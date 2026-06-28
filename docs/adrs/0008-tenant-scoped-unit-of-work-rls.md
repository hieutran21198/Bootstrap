# 0008. Tenant-scoped Unit of Work enforcing Row-Level Security

- **Status**: Accepted
- **Date**: 2026-06-28
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The portal is a multi-tenant service: every org-scoped table (`staff`, and every future aggregate carrying `organization_id`) holds rows belonging to many organizations in one physical table. [ADR-0003](0003-service-architecture.md) established the Unit of Work as the write-side transaction boundary, and [ADR-0005](0005-collection-style-repositories.md) made writers single-mission (`Create` / `Update`, no callbacks) with read-modify-write composed by the caller inside the UoW.

The original UoW (`DoTransaction(ctx, handler)`) was **tenant-agnostic**. It opened a transaction and ran the handler, but nothing bound the caller's organization to the connection. That left tenant isolation entirely to discipline — every query would have to remember `WHERE organization_id = ?`, and a single missed predicate is a silent cross-tenant data leak. Postgres Row-Level Security (RLS) exists precisely to move that boundary into the database so it cannot be forgotten, but RLS only works if the application sets a tenant context (a GUC) on the connection inside each transaction.

The original design also exposed an **auto-commit path**: a bare `uow.Organizations().Create(...)` ran as a single statement outside any transaction. With RLS that path is unsafe — there is no transaction in which to bind the org GUC transaction-locally, so an auto-commit write either bypasses the policy or relies on session-scoped state that leaks across pooled connections.

We needed one decision: how does the UoW guarantee that every write is tenant-scoped, so RLS is the authority for isolation rather than hand-written `WHERE` clauses?

## Decision

We will make the Unit of Work **mandatorily tenant-scoped** for multi-tenant services. The `command.UnitOfWork` port exposes a single entry point:

```go
DoOrganizationTransaction(ctx context.Context, id organization.ID, handler TransactionalUnitOfWorkHandler) error
```

The postgres implementation, inside one `db.Transaction`:

1. **Validates** `id` as a UUIDv7 (`idgen.Validate`); an invalid or empty id returns `organization.ErrEmptyID` and aborts before any statement runs.
2. **Binds RLS** as the first statement via `bindOrganizationRLS`, which runs `select set_config('app.organization_id', ?, true)` — transaction-local (`is_local = true`), so it reverts on COMMIT/ROLLBACK and a pooled connection never leaks one request's org to the next.
3. **Runs the handler** with a fresh `TransactionalUnitOfWork` bound to that RLS-scoped transaction; every writer reached through it is filtered to the bound organization.

There is **no org-less / auto-commit write path** in a multi-tenant service: a single-aggregate write is just a one-line closure. Table policies read the same GUC name, `current_setting('app.organization_id', true)`.

For a service that is **genuinely not multi-tenant** (no tenant boundary, no RLS), the org-less variant `DoTransaction(ctx, handler)` is the documented escape hatch. It is kept commented out in `uow.go` and must be enabled deliberately — it is the exception, not the default.

## Consequences

- **Positive**:
  - Tenant isolation is enforced by the database (RLS), not by remembering a `WHERE` clause in every query — the failure mode (missed predicate) is eliminated by construction.
  - The org id is a **required, explicit parameter**, so a handler cannot start a write without declaring which tenant it acts on; the type system carries the invariant.
  - Transaction-local GUC binding is pool-safe: no session-state leakage between requests sharing a pooled connection.
  - Invalid tenant ids are rejected at the boundary (`idgen.Validate`) before any row is touched.
- **Negative**:
  - The auto-commit convenience is gone — even a one-aggregate write must wrap a closure and supply an org id. Slightly more ceremony per call site.
  - The query/read side (`readstore.ReadStore`) does not yet bind RLS; reads currently run on the root DB without a transaction. Enforcing RLS on reads is follow-up work (wrap each query in a `set_config`-first transaction).
  - The GUC name (`app.organization_id`) is a contract split across two places — the UoW and every table policy. They must stay in sync; the `rls-patterns` skill documents the contract but cannot mechanise it.
- **Neutral**:
  - The two-struct UoW shape from [ADR-0003](0003-service-architecture.md) is unchanged; the embedded root-db `txUnitOfWork` now exists only to satisfy the accessor surface at construction, never as an auto-commit path.
  - Builds on the existing `admin`/`writer`/`reader` role split — the app connects as `writer`/`reader` (NOBYPASSRLS); `admin` (superuser) runs migrations and bypasses RLS by design.

## Alternatives considered

- **Keep the tenant-agnostic `DoTransaction` and filter in Go (`WHERE organization_id = ?`).** Rejected: defense-in-depth at best, authority at worst. One forgotten predicate leaks data, and there is no compile-time or database-level guarantee. RLS removes the whole class of bug; app-side filtering can sit on top but must not replace it.
- **Carry the org id in `ctx` and read it inside `DoTransaction` (unchanged signature).** Rejected: it hides a hard requirement behind an implicit channel. A handler could call the method with no org in context and only fail at runtime. An explicit `organization.ID` parameter makes "you must name a tenant" a compile-time fact and keeps the dependency obvious at the call site.
- **Session-scoped `SET app.organization_id` instead of transaction-local `set_config(..., true)`.** Rejected: session scope persists across the connection, so a pooled connection carries one request's org into the next checkout — a silent cross-tenant leak. Transaction-local is the only pool-safe option.
- **Drop the auto-commit path entirely for all services, no escape hatch.** Rejected as over-reach: a future non-multi-tenant service has no tenant to bind and should not pay the org-id ceremony. The `DoTransaction` variant is retained, documented, and commented out — explicitly the exception.

## References

- [`docs/conventions/go/service-architecture.md` § Unit of Work](../conventions/go/service-architecture.md#unit-of-work) — the convention this ADR updates (both variants documented there).
- [ADR-0003](0003-service-architecture.md) — established the UoW as the write-side transaction boundary.
- [ADR-0004](0004-typed-aggregate-ids-uuidv7.md) — typed UUIDv7 IDs stored as `TEXT`; the org id validated here is one.
- [ADR-0005](0005-collection-style-repositories.md) — single-mission writers; read-modify-write composed inside the UoW.
- `services/portal/internal/infra/postgres/uow/uow.go` — `DoOrganizationTransaction` + `bindOrganizationRLS` (the implementation).
- `services/portal/internal/app/command/port.go` — `UnitOfWork` / `TransactionalUnitOfWork` / `TransactionalUnitOfWorkHandler` (the port).
- `rls-patterns` skill — `packages/nix/core/ai/skills/db-rls-patterns/` — policy authoring + the `app.organization_id` GUC contract.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [`set_config` / `current_setting`](https://www.postgresql.org/docs/current/functions-admin.html)
