# 0011. Org-root RLS hardening with a self-binding registration insert

- **Status**: Accepted
- **Date**: 2026-06-29
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

[ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) made Postgres RLS the authority for tenant isolation and bound one of two named scopes (`organization` / `system`) transaction-locally at every connection-scoped entry point. Org-scoped aggregates (`staff`) carry a `FORCE`d policy keyed on `organization_id`. But `organizations` — the **tenant root** — was deliberately left with **no policy**: it has no `organization_id` column (it *is* the tenant), and the [portal database schema](../../services/portal/docs/specs/database-schema.md) classified it as "tenant root — no RLS; chicken-and-egg".

Leaving the tenant root unprotected is a real hole. The command side connects as the `NOBYPASSRLS` `writer` role with schema-wide `INSERT, UPDATE, DELETE`. With no policy on `organizations`, that role can read or mutate **any** organization's root row regardless of the bound `app.organization_id` — a single bug in a tenant-facing handler (a wrong id, a missing `WHERE`, a typo) can rename, deactivate, or re-own *another tenant's* organization. That is exactly the "forgot the predicate" class of cross-tenant leak ADR-0008 exists to eliminate by construction, reopened on the one table that names the tenant.

The chicken-and-egg framing that justified "no policy" was an over-statement. A policy on `organizations` does **not** need an existing org to filter against — it can key on the row's own `id` versus the bound `app.organization_id`. And registration ([organization-registration spec](../../services/portal/docs/specs/organization-registration.md)) already binds `app.organization_id` to the **new** org's app-generated UUIDv7 *before* inserting it, so a self-referential `id`-keyed policy admits the registration insert while still constraining every other access to the bound org.

The migrations that create `organizations` and the `staff` policies are written but **not yet applied to any database**. This is the moment to add the org-root policy — before first apply — so there is no policy-rewrite/re-test churn later, and no window where the tenant root ships unprotected.

## Decision

**We will put a `FORCE`d RLS policy on `organizations`, keyed on the row's own `id` against the bound scope, mirroring the two-scope model of [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md)/[ADR-0009](0009-safe-system-scope-rls.md) but on `id` instead of `organization_id`.** The tenant root is no longer an RLS exemption.

The `organization` scope policy (`TO writer, reader`):

```sql
USING      (id = current_setting('app.organization_id', true))
WITH CHECK (id = current_setting('app.organization_id', true))
```

This admits the registration insert (the handler binds `app.organization_id = <new org id>` first, then inserts `organizations` with that same `id`, so `WITH CHECK` passes), constrains every read/update/delete to the one bound org, and **fails closed** when unbound (`current_setting(..., true)` → `NULL` → `id = NULL` is unknown → row denied). The `system` read scope (`TO system_reader`) mirrors `staff`'s `system_read_staff`: `app.scope = 'system'` plus the `app.organization_allowlist` GUC, with no `system` branch on the tenant-facing roles.

`organizations` is reclassified from **tenant root (no RLS)** to **tenant root (self-keyed RLS)**: still has no `organization_id` column, still the tenant boundary, but now policy-protected on its own `id`. Migrations still run as `admin` (BYPASSRLS) and are unaffected.

## Consequences

- **Positive**:
  - The tenant root is no longer the single unprotected table — a tenant-facing handler can no longer touch another org's root row even with a wrong id, closing the last cross-tenant write hole on the `organization` scope.
  - One consistent isolation model: `organizations` and `staff` both fail closed when unbound and both constrain to the bound org; reviewers reason about one pattern (org-keyed vs id-keyed is the only difference).
  - The registration self-binding insert is now *required* by the policy, not merely permitted — it documents and enforces the one legitimate way the tenant root is created.
- **Negative**:
  - Any future cross-tenant *read* of `organizations` (e.g. a platform rollup listing all orgs) must bind the `system` scope through `system_reader`; it can no longer lean on the table being unprotected. This is the intended direction but adds the same ceremony `staff` already has.
  - One more policy to keep in sync with the GUC contract; the id-keyed predicate is a deliberate deviation from the org-keyed norm and must be understood as such (documented in the migration + schema spec).
- **Neutral**:
  - Builds entirely on the existing role split and GUC contract from [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md); no new role, no new GUC, no code change to the UoW/Read Store — the `organization` scope binder (`bindOrganizationRLS`) already sets exactly the GUC this policy reads.
  - `system`-scope reads of `organizations` remain gated by [ADR-0009](0009-safe-system-scope-rls.md)'s `system_reader` role + allowlist; this ADR only extends that same shape to the root table.

## Alternatives considered

- **Leave `organizations` with no RLS (status quo).** Rejected: it leaves the tenant root mutable across tenants by the `NOBYPASSRLS` `writer` role, reopening the exact leak class ADR-0008 removes. "Chicken-and-egg" does not hold — an `id`-keyed policy needs no pre-existing row.
- **Column-scoped `GRANT`s instead of a policy.** Rejected: grants narrow *which columns* a role touches, not *which rows*; they cannot express per-tenant row isolation and would not constrain a handler to the bound org.
- **A separate `bootstrap_writer` role that may insert `organizations`.** Rejected (consistent with the [registration spec](../../services/portal/docs/specs/organization-registration.md)): registration is not a cross-tenant write — it writes one root row keyed to the org it binds. The self-keyed policy admits that insert under the existing `writer` role with zero new privilege, so a new role would expand the surface [ADR-0009](0009-safe-system-scope-rls.md) warns against for no benefit.
- **Defer hardening until after the first migration is applied.** Rejected: it guarantees a policy-rewrite + re-test cycle and ships the tenant root unprotected in the interim. The migrations are unapplied now — adding the policy before first apply is strictly cheaper.

## References

- [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) — RLS authority, the two named scopes, and the transaction-local GUC contract this policy reads.
- [ADR-0009](0009-safe-system-scope-rls.md) — the `system_reader` role + allowlist this policy's `system` branch mirrors.
- [Organization registration & root account spec](../../services/portal/docs/specs/organization-registration.md) — the self-binding registration insert this policy admits.
- [Portal database schema](../../services/portal/docs/specs/database-schema.md) — the data dictionary reclassifying `organizations`.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) — `admin`/`writer`/`reader`/`system_reader` roles + `app.scope` / `app.organization_id` GUCs.
- `services/portal/internal/infra/postgres/uow/uow.go` — `bindOrganizationRLS`, which sets the `app.organization_id` GUC this policy reads.
- `services/portal/internal/infra/postgres/migrations/` — where the org-root policy migration lands, run as `admin` via `migrate-up`.
- [`rls-patterns` skill](../../tools/ai/skills/rls-patterns/SKILL.md) — policy authoring + GUC contract + worked `staff` example.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [`set_config` / `current_setting`](https://www.postgresql.org/docs/current/functions-admin.html)
