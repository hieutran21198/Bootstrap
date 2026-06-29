# Portal database schema

> **Status**: Implemented
> **Authors**: Minh Hieu Tran <hieu.tran21198@gmail.com>
> **Last reviewed**: 2026-06-29
> **Tracks**: [ADR-0003](../../../../docs/adrs/0003-service-architecture.md), [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md), [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md)

> **Implementation status:** Tables and indexes exist in the init migration (`20260626000001_init.sql`); the `staff` RLS policies — the `organization` policy (`TO writer, reader`) and the `system` read policy (`TO system_reader`) — exist in `20260629000001_staff_rls.sql`. The migrations have **not been run** against a database yet (apply with `migrate-up`). The cross-tenant `system_reader` role is provisioned by the postgres devenv module but **disabled by default** (`core.services.postgres.roles.systemReader.enable = false`); it is enabled only by a separate system-scoped runtime, never the tenant-facing portal (ADR-0009).

## Problem

Portal's relational schema is defined only in goose migration SQL (`internal/infra/postgres/migrations/`). The migration is the source of truth for *what* the schema is, but it does not explain *which tables are tenant-scoped*, *which carry an RLS policy*, or *how each column maps to a domain aggregate*. A contributor adding a table, writing a policy, or debugging an isolation failure has no single table-by-table reference. This spec is that reference: the portal data dictionary, annotated with the tenant-isolation classification each table needs.

This spec documents the schema; it does not re-decide the rules behind it. The role/GUC contract is the workspace [Database role and scope contract](../../../../docs/conventions/database/role-and-scope-contract.md); the RLS authority and scopes are [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md); typed UUIDv7 keys are [ADR-0004](../../../../docs/adrs/0004-typed-aggregate-ids-uuidv7.md). This file links to them, never restates them.

## Goals

- A table-by-table data dictionary (columns, types, nullability, defaults, keys, indexes) kept in sync with the migrations.
- A per-table tenant-isolation classification: **tenant root**, **org-scoped aggregate**, or **cross-tenant reference** — and whether each needs an RLS policy.
- A mapping from each table to the domain aggregate / repo that owns it.

## Non-goals

- The RLS policy SQL, migration workflow, and role provisioning — those live in the [`rls-patterns` skill](../../../../tools/ai/skills/rls-patterns/SKILL.md), [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md), and `packages/nix/core/services/postgres/default.nix`.
- The Go repository/UoW shape — see [Service architecture § Unit of Work](../../../../docs/conventions/go/service-architecture.md#unit-of-work).
- A migration-by-migration changelog — the ordered `migrations/` directory is that history.

## Background

- **Engine**: PostgreSQL, migrated with goose (run via `migrate-up`/`migrate-down`/`migrate-status`); no ORM auto-migrate. Migrations run as the `admin` (owner, `BYPASSRLS`) role.
- **Keys**: all aggregate ids are UUIDv7 strings stored as `TEXT` ([ADR-0004](../../../../docs/adrs/0004-typed-aggregate-ids-uuidv7.md)). Policies and joins compare as text — no `::uuid` cast.
- **Source migration**: `services/portal/internal/infra/postgres/migrations/20260626000001_init.sql` (creates the tables below; the `app.scope`-aware RLS policy is a **planned** later migration, see [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md)).
- **Tenant model**: one physical table holds rows for many organizations; isolation is enforced by RLS, bound per transaction via `app.organization_id` (organization scope) — see the [role and scope contract](../../../../docs/conventions/database/role-and-scope-contract.md).

## Design

### Tenant-isolation classification

Every table is exactly one of:

| Class                      | Meaning                                                                | RLS policy?                                            |
| -------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------- |
| **Tenant root**            | The organization itself; has no `organization_id` (it *is* the tenant). | No — chicken-and-egg; gate with column-scoped `GRANT`s. |
| **Org-scoped aggregate**   | Carries `organization_id NOT NULL`; rows belong to one tenant.          | **Yes** — `FORCE`d policy on `app.organization_id`.    |
| **Cross-tenant reference** | Lookup/reference data with no tenant column.                          | No — shared across tenants.                            |

### Table: `organizations`

**Class:** tenant root · **Owner:** `organization` aggregate (`internal/domain/organization/`, repo `internal/infra/postgres/repo/organization.go`)

| Column           | Type      | Null | Default | Key / Constraint        | Notes                                            |
| ---------------- | --------- | ---- | ------- | ----------------------- | ------------------------------------------------ |
| `id`             | `TEXT`    | no   | —       | `PRIMARY KEY`           | UUIDv7 string ([ADR-0004](../../../../docs/adrs/0004-typed-aggregate-ids-uuidv7.md)). |
| `name`           | `TEXT`    | no   | —       | —                       | Display name.                                    |
| `slug`           | `TEXT`    | no   | —       | `UNIQUE`                | URL-safe identifier; unique across all tenants.  |
| `owner_staff_id` | `TEXT`    | no   | —       | indexed                 | UUIDv7 of the owning `staff` row (by id, not FK). |
| `deactivated`    | `BOOLEAN` | no   | `FALSE` | —                       | Soft-deactivation flag.                          |

**Indexes:** `idx_organizations_owner_staff_id (owner_staff_id)`.

**RLS:** none. `organizations` is the tenant root — a policy here would need the current org to filter the org table. Restrict with column-scoped `GRANT`s if access narrowing is ever required.

### Table: `staff`

**Class:** org-scoped aggregate · **Owner:** `staff` aggregate (`internal/domain/staff/`, repo `internal/infra/postgres/repo/staff.go`)

| Column            | Type      | Null | Default | Key / Constraint | Notes                                                              |
| ----------------- | --------- | ---- | ------- | ---------------- | ----------------------------------------------------------------- |
| `id`              | `TEXT`    | no   | —       | `PRIMARY KEY`    | UUIDv7 string.                                                    |
| `organization_id` | `TEXT`    | no   | —       | indexed          | Tenant discriminator; the RLS policy predicate filters on this.  |
| `email`           | `TEXT`    | no   | —       | unique per active org | Login/contact email (lowercased, RFC 5322 via `staff.NewEmail`). Unique per organization among **active** staff — see Indexes. |
| `first_name`      | `TEXT`    | no   | —       | —                | —                                                                |
| `last_name`       | `TEXT`    | no   | —       | —                | —                                                                |
| `role`            | `TEXT`    | no   | —       | —                | Domain enum `staff.Role`: `owner` \| `admin` \| `member` (validated in Go, not by a DB CHECK). |
| `deactivated`     | `BOOLEAN` | no   | `FALSE` | —                | Soft-deactivation flag.                                          |

**Indexes:**

- `idx_staff_organization_id (organization_id)` — required; the RLS policy predicate filters on it (covers all rows, active and deactivated).
- `uq_staff_active_org_email` — **partial unique** `(organization_id, email) WHERE NOT deactivated`. Enforces one active staff member per email per organization. Scoped to the tenant because the same person may legitimately work for more than one organization; partial so an email frees up once its holder is deactivated and can be re-hired. There is **no** application-level dedup — this constraint is the only enforcement (the repo `Create` relies on DB constraints; see `internal/infra/postgres/repo/staff.go`).

**RLS:** **required** (org-scoped) — **`ENABLE` + `FORCE` + two policies in `20260629000001_staff_rls.sql`** (not yet applied to a DB). Two policies cover the two scopes:

- `tenant_isolation_staff` (`FOR ALL TO writer, reader`) — the `organization` scope. `USING`/`WITH CHECK`: `organization_id = current_setting('app.organization_id', true)`. The tenant-facing UoW/Read Store binds `app.organization_id`; a missing GUC denies the row (fail closed). Writer + reader share it; `WITH CHECK` stops a writer forging a row for another org.
- `system_read_staff` (`FOR SELECT TO system_reader`) — the `system` scope (ADR-0009). Passes when `app.scope = system` **and** the row's org is in `app.organization_allowlist` (`*` or a comma list). The tenant-facing roles have **no** branch here, so `app.scope='system'` on a tenant connection matches nothing and fails closed. A missing allowlist denies all rows — "all tenants" is never an implicit default.

See [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md) (organization policy), [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md) (`system_reader` policy + the capability gate enforced in the Read Store), [`system-scope-rls.md`](system-scope-rls.md) (the full system-scope build), and the [`rls-patterns` skill](../../../../tools/ai/skills/rls-patterns/SKILL.md) (policy authoring).

### Relationships

- `staff.organization_id` → `organizations.id` (many staff per organization). Referenced by id string, not a DB foreign key — consistent with the aggregate-boundary rule (cross-aggregate references are by UUID string; see [services/portal/AGENTS.md](../../AGENTS.md)).
- `organizations.owner_staff_id` → `staff.id` (the founding staff member). Also by id string; the cycle (`organizations` ↔ `staff`) is why neither side declares a DB-level FK.

## Alternatives considered

- **A separate global data dictionary under `docs/`** — Rejected: the schema dies with portal; the two-tier rule of thumb ([docs/AGENTS.md](../../../../docs/AGENTS.md)) puts service-only knowledge in the service tree. Cross-service DB *rules* live in the global [database conventions](../../../../docs/conventions/database/README.md); this *schema* is portal-local.
- **Generating the dictionary from the migration SQL** — Rejected for now: the per-table isolation classification and aggregate mapping are not derivable from DDL alone. Revisit if the schema grows enough to warrant a generator.

## Open questions

- _None open._ (Resolved: `staff.email` is unique per organization among active staff — `uq_staff_active_org_email`, partial `WHERE NOT deactivated`. Per-org, not global, because the same person may work for multiple organizations; active-only so an email frees up after deactivation.)

## Implementation plan

Tables, indexes, and the `staff` RLS policies are written. The migrations have not been applied to a database yet (`migrate-up` when ready).

- [x] Create the `organizations` + `staff` tables and indexes — done (init migration).
- [x] Decide and encode `staff.email` uniqueness — done: partial unique `(organization_id, email) WHERE NOT deactivated` (`uq_staff_active_org_email`) in the init migration.
- [x] Add the `FORCE`d RLS migration for `staff`: `ENABLE` + `FORCE` + the `organization` policy (`tenant_isolation_staff`, `TO writer, reader`) — done in `20260629000001_staff_rls.sql` ([ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md)).
- [x] Add the `system_reader` role + `system` read policy (`system_read_staff`, `TO system_reader`) on `staff` — done: role in the postgres devenv module (disabled by default), policy in `20260629000001_staff_rls.sql` ([ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md), [`system-scope-rls.md`](system-scope-rls.md)).
- [ ] Apply the migrations against the dev database (`migrate-up`) and run the RLS isolation tests (two-tenant + cross-tenant `system_reader`).
- [ ] Update this dictionary whenever a migration adds/changes a table — bump `Last reviewed`.

## References

- `services/portal/internal/infra/postgres/migrations/20260626000001_init.sql` — the migration this dictionary documents.
- [Database role and scope contract](../../../../docs/conventions/database/role-and-scope-contract.md) — roles + GUC contract this schema applies.
- [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md) — RLS authority and the two scopes.
- [ADR-0004](../../../../docs/adrs/0004-typed-aggregate-ids-uuidv7.md) — typed UUIDv7 ids stored as `TEXT`.
- [ADR-0003](../../../../docs/adrs/0003-service-architecture.md) — DDD/CQRS/hexagonal shape the repos follow.
- [`rls-patterns` skill](../../../../tools/ai/skills/rls-patterns/SKILL.md) — policy authoring + migration workflow + worked `staff` example.
- [services/portal/AGENTS.md](../../AGENTS.md) — aggregate-boundary and repo conventions.
