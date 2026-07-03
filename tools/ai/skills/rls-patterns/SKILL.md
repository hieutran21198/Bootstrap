---
name: rls-patterns
description: Row Level Security patterns for database operations. Use when writing database code or creating API routes that access data.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Database RLS Patterns

Enforce Row Level Security so tenant data cannot leak across orgs at the
database layer. RLS is the authority; app-side filtering is only
defense-in-depth.

## When this applies

- Adding or altering an org-scoped table (carries `organization_id`, like `staff`).
- Writing goose migrations, repos, or touching the UnitOfWork transaction path.
- Creating handlers/API routes that read or write tenant data.

## Critical rules (each is a real footgun)

1. **App connects as a non-owner `NOBYPASSRLS` role.** `writer` for commands,
   `reader` for queries. `admin` is SUPERUSER, owns the tables, and always
   bypasses RLS — migrations only, never request traffic. Verify the live
   connection: `SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user`
   must return `false`, or every policy is a silent no-op.
2. **`ENABLE` + `FORCE`.** `ENABLE ROW LEVEL SECURITY` alone does not filter the
   table owner; always pair it with `FORCE ROW LEVEL SECURITY`.
3. **Enable always ships with a policy, in the same migration.** RLS is
   fail-closed: an enabled table with no policy returns zero rows and rejects
   every write.
4. **Set tenant context per-transaction, never per-session.** First statement in
   the tx: `SELECT set_config('app.organization_id', ?, true)`. The `is_local=true`
   arg reverts the GUC on COMMIT/ROLLBACK; a bare session `SET` leaks one
   request's org to the next checkout of a pooled connection.
5. **Always parameterize the org id (`?`/`$1`).** It originates from an auth
   token — bind it, never interpolate. Validate as UUIDv7 first (`idgen.Validate`).
6. **Read the GUC with `current_setting('app.organization_id', true)`.** The
   `true` (missing_ok) returns NULL when unset, so the row is denied (fail-closed);
   dropping it makes an unmapped request 500 instead of returning no rows.
7. **Set both `USING` and `WITH CHECK` explicitly** so a `writer` cannot forge a
   row for another org (`USING` filters reads; `WITH CHECK` validates writes).
8. **Policy helper functions that read `current_setting()` are `STABLE`, never
   `IMMUTABLE`.** pgx caches prepared plans; `IMMUTABLE` pins the first request's
   org for the life of the connection.
9. **Never replace a policy with `WHERE organization_id = ?` in Go** — add it on
   top of one, never instead of it.

## Which tables need a policy

**Needs org-keyed RLS** — non-null `organization_id`, reached by
`writer`/`reader`: `staff` and every org-scoped aggregate; per-org config /
credentials / feature flags; org-scoped outbox / event / read-model tables;
soft-delete siblings (policies do NOT propagate — each table enables
independently).

**Needs self-keyed root RLS** — `organizations`. It has no `organization_id`
because it *is* the tenant root, but ADR-0011 makes it policy-protected on its
own `id = current_setting('app.organization_id', true)`. Registration binds the
new org id before inserting, so the self-keyed `WITH CHECK` admits the bootstrap
insert and every other access stays constrained to the bound org.

**No tenant RLS** — cross-tenant reference data (currencies, time zones) and
admin-only tables (`admin` bypasses RLS anyway).

## Canonical migration (org-scoped table)

Goose, run as `admin`. RLS should ship with table creation when possible; if
hardening an existing/unapplied table, keep the `ENABLE`/`FORCE` and policies in
one focused migration. IDs are `TEXT` UUIDv7 (ADR-0004) — compare as text, no
`::uuid` cast.

```sql
-- +goose Up
-- +goose StatementBegin
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff FORCE  ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_staff ON staff
    AS PERMISSIVE
    FOR ALL
    TO writer, reader
    USING      (organization_id = current_setting('app.organization_id', true))
    WITH CHECK (organization_id = current_setting('app.organization_id', true));

CREATE POLICY system_read_staff ON staff
    AS PERMISSIVE
    FOR SELECT
    TO system_reader
    USING (
        current_setting('app.scope', true) = 'system'
        AND (
            current_setting('app.organization_allowlist', true) = '*'
            OR organization_id = ANY (
                string_to_array(current_setting('app.organization_allowlist', true), ',')
            )
        )
    );
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP POLICY IF EXISTS system_read_staff ON staff;
DROP POLICY IF EXISTS tenant_isolation_staff ON staff;
ALTER TABLE staff NO FORCE ROW LEVEL SECURITY;
ALTER TABLE staff DISABLE  ROW LEVEL SECURITY;
-- +goose StatementEnd
```

Two scopes on one axis (ADR-0008), with ADR-0009's safer split:

- `organization` scope binds `app.organization_id` and uses tenant-facing
  `writer`/`reader` policies. These policies have **no** `system` OR-branch;
  setting `app.scope='system'` on a tenant connection must match nothing and
  fail closed.
- `system` scope is read-only today. It uses the dedicated `system_reader`
  `NOBYPASSRLS` role plus a separate `FOR SELECT` policy and binds
  `app.scope='system'` with `app.organization_allowlist`. The allowlist is `*`
  for all tenants or a comma-separated UUIDv7 list; missing allowlist is zero
  rows, never implicit all-tenants.

Self-keyed tenant-root policy for `organizations` (ADR-0011) mirrors the same
split but compares the row's `id` instead of `organization_id`:

```sql
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_organizations ON organizations
    AS PERMISSIVE
    FOR ALL
    TO writer, reader
    USING      (id = current_setting('app.organization_id', true))
    WITH CHECK (id = current_setting('app.organization_id', true));

CREATE POLICY system_read_organizations ON organizations
    AS PERMISSIVE
    FOR SELECT
    TO system_reader
    USING (
        current_setting('app.scope', true) = 'system'
        AND (
            current_setting('app.organization_allowlist', true) = '*'
            OR id = ANY (
                string_to_array(current_setting('app.organization_allowlist', true), ',')
            )
        )
    );
```

Also required in the same file:

- For org-keyed tables: `organization_id TEXT NOT NULL` and
  `CREATE INDEX idx_<table>_organization_id` — the policy filters on it; confirm
  with `EXPLAIN (ANALYZE, BUFFERS)`. For `organizations`, the primary-key `id`
  is the policy key.
- No per-table `GRANT`s for `writer`/`reader`: they already hold schema-wide
  CRUD/SELECT plus `ALTER DEFAULT PRIVILEGES` from the postgres devenv module.
  `system_reader` is SELECT-only and still must be paired with an explicit
  per-table system read policy before it can see rows.

## Binding chokepoint (don't reinvent)

Writes flow through `UnitOfWork.DoOrganizationTransaction(ctx, orgID, handler)`
(`services/portal/internal/infra/postgres/uow/uow.go`); tenant reads through
`ReadStore.DoOrganizationQuery` (`.../readstore/readstore.go`). Both validate the
id and call `bindOrganizationRLS` (`set_config(..., true)`) as the first
statement. The org id is a REQUIRED parameter — there is no org-less write path.
Connect gormx with the `writer`/`reader` DSN, never `admin`.

System reads flow through `ReadStore.DoSystemQuery(ctx, cap, handler)` and are
implemented, not planned. The caller must pass an unforgeable
`query.SystemReadCapability`; the read store rejects invalid/zero capabilities,
then `bindSystemRLS` sets `app.scope='system'` and `app.organization_allowlist`
transaction-locally from the capability target. There is deliberately no
`DoSystemTransaction`; system writes need a future ADR, role, and capability.

## Isolation test (must run as writer/reader)

Against a `writer`/`reader` connection for tenant scope, and against
`system_reader` for system-scope reads — never `admin`, or the policy is a
silent no-op:

1. Assert `SELECT rolsuper OR rolbypassrls ... = false`.
2. org A inserts a row; org B must see 0.
3. Cover: unset-GUC fails closed (0 rows); `WITH CHECK` rejects a foreign-org
   `Create`; cross-org UPDATE/DELETE affect 0 rows; `FORCE` applies to the owner;
   an invalid id is rejected (`organization.ErrEmptyID`) before any row is touched.
4. For system reads, setting `app.scope='system'` on `writer`/`reader` must still
   return 0 rows; `system_reader` must require both `app.scope='system'` and
   `app.organization_allowlist`; missing allowlist returns 0 rows, `*` returns all
   opted-in rows, and a UUIDv7 list returns only those organizations.

## Migration workflow

1. **Approval = ADR.** A new *decision* (new aggregate, new scope, role/grant or
   tenant-boundary change) needs an `Accepted` ADR in `docs/adrs/`. Applying an
   already-accepted pattern (a routine org-scoped table) needs none; add a spec
   (`Tracks` the ADR) when column-by-column design detail is needed.
2. `migrate-new add_<table>_rls` scaffolds the migration.
3. Put `CREATE TABLE` + index + `ENABLE`/`FORCE` + `CREATE POLICY` + a clean
   `-- +goose Down` in the one file.
4. `migrate-up` then `migrate-status`; run the isolation test; `EXPLAIN` the
   policy filter uses the index.
5. Document only what carries meaning — the migration SQL is the schema source of
   truth: the ADR (why), a spec (how) if one tracks the area, and AGENTS.md
   code-map notes for a new aggregate.

**Production** (migrations run as `admin`, bypass RLS, high blast radius):
reviewer present + originating ADR `Accepted`; backup/PITR confirmed; `Down`
round-trips clean locally; post-migration RLS verified (isolation test, index
used, no table left `ENABLE`d without a policy).

## References

- PostgreSQL — Row Security <https://www.postgresql.org/docs/current/ddl-rowsecurity.html> ·
  `CREATE POLICY` <https://www.postgresql.org/docs/current/sql-createpolicy.html> ·
  `SET`/`SET LOCAL` <https://www.postgresql.org/docs/current/sql-set.html> ·
  `current_setting`/`set_config` <https://www.postgresql.org/docs/current/functions-admin.html>
- pgx prepared-plan + `IMMUTABLE` footgun — <https://github.com/jackc/pgx/issues/2007>
- This workspace — roles: `packages/nix/core/services/postgres/default.nix` ·
  two-scope model: ADR-0008 (`docs/adrs/0008-tenant-scoped-unit-of-work-rls.md`) ·
  safe system reads: ADR-0009 (`docs/adrs/0009-safe-system-scope-rls.md`) ·
  self-keyed org-root RLS: ADR-0011 (`docs/adrs/0011-org-root-rls-hardening.md`) ·
  chokepoints: `uow.go`, `readstore.go` · ports: `app/command/port.go`,
  `app/query/port.go` · typed UUIDv7 IDs: ADR-0004
