# Database Role and Scope Contract

> **Scope**: every service that opens an application connection to the workspace Postgres database (`services/**`), and the shared DB helpers in `packages/go/**` (`gormx`, `migrate`).
> **Status**: Active
> **Decided by**: [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md), [ADR-0011](../../adrs/0011-org-root-rls-hardening.md)
> **Last reviewed**: 2026-06-29

**Rule.** Connect application traffic as the `NOBYPASSRLS` `writer` (commands) or `reader` (queries) role, never `admin`, and bind exactly one transaction-local scope GUC — `app.organization_id` for the `organization` scope, `app.scope = system` for the `system` scope — as the first statement of every transaction.

**Rationale.** Row-Level Security is the *authority* for tenant isolation ([ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md)) — it removes the "forgot a `WHERE organization_id = ?`" class of cross-tenant leak by construction. RLS only holds if two invariants are never broken: the connection must be a role that RLS actually applies to (`admin` is `SUPERUSER`/`BYPASSRLS` and silently makes every policy a no-op), and the request scope must be set *transaction-locally* (a session-level `SET` leaks one request's scope to the next checkout of a pooled connection — a silent cross-tenant leak). This contract is the single set of names and roles every service and policy must agree on; if they drift, isolation fails quietly.

**Apply.**

- **Roles** (provisioned by `core.services.postgres`, see `packages/nix/core/services/postgres/default.nix`):
  - `admin` — `SUPERUSER`, database owner, **`BYPASSRLS`**. Migrations only (goose via `migrate-up`), never request traffic.
  - `writer` — `NOBYPASSRLS`, schema-wide `SELECT, INSERT, UPDATE, DELETE`. The command (write) side connects as this.
  - `reader` — `NOBYPASSRLS`, schema-wide `SELECT`. The query (read) side connects as this.
- **GUC contract** — two transaction-local settings, bound via `set_config(name, value, true)` (the third arg `true` = `is_local`, so it reverts on COMMIT/ROLLBACK):

  | Scope          | `app.scope`    | `app.organization_id` | Row visibility                  | Bound by                                  |
  | -------------- | -------------- | --------------------- | ------------------------------- | ----------------------------------------- |
  | `organization` | *(unset)*      | the tenant's id       | rows of that one organization   | per-tenant CMS, per-tenant jobs           |
  | `system`       | `system`       | *(unset)*             | all organizations' rows         | cross-tenant jobs; future back-office svc |
  | *(unbound)*    | *(unset)*      | *(unset)*             | none — fails closed (zero rows) | nobody; the safety default                |

- **Bind first, inside a transaction.** Validate any tenant id as a UUIDv7 (`idgen.Validate`) before binding; bind the scope as the first statement; run the rest of the unit of work in the same transaction. There is no scope-less runtime path — an unbound transaction matches no policy branch and returns zero rows.
- **`system` widens, it does not bypass.** Both scopes run under the `NOBYPASSRLS` app roles; `system` satisfies the policy via `app.scope = system`, so cross-tenant access is still constrained and auditable by the same `FORCE`d policy. Never reach for `admin`/`BYPASSRLS` to "just see everything".
- **The tenant root is policy-protected too.** `organizations` has no `organization_id` (it *is* the tenant), but it is **not** an RLS exemption: it carries a `FORCE`d policy keyed on the row's own `id = current_setting('app.organization_id', true)` ([ADR-0011](../../adrs/0011-org-root-rls-hardening.md)). The `organization` scope binds the same `app.organization_id` GUC for the root table as for org-scoped tables — registration binds the new org's id before inserting its root row, so the self-keyed `WITH CHECK` admits the bootstrap insert while every other access stays constrained to the bound org.
- For the policy SQL, migration workflow, and worked `staff` example, follow the [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) — this rule fixes the *names and roles*; the skill is the *how-to*.

**Examples.**

✓ Good:
```go
// Command side: writer role DSN, organization scope bound transaction-locally.
func (u *UnitOfWork) DoOrganizationTransaction(ctx context.Context, id organization.ID, handler command.TransactionalUnitOfWorkHandler) error {
	return u.db.Transaction(func(tx *gorm.DB) error {
		if err := idgen.Validate(id); err != nil { // validate before binding
			return organization.ErrEmptyID
		}
		// first statement: transaction-local (is_local = true)
		if err := tx.WithContext(ctx).
			Exec(`select set_config('app.organization_id', ?, true)`, id.String()).Error; err != nil {
			return fmt.Errorf("%w: %w", ErrOrganizationRLSCannotBeBound, err)
		}
		return handler(ctx, newTxUnitOfWork(tx))
	})
}
```

✗ Bad:
```go
// Connects as admin (BYPASSRLS) and uses a session-level SET.
// Every policy becomes a silent no-op, and the scope leaks to the next
// request that checks out this pooled connection.
db.Exec(`SET app.organization_id = '...'`) // session scope — leaks across pool
adminDB.Find(&staff)                        // admin bypasses RLS entirely
```

**Enforcement.** Code review + the database itself. The `FORCE`d RLS policy fails closed (zero rows) for any unbound or wrongly-scoped transaction, so a missed binding surfaces as missing data, not a silent leak. Connecting as `admin` for request traffic is caught in review and by the role split in `core.services.postgres` (services are configured with `writer`/`reader` DSNs, not `admin`). Verify a live connection is constrained with `SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user` — it must return `false`.

## See also

- [Database conventions index](README.md)
- [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md) — the decision that established RLS authority and the two scopes.
- [ADR-0011](../../adrs/0011-org-root-rls-hardening.md) — the tenant-root (`organizations`) self-keyed RLS hardening.
- [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) — policy authoring, migration workflow, worked `staff` example.
- [Service architecture § Unit of Work](../go/service-architecture.md#unit-of-work) — the Go-side UoW / Read Store that binds the scope.
- [Portal database schema](../../../services/portal/docs/specs/database-schema.md) — the portal data dictionary that applies this contract per table.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [`set_config` / `current_setting`](https://www.postgresql.org/docs/current/functions-admin.html)
