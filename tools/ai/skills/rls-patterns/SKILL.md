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

**Needs RLS** — non-null `organization_id`, reached by `writer`/`reader`:
`staff` and every org-scoped aggregate; per-org config / credentials / feature
flags; org-scoped outbox / event / read-model tables; soft-delete siblings
(policies do NOT propagate — each table enables independently).

**No RLS** — `organizations` (the tenant root; chicken-and-egg — gate with
column-scoped `GRANT`s instead); cross-tenant reference data (currencies, time
zones); admin-only tables (`admin` bypasses RLS anyway).

## Canonical migration (org-scoped table)

Goose, run as `admin`. RLS lives in the SAME file as the `CREATE TABLE`. IDs are
`TEXT` UUIDv7 (ADR-0004) — compare as text, no `::uuid` cast.

```sql
-- +goose Up
-- +goose StatementBegin
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff FORCE  ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_staff ON staff
    AS PERMISSIVE FOR ALL TO writer, reader
    USING      (current_setting('app.scope', true) = 'system'
                OR organization_id = current_setting('app.organization_id', true))
    WITH CHECK (current_setting('app.scope', true) = 'system'
                OR organization_id = current_setting('app.organization_id', true));
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP POLICY IF EXISTS tenant_isolation_staff ON staff;
ALTER TABLE staff NO FORCE ROW LEVEL SECURITY;
ALTER TABLE staff DISABLE  ROW LEVEL SECURITY;
-- +goose StatementEnd
```

Two scopes on one axis (ADR-0008): an `organization` actor binds
`app.organization_id`; a `system` actor (cross-tenant jobs / future back-office,
**still `NOBYPASSRLS`** — never run as `admin`) binds `app.scope = system`. An
unbound tx matches neither branch and fails closed. Gate *who* may bind `system`
at the app layer — RLS only enforces the data boundary. The portal is
tenant-facing and uses `organization` scope only; `system` entry points are planned.

Also required in the same file:

- `organization_id TEXT NOT NULL` and `CREATE INDEX idx_<table>_organization_id` —
  the policy filters on it; confirm with `EXPLAIN (ANALYZE, BUFFERS)`.
- No per-table `GRANT`s: `writer`/`reader` already hold schema-wide CRUD/SELECT
  plus `ALTER DEFAULT PRIVILEGES` from the postgres devenv module. Add explicit
  `GRANT`s only for a column-scoped exception (e.g. locking down `organizations`).

## Binding chokepoint (don't reinvent)

Writes flow through `UnitOfWork.DoOrganizationTransaction(ctx, orgID, handler)`
(`services/portal/internal/infra/postgres/uow/uow.go`); reads through
`ReadStore.DoOrganizationQuery` (`.../readstore/readstore.go`). Both validate the
id and call `bindOrganizationRLS` (`set_config(..., true)`) as the first
statement. The org id is a REQUIRED parameter — there is no org-less write path.
Connect gormx with the `writer`/`reader` DSN, never `admin`.

## Isolation test (must run as writer/reader)

Against a `writer`/`reader` connection — never `admin`, or the policy is a silent
no-op:

1. Assert `SELECT rolsuper OR rolbypassrls ... = false`.
2. org A inserts a row; org B must see 0.
3. Cover: unset-GUC fails closed (0 rows); `WITH CHECK` rejects a foreign-org
   `Create`; cross-org UPDATE/DELETE affect 0 rows; `FORCE` applies to the owner;
   an invalid id is rejected (`organization.ErrEmptyID`) before any row is touched.

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
  chokepoints: `uow.go`, `readstore.go` · ports: `app/command/port.go`,
  `app/query/port.go` · typed UUIDv7 IDs: ADR-0004
