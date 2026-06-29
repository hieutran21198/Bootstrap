# System-scope RLS read path

> **Status**: Implemented
> **Authors**: Minh Hieu Tran <hieu.tran21198@gmail.com>
> **Last reviewed**: 2026-06-29
> **Tracks**: [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md), [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md)

> **Implementation status:** The four layers (dedicated `system_reader` role, split RLS policy, capability gate, read-side `DoSystemQuery`) are written and the portal compiles. The migrations are **not yet applied** to a database, and there is **no runtime consumer** wired up — the portal is tenant-facing and never binds `system`. The first consumer (a cross-tenant worker) is a separate binary, not built here.

## Problem

[ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md) decided how to handle the cross-tenant `system` scope safely. This spec is the concrete build: the exact Postgres role, policy, Go types, and read entry point that realise the decision — so a contributor can see what exists, how the four layers fit, and where the boundary is enforced.

## Goals

- A dedicated `system_reader` Postgres role with its own read policy (not an `OR` branch on `writer`/`reader`).
- An app-layer capability gate that makes "who may bind `system`" a typed, unforgeable fact.
- A read-only `DoSystemQuery` entry point that binds the scope + an org allowlist transaction-locally.
- Fail-closed everywhere: forged capability, missing allowlist, or `system` on a tenant role all yield zero rows / an error.

## Non-goals

- **System writes.** There is no `DoSystemTransaction`; that needs its own ADR, a `system_writer` role, and per-table `WITH CHECK` policies (ADR-0009).
- **A concrete authorizer / consumer.** This spec ships the gate type (`SystemScopeAuthorizer`) and the entry point; the allowlist-of-permitted-workers implementation and the worker binary arrive with the first real consumer.
- **Wiring `system_reader` into the portal.** The role is disabled by default and must never be wired into the tenant-facing portal binary.

## Background

The `organization` scope (the tenant-facing path) is implemented in `uow.go`/`readstore.go` and binds `app.organization_id` transaction-locally. The `system` scope reuses that shape but on a separate role + policy + GUC, per [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md) and the [role and scope contract](../../../../docs/conventions/database/role-and-scope-contract.md).

## Design

### Layer 1 — dedicated `system_reader` role (Nix)

`packages/nix/core/services/postgres/default.nix` provisions `system_reader` alongside `admin`/`writer`/`reader`: a `NOBYPASSRLS` login role with schema `SELECT`, **disabled by default** (`core.services.postgres.roles.systemReader.enable = false`). It exposes `POSTGRES_SYSTEM_READER_USER`/`_PASSWORD` only when enabled. Cross-tenant visibility comes from the policy below, not from the grant — an un-opted table simply yields no rows for this role.

### Layer 2 — split policy (migration)

`services/portal/internal/infra/postgres/migrations/20260629000001_staff_rls.sql` puts two policies on `staff`:

- `tenant_isolation_staff` — `FOR ALL TO writer, reader`, the `organization` scope.
- `system_read_staff` — `FOR SELECT TO system_reader`:

  ```sql
  USING (
      current_setting('app.scope', true) = 'system'
      AND (
          current_setting('app.organization_allowlist', true) = '*'
          OR organization_id = ANY (
              string_to_array(current_setting('app.organization_allowlist', true), ',')
          )
      )
  )
  ```

  The tenant-facing roles have **no** `system` branch, so `app.scope='system'` on a `writer`/`reader` connection matches nothing and fails closed. A missing allowlist → `NULL` → neither branch → zero rows.

### Layer 3 — capability gate (app/query)

`services/portal/internal/app/query/system_scope.go` defines the gate:

- `SystemReadCapability` — unexported fields, `minted` flag; only [`NewSystemReadCapability`] sets it. A zero-value/forged capability has `IsValid() == false`.
- `SystemTarget` — constructed only via `AllOrganizations()` (`*`) or `OnlyOrganizations(ids)`; the capability carries the target so a caller cannot authorize one target and bind another.
- `SystemScopeAuthorizer` — the interface that mints capabilities after authorizing a `SystemPrincipal` + target + purpose. Implementations (an allowlist of worker names, etc.) arrive with the consumer.
- `purpose` is required (`ErrEmptySystemPurpose`) and recorded for audit.

### Layer 4 — read entry point (infra/readstore)

`ReadStore.DoSystemQuery(ctx, cap, handler)`:

1. Rejects an invalid capability (`ErrInvalidSystemCapability`).
2. Opens a transaction; `bindSystemRLS` sets `app.scope='system'` and `app.organization_allowlist` (transaction-local) from the capability's target — validating each id as UUIDv7 for `OnlyOrganizations`.
3. Runs the handler against a tx-scoped `TransactionalReadStore` (connected as `system_reader`).

There is no `DoSystemTransaction`; the write port is untouched.

### Boundary summary

| Layer | Enforces |
| ----- | -------- |
| `system_reader` role | least-privilege connection; `NOBYPASSRLS` |
| `system_read_staff` policy | the data boundary — which rows, fail-closed |
| capability gate | who may bind `system` (app-layer authorization) |
| `DoSystemQuery` | read-only, allowlist binding, no write path |

## Alternatives considered

- **Reuse `writer`/`reader` with an `OR` policy.** Rejected by [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md): a missed app-layer gate would expose every tenant; the separate role makes the database the backstop.
- **Build the worker/authorizer now.** Out of scope: no consumer exists. The gate type + entry point keep the door open without shipping an unused cross-tenant binary.

## Open questions

- The concrete `SystemScopeAuthorizer` (worker allowlist? capability token? time-bound?) is undecided until the first consumer. Owner: whoever builds the cross-tenant worker.
- Audit sink: `purpose`/`principal` are carried but not yet written to an audit row inside the transaction. Owner: same.

## Implementation plan

- [x] `system_reader` role in the postgres devenv module (disabled by default).
- [x] `system_read_staff` policy in `20260629000001_staff_rls.sql`.
- [x] Capability types + `SystemScopeAuthorizer` in `app/query/system_scope.go`.
- [x] `DoSystemQuery` + `bindSystemRLS` in `readstore.go`; portal compiles.
- [ ] Apply migrations + RLS isolation tests (two-tenant + cross-tenant `system_reader`).
- [ ] A concrete `SystemScopeAuthorizer` + audit row + the worker binary — with the first consumer.
- [ ] `DoSystemTransaction` (system writes) — separate ADR.

## References

- [ADR-0009](../../../../docs/adrs/0009-safe-system-scope-rls.md) — the decision this spec implements.
- [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md) — the two-scope RLS model.
- [Database role and scope contract](../../../../docs/conventions/database/role-and-scope-contract.md) — roles + GUCs.
- [Portal database schema](database-schema.md) — the `staff` policies in the data dictionary.
- `services/portal/internal/app/query/system_scope.go` — capability gate.
- `services/portal/internal/infra/postgres/readstore/readstore.go` — `DoSystemQuery` + `bindSystemRLS`.
- `services/portal/internal/infra/postgres/migrations/20260629000001_staff_rls.sql` — the policies.
- `packages/nix/core/services/postgres/default.nix` — the `system_reader` role.
