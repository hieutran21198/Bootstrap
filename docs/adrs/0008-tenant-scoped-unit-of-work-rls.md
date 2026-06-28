# 0008. RLS tenant isolation with organization and system scopes

- **Status**: Accepted
- **Date**: 2026-06-28
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The platform is multi-tenant: every org-scoped table (`staff`, and every future aggregate carrying `organization_id`) holds rows belonging to many organizations in one physical table. [ADR-0003](0003-service-architecture.md) established the Unit of Work as the write-side transaction boundary, [ADR-0005](0005-collection-style-repositories.md) made writers single-mission (`Create` / `Update`, no callbacks), and the CQRS read side queries through a separate read store.

Tenant isolation could be left to application discipline — every query remembering `WHERE organization_id = ?`. A single missed predicate is then a silent cross-tenant data leak, on the read path, the write path, or both, with no compile-time or database-level guarantee. Postgres Row-Level Security (RLS) exists to move that boundary into the database so it cannot be forgotten. RLS only works if the application sets a request context (a GUC) on the connection inside each transaction, and only if that context is bound at **every** connection-scoped entry point — a single unbound path reopens the leak.

But the platform has **two kinds of actor**, not one, and they need different row visibility:

- **Tenant-facing surfaces** (the portal, where a tenant manages itself, and per-tenant background jobs) act *inside one organization* and must see only that org's rows.
- **Cross-tenant actors** (background jobs that run platform-wide rollups or maintenance, and a future separate back-office service that supports any customer) act *above* any single tenant and must see across organizations.

A model with only an organization context cannot express the second actor: a cross-tenant job or back-office request has no single org to bind. So isolation needs **two named scopes on one axis**, not a single tenant context plus ad-hoc bypasses. The pre-RLS data-access surface also exposed **auto-commit paths**: a bare `Create(...)` ran as a single statement outside any transaction, with no transaction in which to bind a scope transaction-locally.

We needed one decision: what is the authority for tenant isolation, and what scopes does the application bind to uphold it uniformly across writes, reads, and schema changes?

## Decision

**Postgres RLS is the authority for tenant isolation, and the application binds one of two named scopes — `organization` or `system` — transaction-locally at every connection-scoped entry point.** Scope is a property of the *unit of work*, not of the actor: a worker binds whichever scope a given job requires.

Org-scoped tables carry a `FORCE`d policy that passes a row when **either** the bound scope is `system` **or** the bound `organization_id` matches the row. Application roles (`writer`, `reader`) are `NOBYPASSRLS` for both scopes — `system` widens the policy predicate, it does not bypass RLS.

The contract is two transaction-local GUCs:

| Scope          | `app.scope`    | `app.organization_id` | Row visibility                     | Bound by                                  |
| -------------- | -------------- | --------------------- | ---------------------------------- | ----------------------------------------- |
| `organization` | `organization` | the tenant's id       | rows of that one organization      | per-tenant CMS, per-tenant jobs           |
| `system`       | `system`       | unset                 | all organizations' rows            | cross-tenant jobs; future back-office svc |
| *(unbound)*    | unset          | unset                 | none — fails closed (zero rows)    | nobody; the safety default                |

Policy predicate: `current_setting('app.scope', true) = 'system' OR organization_id = current_setting('app.organization_id', true)`.

Three components apply this:

1. **Unit of Work (writes)** — `command.UnitOfWork`, which binds the scope before handing the handler a `TransactionalUnitOfWork`.
2. **Read Store (reads)** — `query.ReadStore`, which binds the scope before handing the handler a `TransactionalReadStore`.
3. **Migrations (schema)** — run as `admin` (SUPERUSER, BYPASSRLS), the place where the policies themselves are defined. `admin` is the only BYPASSRLS path and is never used at request time.

The runtime entry points share one shape. Inside a single `db.Transaction`, each:

1. **Validates** any tenant id as a UUIDv7 (`idgen.Validate`); an invalid or empty id aborts before any statement runs (the `organization` scope requires an id; the `system` scope does not).
2. **Binds the scope** as the first statement via `set_config(..., true)` — transaction-local (`is_local = true`), so it reverts on COMMIT/ROLLBACK and a pooled connection never leaks one request's scope to the next.
3. **Runs the handler** with a fresh scoped accessor (`TransactionalUnitOfWork` for writes, `TransactionalReadStore` for reads).

There is **no scope-less runtime path** — neither an auto-commit write nor an unbound read. An unbound transaction fails closed (zero rows) against the `FORCE`d policy.

**Implementation status.** The `organization` scope is implemented today: `DoOrganizationTransaction` / `DoOrganizationQuery` bind `app.organization_id` via `bindOrganizationRLS`. The portal is a **tenant-facing** service — a tenant manages itself — so it uses the `organization` scope exclusively and never binds `system`. The `system` scope is part of this accepted model but **not yet in code** — it needs a `bindSystemScope` binder, `system`-scoped entry points (e.g. `DoSystemTransaction` / `DoSystemQuery`), and the migration that defines the `app.scope`-aware policy (the init migration creates tables only, no policy yet). Its first consumer is the **cross-tenant background-job / worker** path (platform-wide rollups, maintenance); a **separate back-office service** that supports any customer is a later consumer of the same model. Both are out of scope for this ADR.

For a service that is **genuinely not multi-tenant** (no tenant boundary, no RLS), the scope-less variant `DoTransaction(ctx, handler)` is the documented escape hatch. It is kept commented out in `uow.go` and must be enabled deliberately — the exception, not the default.

## Consequences

- **Positive**:
  - Tenant isolation is enforced by the database (RLS), not by remembering a `WHERE` clause — the failure mode (missed predicate) is eliminated by construction, on reads and writes alike.
  - One axis, two named scopes: tenant-facing services (the portal), cross-tenant jobs, and a future back-office service all bind `organization` or `system` through the same mechanism, so there is one isolation model to reason about — no ad-hoc bypass paths.
  - `system` is still RLS-on (`NOBYPASSRLS`): a cross-tenant actor's queries are audited and constrained by the same policy, never silently unfiltered.
  - Scope is bound transaction-locally, so it is pool-safe — no session-state leakage between requests sharing a pooled connection.
  - The org id is a **required, explicit parameter** on the `organization` entry points, and selecting `system` is an explicit, named choice — an actor cannot start work without declaring its scope.
- **Negative**:
  - Auto-commit convenience is gone — even a one-aggregate write must wrap a closure and declare a scope, and reads must open a transaction. Slightly more ceremony per call site.
  - The GUC contract (`app.scope`, `app.organization_id`) is split across several places — the UoW, the read store, and every table policy. They must stay in sync; the `rls-patterns` skill documents the contract but cannot mechanise it.
  - `system` scope is a sharp tool: a bug in a cross-tenant job (or the future back-office) runs against every tenant's rows at once. Authorization (who may bind `system`) must gate it at the application layer — RLS only enforces the data boundary, not who is allowed to widen it.
- **Neutral**:
  - The two-struct accessor shape from [ADR-0003](0003-service-architecture.md) is unchanged on both sides; the embedded root-db accessor exists only to satisfy the accessor surface at construction, never as an auto-commit path.
  - Builds on the existing `admin`/`writer`/`reader` role split — the app connects as `writer`/`reader` (NOBYPASSRLS) for **both** scopes; `admin` (superuser) runs migrations and bypasses RLS by design.
  - Scope is orthogonal to authorization. `staff.Role` (`owner`/`admin`/`member`) governs what an actor may *do* inside an org; the platform-operator role (future) governs who may bind `system`. Neither is an RLS scope.

## Alternatives considered

- **One organization scope only; let cross-tenant actors bypass RLS (run as superuser).** Rejected: it makes the most powerful, least tenant-bound actors (cross-tenant jobs, the future back-office) the ones with no database-level guardrail — a single bug becomes a cross-tenant breach. The `system` scope keeps cross-tenant access under the same `FORCE`d policy and the same `NOBYPASSRLS` role.
- **Filter in Go (`WHERE organization_id = ?`) instead of RLS.** Rejected: defense-in-depth at best, authority at worst. One forgotten predicate leaks data, with no compile-time or database-level guarantee. RLS removes the whole class of bug; app-side filtering can sit on top but must not replace it.
- **Bind a scope on writes only, leave reads to Go-side filtering.** Rejected: it splits isolation across two mechanisms and leaves the read path — the most common path — the least protected. Binding the same scope on both sides keeps one authority and one failure model.
- **Carry the scope in `ctx` and read it implicitly inside the entry points.** Rejected: it hides a hard requirement behind an implicit channel. An explicit scope choice (and an explicit `organization.ID` for the org scope) makes "you must declare your scope" a call-site fact, not a runtime surprise.
- **Session-scoped `SET` instead of transaction-local `set_config(..., true)`.** Rejected: session scope persists across the connection, so a pooled connection carries one request's scope into the next checkout — a silent cross-tenant leak. Transaction-local is the only pool-safe option.
- **A third explicit scope for workers.** Rejected: a worker has no inherent scope — each job is either per-tenant (`organization`) or cross-tenant (`system`). Scope belongs to the unit of work, so two scopes cover every actor; a "worker" scope would just be `system` under another name.

## References

- [`docs/conventions/go/service-architecture.md` § Unit of Work](../conventions/go/service-architecture.md#unit-of-work) — the convention this ADR updates (write and read variants documented there).
- [ADR-0003](0003-service-architecture.md) — established the UoW as the write-side transaction boundary.
- [ADR-0004](0004-typed-aggregate-ids-uuidv7.md) — typed UUIDv7 IDs stored as `TEXT`; the org id validated here is one.
- [ADR-0005](0005-collection-style-repositories.md) — single-mission writers; read-modify-write composed inside the UoW.
- `services/portal/internal/infra/postgres/uow/uow.go` — `DoOrganizationTransaction` + `bindOrganizationRLS` (write-side, `organization` scope; `system`-scope entry point planned).
- `services/portal/internal/infra/postgres/readstore/readstore.go` — `DoOrganizationQuery` + `bindOrganizationRLS` (read-side, `organization` scope; `system`-scope entry point planned).
- `services/portal/internal/app/command/port.go` — `UnitOfWork` / `TransactionalUnitOfWork` / `TransactionalUnitOfWorkHandler` (write port).
- `services/portal/internal/app/query/port.go` — `ReadStore` / `TransactionalReadStore` / `TransactionalReadStoreHandler` (read port).
- `services/portal/internal/infra/postgres/migrations/` — schema + RLS policy definitions, run as `admin` via `migrate-up` (the `app.scope`-aware policy is the planned migration).
- `rls-patterns` skill — `packages/nix/core/ai/skills/db-rls-patterns/` — policy authoring + the `app.scope` / `app.organization_id` GUC contract.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [`set_config` / `current_setting`](https://www.postgresql.org/docs/current/functions-admin.html)
