# 0005. Replace callback-style repository Update with collection-style Create + Update

- **Status**: Accepted
- **Date**: 2026-06-26
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: [ADR-0003](0003-service-architecture.md) §4 (Decision part 4 — port shape only; the other five parts of ADR-0003 stand)
- **Superseded by**: -

## Context

[ADR-0003](0003-service-architecture.md) §4 defined the Writer port shape as:

```go
type Writer interface {
    Save(ctx context.Context, o *Organization) error
    Update(
        ctx context.Context,
        id ID,
        updateFn func(ctx context.Context, o *Organization) (*Organization, error),
    ) error
}
```

The callback-style `Update` was inherited from [ThreeDotsLabs Wild Workouts](https://github.com/ThreeDotsLabs/wild-workouts-go-ddd-example), where Firestore exposes transactions as a closure (`fs.RunTransaction(ctx, func(tx *fs.Transaction) error { ... })`). Wild Workouts mirrors that shape at the repository layer because it had no other place to bind read-modify-write atomicity.

We have postgres plus a Unit-of-Work pattern ([ADR-0003](0003-service-architecture.md) §5) that already owns transactional scope. The callback inside the repo therefore double-books on the same concern, and shows up as several smaller defects:

1. **Two layers own atomicity.** The handler can wrap a `DoTransaction` *and* call `Writer.Update(updateFn)`, which itself opens a transaction. The interaction (gorm savepoints) works, but the model becomes "atomicity is wherever you happen to look", not "atomicity is the UoW".
2. **Repository methods read as ad-hoc.** `Update(ctx, id, updateFn)` does not name a single mission — it loads, mutates via a caller-supplied closure, and persists. The classical DDD repository (Evans, Vernon) is collection-like: `Add`, `Get`, `Save` — methods that name what the collection does.
3. **Call sites carry closure noise.** Every read-modify-write at the handler level is `uow.Xs().Update(ctx, id, func(ctx, x) (*X, error) { ... return x, nil })`. The closure is structurally needed only because the repo demands it; with explicit `Update(ctx, *T)`, the handler reads "load, mutate, save" line-by-line in straight code.
4. **The repo's transaction can mask serialization conflicts.** "Adapters MAY retry updateFn on serialization conflicts; updateFn MUST be idempotent" was a written contract — but retry policy belongs at the orchestration layer (UoW or the application handler), not in every aggregate's repo.

The user objected to the callback shape directly, with the framing "*Repository needs to resolve clear mission*". That framing matches Evans/Vernon's collection-style repository and is what we want.

## Decision

We replace the callback `Update` with two collection-style methods. The Writer port is now:

```go
// services/portal/internal/domain/organization/port.go
type Writer interface {
    Create(ctx context.Context, o *Organization) error
    Update(ctx context.Context, o *Organization) error
}
```

Concretely:

1. **`Create(ctx, *T) error`.** Inserts a new aggregate. The underlying primary-key constraint rejects duplicates; the error propagates back unwrapped except for repo-prefixed `fmt.Errorf`.
2. **`Update(ctx, *T) error`.** Overwrites the persisted state of an existing aggregate, keyed on `T.ID()`. Returns `NotFoundError` when no row matches (postgres adapter detects this via `RowsAffected == 0`). The aggregate handed in is the result of a previous load + in-memory mutation; the repo does not load, mutate, or re-validate.
3. **No internal transactions.** Each method issues a single statement. Atomicity for read-modify-write is composed by the caller through `UnitOfWork.DoTransaction`. The closure does the load (`utx.Xs().ByID`), the in-memory mutation (aggregate methods), and the persist (`utx.Xs().Update`) explicitly.
4. **No `Save` upsert.** `Create` and `Update` are separate missions. An `Update` against a deleted row fails loudly with `NotFoundError`; a `Save` upsert would silently re-create it.

The postgres adapter implements `Update` with `Select("*").Updates(&row)` so zero values (e.g., `Deactivated=false`) are written, and inspects `RowsAffected` to distinguish "row updated" from "row not found".

This decision narrows ADR-0003 §4 only. The other five parts of ADR-0003 (layer split, DDD aggregates, value objects, CQRS port split, UoW pattern, postgres repo shape) stand unchanged.

## Consequences

- **Positive**:
  - **One layer owns atomicity.** `UnitOfWork.DoTransaction` is the only place transactions start; repo methods are stateless single-statement writers. The mental model collapses to one node.
  - **Each repository method has one clear mission.** Read the method name; know what happens. `Create` inserts. `Update` overwrites by ID. No closure indirection at the call site.
  - **`Update` fails loudly on missing rows.** A handler that updates an aggregate it expected to find gets `NotFoundError`, not a silent re-insert. The compile-time + runtime contract is sharper.
  - **Composability.** The handler can mix multiple aggregate updates inside one `DoTransaction` closure with linear straight-line code. No nested closures, no `updateFn` boilerplate.
  - **Aligns with classical DDD repository.** Evans' *Domain-Driven Design* and Vernon's *Implementing Domain-Driven Design* both treat the repository as a collection-like interface (`Add`, `Get`, `Remove`, `Save`). Our `Create` + `Update` is that shape, split for stricter insert/update semantics.
- **Negative**:
  - **Caller must remember to wrap in `DoTransaction`** when atomicity matters. With the callback, atomicity was automatic. The mitigation is the existing `TransactionalUnitOfWork` type — handlers that MUST run inside a transaction depend on the narrower type, which has no `DoTransaction` and only resolves through a `DoTransaction` closure.
  - **One more line at read-modify-write call sites.** The pattern is now `load → mutate → Update` instead of one `Update(callback)`. Acceptable cost: the three lines name three distinct operations.
  - **Retry-on-serialization-conflict policy moves out of the repo.** A future need for retries lives in UoW (or in a handler decorator) — neither the repo nor the aggregate cares. The trade-off is intentional: cross-cutting orchestration is not the repo's job.
- **Neutral**:
  - **Diverges from Wild Workouts** at one specific point (repo signature). The rest of the DDD + Hexagonal pattern is unchanged. The translation cost for newcomers from Wild Workouts is documented here.
  - **Compatible with [ADR-0003](0003-service-architecture.md) §5 (UoW pattern)** without changes. `TransactionalUnitOfWork` already exposes `Organizations() organization.Writer` — the new Writer signatures are returned by the same accessor.
  - **Builds on [ADR-0004](0004-typed-aggregate-ids-uuidv7.md).** The aggregate carries its typed `ID`; `Update` reads it via `o.ID()` rather than taking it as a separate parameter, which makes the "this aggregate, not some other one" intent explicit.

## Alternatives considered

- **Keep the callback `Update(ctx, id, updateFn)`** (the original ADR-0003 §4 shape). Rejected because it double-books atomicity with the UoW, makes every read-modify-write call site noisier with closure boilerplate, and gives the repository a method whose mission cannot be named in one verb. The Firestore-shaped constraint that forced this pattern in Wild Workouts does not exist in postgres + UoW.
- **Single `Save(ctx, *T) error` upsert** (insert if missing, update if present). Rejected because it masks the distinction between insert and update at the type level. An `Update` against a deleted aggregate should fail with `NotFoundError`, not silently re-create the row. The split costs nothing and catches more bugs.
- **Method-per-mutation** (`Rename(ctx, id, newName)`, `Deactivate(ctx, id)`, ...). Rejected because it duplicates domain behavior at the repo level — the aggregate already has `Rename` and `Deactivate` methods that enforce invariants. Each domain mutation would need a matching repo method and a matching SQL statement, and every new business rule would touch both. The collection-style `Update(ctx, *T)` lets the aggregate own the mutation logic and the repo own only the persistence.
- **Optimistic concurrency via a `version` column.** Considered as a side concern — not part of *this* decision. Optimistic concurrency is a separate ADR if and when contention shows up empirically; nothing about `Create` + `Update` precludes adding a `version`-checked `Update` later, by the same handler-orchestrated pattern.

## References

- [ADR-0003](0003-service-architecture.md) — the parent architectural decision; this ADR narrows §4 only.
- [`docs/conventions/go/service-architecture.md` § Ports (CQRS-split)](../conventions/go/service-architecture.md#ports-cqrs-split) — the convention this ADR establishes (revised in place; conventions are living).
- [`services/portal/internal/domain/organization/port.go`](../../services/portal/internal/domain/organization/port.go) and [`services/portal/internal/domain/staff/port.go`](../../services/portal/internal/domain/staff/port.go) — the canonical Writer port shape.
- [`services/portal/internal/infra/postgres/repo/`](../../services/portal/internal/infra/postgres/repo/) — the postgres adapter implementing this shape.
- Eric Evans, *Domain-Driven Design: Tackling Complexity in the Heart of Software* — chapter 6, "Repositories", §149-152: the collection-like repository abstraction.
- Vaughn Vernon, *Implementing Domain-Driven Design* — chapter 12, "Repositories": collection-oriented vs persistence-oriented repository styles.
- [ThreeDotsLabs Wild Workouts](https://github.com/ThreeDotsLabs/wild-workouts-go-ddd-example) — the source of the callback-style shape we replaced; the pattern fits Firestore but not postgres + UoW.
