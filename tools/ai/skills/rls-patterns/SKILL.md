---
name: rls-patterns
description: Row Level Security patterns for database operations. Use when writing database code or creating API routes that access data.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Database RLS Patterns

## Purpose

Enforce Row Level Security (RLS) patterns for all database operations.
This skill ensures data isolation and prevents cross-user data access
at the database level.

## When This Skill Applies

Invoke this skill when:

- Creating or modifying API routes that access the database
- Adding an org-scoped table or aggregate (carries organization_id, like portal staff)
- Writing goose migrations, repos, or the UnitOfWork transaction path

## Critical Rules

1. **Connect the app as a non-owner, NOBYPASSRLS role.** This workspace
   provisions three Postgres roles: `admin`, `writer`, `reader`. `admin`
   is `SUPERUSER` and owns the tables, so it **always bypasses RLS** — use
   it only for goose migrations, never for request traffic. Application
   command handlers must connect as `writer` and query handlers as
   `reader` (both plain login roles, `NOBYPASSRLS`). Verify the live
   connection is actually constrained:
   `SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user`
   must return `false`. A superuser DSN makes every policy silently a no-op.

2. **`ENABLE` is not enough — add `FORCE`.** `ALTER TABLE t ENABLE ROW
   LEVEL SECURITY` does not apply policies to the table owner. Always pair
   it with `ALTER TABLE t FORCE ROW LEVEL SECURITY` so a role that happens
   to own the table is still filtered. (Superusers like `admin` bypass
   regardless; `FORCE` is the safety net for the app role.)

3. **Enabling RLS without a policy denies everything.** RLS is fail-closed:
   an enabled table with no matching policy returns zero rows and rejects
   every write. Never ship the `ENABLE` migration without its `CREATE POLICY`
   in the same migration.

4. **Set tenant context per transaction, never per session.** Inject the
   org id as the FIRST statement inside the transaction with
   `SELECT set_config('app.organization_id', ?, true)`. The third arg
   `is_local = true` scopes the GUC to the transaction so it reverts on
   COMMIT/ROLLBACK. A bare `SET` (session scope) leaks the previous
   request's org to the next checkout of the same pooled connection — a
   silent cross-tenant data leak. In the portal this is done once, in
   `bindOrganizationRLS` inside `UnitOfWork.DoOrganizationTransaction`.

5. **Always parameterize the org id (`?` / `$1`).** Never build the
   `set_config` value with string formatting; the id originates from an
   auth token and must be bound, not interpolated. Validate it as a
   UUIDv7 first (`idgen.Validate`), as `DoOrganizationTransaction` does.

6. **Make policies fail-closed with the `missing_ok` flag.** Policy
   expressions read `current_setting('app.organization_id', true)`. The
   `true` returns `NULL` when the GUC is unset instead of raising, and
   `organization_id = NULL` evaluates to unknown → the row is denied. Drop
   the `true` and an unmapped request 500s instead of returning no rows.

7. **Set both `USING` and `WITH CHECK`.** `USING` filters which existing
   rows are visible (SELECT/UPDATE/DELETE); `WITH CHECK` validates new rows
   (INSERT/UPDATE). Omitting `WITH CHECK` defaults it to `USING`, but state
   it explicitly so a `writer` cannot forge a row for another org.

8. **Never mark a policy helper function `IMMUTABLE` if it reads
   `current_setting()`.** Use `STABLE`. pgx caches prepared plans; an
   `IMMUTABLE` helper pins the first request's org for the life of the
   connection.

9. **RLS is the authority; app-side org filtering is defense-in-depth
   only.** Do not rely on `WHERE organization_id = ?` in Go in place of a
   policy — add it on top of one.

## Protected Tables

A table needs an RLS policy when ALL hold: (a) it carries a tenant
discriminator — `organization_id` (see `staff`) — non-null on every row;
(b) it is reached by `writer`/`reader` (not just `admin`); (c) the tenant
boundary is a stable, indexable predicate.

**Needs RLS**
- `staff` and every future org-scoped aggregate table (`organization_id`).
- Per-org configuration, integration credentials, feature flags.
- Outbox / event / read-model tables when the rows are org-scoped
  (`WITH CHECK` stops a writer forging events for another org).
- Soft-delete / archive siblings — policies do NOT propagate; each table
  enables and policies independently.

**Does NOT need RLS**
- `organizations` (the tenant root). RLS here is chicken-and-egg — the
  policy would need the current org to filter the org table. Gate it with
  column-scoped `GRANT`s instead.
- Cross-tenant lookup/reference data with no tenant column (currencies,
  time zones).
- Tables only ever touched by `admin` (migrations, ops). `admin` bypasses
  RLS anyway, so a policy adds nothing.

## Worked Example: the portal `staff` aggregate

The portal service is the canonical example. Its schema
(`services/portal/internal/infra/postgres/migrations/20260626000001_init.sql`)
has exactly the shape RLS targets:

- `organizations` — the **tenant root** (`id, name, slug, owner_staff_id,
  deactivated`). No `organization_id` column → it is the tenant itself,
  so it does NOT get a policy (see "Does NOT need RLS" above).
- `staff` — an **org-scoped aggregate** (`id, organization_id, email,
  first_name, last_name, role, deactivated`) with `organization_id TEXT
  NOT NULL` and an existing `idx_staff_organization_id`. This is the table
  that needs tenant isolation.

IDs are `TEXT` UUIDv7 strings (ADR-0004), so policies compare as text —
no `::uuid` cast.

### 1. Enable RLS + tenant policy on `staff` (goose migration, run as `admin`)

Create with `migrate-new staff_rls`; goose runs it via `migrate-up` as
the `admin` (owner) role:

```sql
-- +goose Up
-- +goose StatementBegin
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_staff ON staff
    AS PERMISSIVE
    FOR ALL
    TO writer, reader
    USING      (organization_id = current_setting('app.organization_id', true))
    WITH CHECK (organization_id = current_setting('app.organization_id', true));
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP POLICY IF EXISTS tenant_isolation_staff ON staff;
ALTER TABLE staff NO FORCE ROW LEVEL SECURITY;
ALTER TABLE staff DISABLE ROW LEVEL SECURITY;
-- +goose StatementEnd
```

`organizations` gets no policy — it is the tenant root. Restrict it with
column-scoped `GRANT`s if needed, not RLS.

#### Two scopes: `organization` and `system`

The platform has two kinds of actor on **one** RLS axis (ADR-0008):

- **`organization`** — bound to one tenant (the tenant-facing portal where
  a tenant manages itself, and per-tenant jobs). The policy above handles
  it.
- **`system`** — cross-tenant (background jobs running platform-wide
  rollups/maintenance, and a future separate back-office service — never
  the tenant-facing portal). It must see every org's rows, but it is
  **still `NOBYPASSRLS`** — never run a cross-tenant actor as the `admin`
  superuser. Widen the policy with a second GUC, `app.scope`, instead of
  bypassing RLS:

```sql
CREATE POLICY tenant_isolation_staff ON staff
    AS PERMISSIVE
    FOR ALL
    TO writer, reader
    USING      (current_setting('app.scope', true) = 'system'
                OR organization_id = current_setting('app.organization_id', true))
    WITH CHECK (current_setting('app.scope', true) = 'system'
                OR organization_id = current_setting('app.organization_id', true));
```

A transaction binds **either** `app.scope = system` (cross-tenant) **or**
`app.organization_id = <id>` (one tenant); an unbound transaction matches
neither branch and fails closed (zero rows). `system` is a sharp tool — a
bug in a cross-tenant job (or the future back-office) runs against every
tenant at once — so gate *who* may bind it at the application layer; RLS
only enforces the data boundary, not who may widen it. The `system`-scope
binder/entry points are planned, not yet implemented — the portal is
tenant-facing and uses the `organization` scope only.

### 2. Split read/write policies (optional, finer than `FOR ALL`)

The portal already splits command (`writer`) from query (`reader`) at the
port level (CQRS). You can mirror that split in policy:

```sql
CREATE POLICY staff_tenant_read ON staff
    AS PERMISSIVE FOR SELECT TO reader
    USING (organization_id = current_setting('app.organization_id', true));

CREATE POLICY staff_tenant_write ON staff
    AS PERMISSIVE FOR ALL TO writer
    USING      (organization_id = current_setting('app.organization_id', true))
    WITH CHECK (organization_id = current_setting('app.organization_id', true));
```

### 3. Bind the org at the portal's transaction chokepoint

Every write flows through `UnitOfWork.DoOrganizationTransaction` in
`services/portal/internal/infra/postgres/uow/uow.go`. The org id is a
REQUIRED, explicit parameter (`organization.ID`) — there is no org-less
write path, so a handler cannot accidentally mutate outside a tenant
scope. It validates the id, then binds RLS as the first statement of the
transaction:

```go
// ACTUAL portal code (uow.go).
func (u *UnitOfWork) DoOrganizationTransaction(ctx context.Context, id organization.ID, handler command.TransactionalUnitOfWorkHandler) error {
    return u.db.Transaction(func(tx *gorm.DB) error {
        if err := idgen.Validate(id); err != nil {
            return organization.ErrEmptyID
        }
        if err := bindOrganizationRLS(ctx, tx, id); err != nil {
            return err
        }
        return handler(ctx, newTxUnitOfWork(tx))
    })
}

// bindOrganizationRLS sets the tenant GUC transaction-locally (is_local=
// true), so it reverts on COMMIT/ROLLBACK and a pooled connection never
// leaks one request's org to the next.
func bindOrganizationRLS(ctx context.Context, tx *gorm.DB, id organization.ID) error {
    if err := tx.WithContext(ctx).Exec(
        `select set_config('app.organization_id', ?, true)`, id.String(),
    ).Error; err != nil {
        return fmt.Errorf("%w: %v", ErrOrganizationRLSCannotBeBound, err)
    }
    return nil
}
```

Notes:
- The GUC names are `app.organization_id` and `app.scope` — the policy
  predicates above MUST read the same names. The `organization` scope binds
  `app.organization_id`; the `system` scope binds `app.scope = system`
  (cross-tenant, still `NOBYPASSRLS`). See ADR-0008 for the two-scope model.
- The scope-less `DoTransaction` is intentionally commented out in `uow.go`;
  enable it ONLY for a non-multi-tenant system that does not need RLS.
- The query side is symmetric: `query.ReadStore.DoOrganizationQuery(ctx,
  id, handler)` (impl in
  `services/portal/internal/infra/postgres/readstore/readstore.go`) opens
  a transaction, binds the same `app.organization_id` GUC via
  `bindOrganizationRLS`, and hands the handler a tenant-scoped
  `TransactionalReadStore`. Reads are RLS-bound too — an unbound read
  fails closed (zero rows) against a `FORCE`d policy.
- The portal connects gormx with the `writer` (command) DSN and the
  `reader` (query) DSN — never `admin`.

### 4. Index the tenant column

Policy predicates filter on `organization_id`, so it must be indexed. The
portal `staff` table already ships `idx_staff_organization_id`
(init migration); every new RLS table needs the equivalent. Confirm with
`EXPLAIN (ANALYZE, BUFFERS)` that the policy filter uses the index.

### 5. Isolation test (connect as `writer`, prove cross-org returns 0)

Run against a `writer`/`reader` connection — never the `admin` DSN, or the
policy is a silent no-op. The org id is passed explicitly to
`DoOrganizationTransaction(ctx, id, handler)`, matching the real signature:

```go
// requireRLSEnforced: skip if the connected role bypasses RLS.
var bypass bool
require.NoError(t, db.Raw(
    "SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user",
).Scan(&bypass).Error)
require.False(t, bypass, "connected role bypasses RLS; check DSN/GRANTs")

// org A inserts a staff row; org B must see zero.
var seenByB int64
require.NoError(t, uow.DoOrganizationTransaction(ctx, orgB, func(ctx context.Context, _ command.TransactionalUnitOfWork) error {
    return db.Raw("SELECT count(*) FROM staff").Scan(&seenByB).Error
}))
assert.Equal(t, int64(0), seenByB)
```

Cover, using `staff`: per-org SELECT scoping, unset-GUC fails closed
(0 rows), `WITH CHECK` rejecting a foreign-org `Staffs().Create`, cross-org
UPDATE/DELETE affecting 0 rows, and `FORCE` applying to the owner. Also
assert `DoOrganizationTransaction` rejects an invalid id
(`organization.ErrEmptyID`) before any row is touched.

## Migration Workflow

A schema change is not just SQL — it is an approved, RLS-complete, tested
unit. Follow these steps in order. The engine is **goose** (run via
`migrate-up`); there is no Prisma, no ORM auto-migrate.

### Step 1 — Approval (our gate is the ADR)

Schema changes that introduce or alter a **decision** (a new aggregate
table, a new RLS scope, a role/grant change, a tenant-boundary change) are
gated on an **ADR**, not an ad-hoc issue. The ADR's `Status: Proposed →
Accepted` transition IS the approval workflow; its `Deciders` field names
who approved. Proceed only once the ADR is `Accepted`.

- Applying an **already-accepted** decision needs no new ADR. Adding an
  org-scoped table that just follows ADR-0008's RLS model is routine —
  write the migration. Only a **material** change (new scope, reversed
  rule, broadened tenant boundary) needs a new ADR (`docs/adrs/`).
- When the change needs design detail (column-by-column shape, rollout),
  write a **spec** (`docs/specs/` or `services/<svc>/docs/specs/`) whose
  `Tracks` field points at the ADR. The ADR records *why*; the spec records
  *how*; the migration SQL is the source of truth for *what*.

### Step 2 — Create the migration (goose)

```bash
migrate-new add_<table>_rls      # scaffolds services/<svc>/internal/infra/postgres/migrations/<ts>_*.sql
```

### Step 3 — RLS lives in the SAME migration file (mandatory)

Never ship the `CREATE TABLE` without its RLS in the same file — an enabled
table with no policy is fail-closed (zero rows), and a created table with no
`ENABLE` is wide open. One file contains the complete, safe unit:

- [ ] `CREATE TABLE ...` with `organization_id TEXT NOT NULL` (org-scoped tables)
- [ ] `CREATE INDEX idx_<table>_organization_id ON <table>(organization_id)` — the policy filters on it
- [ ] `ALTER TABLE <table> ENABLE ROW LEVEL SECURITY` **and** `FORCE ROW LEVEL SECURITY`
- [ ] `CREATE POLICY` with the two-scope predicate (`app.scope='system' OR organization_id=current_setting('app.organization_id',true)`), `TO writer, reader` — see [Two scopes](#two-scopes-organization-and-system)
- [ ] A `-- +goose Down` block that drops the policy, `NO FORCE`, `DISABLE`, and the table

Roles and grants are **not** per-migration here: `writer`/`reader` already
hold schema-wide CRUD/SELECT grants plus `ALTER DEFAULT PRIVILEGES` from the
postgres devenv module (`packages/nix/core/services/postgres/default.nix`),
so new tables inherit them. Only add explicit `GRANT`s for a column-scoped
exception (e.g. locking down `organizations`, the tenant root).

### Step 4 — Verify locally

```bash
migrate-up        # applies as the admin (owner) role
migrate-status    # confirm the new version is applied
```

Then prove RLS is live (the isolation test above): connect as `writer`/
`reader`, confirm `rolsuper OR rolbypassrls = false`, and that a cross-org
SELECT returns 0 rows. `pg-info` lists the role DSNs.

### Step 5 — Document the change

We have no separate data dictionary — the **migration SQL is the schema
source of truth**. Beyond it, document only what carries meaning:
- the **ADR** if the change was a decision (Step 1);
- a **spec** update if one tracks this area;
- the relevant `AGENTS.md` "Code map" / table notes if a new aggregate
  changes the service's shape.

### Production migrations

Migrations run as the `admin` (SUPERUSER) role and bypass RLS, so a bad
policy or `Down` block is high-blast-radius. Before applying to a shared/
production database:
- [ ] Reviewer present and the originating ADR is `Accepted`
- [ ] Backup (or a point-in-time-recovery window) confirmed
- [ ] The `-- +goose Down` block is tested (`migrate-down` then `migrate-up` round-trips clean locally)
- [ ] Post-migration validation defined: RLS enforced (isolation test), policy filter uses the index (`EXPLAIN`), no table left `ENABLE` without a policy

### Pre-PR checklist

- [ ] ADR `Accepted` (if the change is a decision)
- [ ] RLS `ENABLE` + `FORCE` + policy in the **same** migration file
- [ ] Two-scope policy predicate, `TO writer, reader` (never `TO admin`)
- [ ] `organization_id` index created in the same file
- [ ] `-- +goose Down` round-trips clean
- [ ] Isolation test passes against a `writer`/`reader` connection
- [ ] No raw role/GUC drift — `app.scope` / `app.organization_id` only

## Authoritative References

**PostgreSQL docs (current)**
- Row Security Policies — <https://www.postgresql.org/docs/current/ddl-rowsecurity.html>
- `CREATE POLICY` (USING vs WITH CHECK, PERMISSIVE/RESTRICTIVE) — <https://www.postgresql.org/docs/current/sql-createpolicy.html>
- `ALTER TABLE` (ENABLE / FORCE ROW LEVEL SECURITY) — <https://www.postgresql.org/docs/current/sql-altertable.html>
- `CREATE ROLE` (BYPASSRLS attribute) — <https://www.postgresql.org/docs/current/sql-createrole.html>
- `SET` / `SET LOCAL` semantics — <https://www.postgresql.org/docs/current/sql-set.html>
- `current_setting` / `set_config` — <https://www.postgresql.org/docs/current/functions-admin.html>
- `row_security` GUC (pg_dump escape hatch) — <https://www.postgresql.org/docs/current/runtime-config-client.html>

**Reference Go implementations**
- pgx UnitOfWork with `set_config(..., true)` — <https://github.com/c2siorg/genie/blob/main/pkg/storage/postgres/tenant.go>
- GORM RLS wrapper + full isolation test suite — <https://github.com/micasa-dev/micasa/blob/main/internal/relay/rlsdb/rlsdb.go>, <https://github.com/micasa-dev/micasa/blob/main/internal/relay/rls_test.go>
- `IMMUTABLE` policy fn + pgx prepared-statement cache footgun — <https://github.com/jackc/pgx/issues/2007>

**This workspace**
- Postgres roles (`admin`/`writer`/`reader`) — `packages/nix/core/services/postgres/default.nix`
- Two-scope RLS model (`organization` + `system`) — `docs/adrs/0008-tenant-scoped-unit-of-work-rls.md`
- Write RLS chokepoint — `UnitOfWork.DoOrganizationTransaction` + `bindOrganizationRLS` in `services/portal/internal/infra/postgres/uow/uow.go` (`system`-scope entry point planned)
- Read RLS chokepoint — `ReadStore.DoOrganizationQuery` + `bindOrganizationRLS` in `services/portal/internal/infra/postgres/readstore/readstore.go` (`system`-scope entry point planned)
- Write-side port (`command.UnitOfWork`, `TransactionalUnitOfWorkHandler`) — `services/portal/internal/app/command/port.go`
- Read-side port (`query.ReadStore`, `TransactionalReadStoreHandler`) — `services/portal/internal/app/query/port.go`
- Migration format + role — `services/portal/internal/infra/postgres/migrations/`, run as `admin` via `migrate-up`
- Typed UUIDv7 IDs (`TEXT` columns) — `docs/adrs/0004-typed-aggregate-ids-uuidv7.md`
