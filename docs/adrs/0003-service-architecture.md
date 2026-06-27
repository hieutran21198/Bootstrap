# 0003. Adopt DDD + CQRS + Hexagonal architecture for services

- **Status**: Accepted
- **Date**: 2026-06-26
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: [ADR-0005](0005-collection-style-repositories.md) (§4 only — port shape; the other five Decision parts stand)

## Context

The portal service is the first service in this workspace. Its initial [`services/portal/AGENTS.md`](../../services/portal/AGENTS.md) set the broad shape — `cmd/http/{command,query}`, `internal/{app,delivery,domain,infra}` — but left several decisions implicit:

- What does an aggregate look like? Private fields with a factory? Anemic with public fields? ORM-tagged structs directly?
- Where does the repository interface live? Domain package? App package? A separate `ports/` package?
- How does CQRS show up at the persistence layer? Two interfaces? One interface with mixed methods? Per-handler interfaces?
- How do command handlers acquire transactional scope across multiple aggregates? `*sql.Tx` parameter? Context-bound? Unit of Work?
- How does the postgres adapter convert between aggregates and rows without leaking ORM tags into the domain?

The user's directive — *"use ThreeDotsLabs hexagonal DDD clean architecture"* — pointed at a specific reference: [ThreeDotsLabs Wild Workouts](https://github.com/ThreeDotsLabs/wild-workouts-go-ddd-example) and the long-form rationale in their book *Go with the Domain*. But Wild Workouts uses `ports/` and `adapters/` as the driving / driven layer names; the portal scaffold had already picked `delivery/` (driving) and `infra/` (driven). The user confirmed at decision time that the portal naming should win. The reconciliation needed to be written down once.

These decisions are stable across services. Every new service in this workspace should inherit them — otherwise each service relitigates aggregate shape, port shape, and transaction handling, and inconsistency creeps in.

## Decision

We adopt the patterns documented in [`docs/conventions/go/service-architecture.md`](../conventions/go/service-architecture.md) for every service module under `services/*/internal/`. The portal service is the canonical reference implementation.

The decision has six load-bearing parts:

1. **Layer split.** `cmd/http/{command,query}` (two HTTP binaries) + `internal/{app/{command,query}, delivery/http/{command,query}, domain/<aggregate>, infra/{postgres/{repo,uow}, zitadel}}`. Dependency direction: `delivery → app → domain ← infra`. `infra` and `delivery` never import each other.

2. **DDD aggregates.** Private fields; factory constructor `NewXxx(...) (*T, error)` validates all invariants; `UnmarshalXxxFromDatabase` is the only way to bypass validation (for repo adapters only); mutators use pointer receivers and return errors on rule violations; getters use value receivers; cross-aggregate references are by ID, never by pointer.

3. **Value objects.** Typed primitives (`type Email string`, `type Slug string`, `type Role string`) with constructor validation. The zero value is invalid. One value object per file.

4. **CQRS at the port level.** Each domain package's `port.go` contains `NotFoundError` (typed) + `Writer` interface (mutations only) + `Reader` interface (queries only). Never one interface with both. `Writer.Update(ctx, id, updateFn)` encapsulates read-modify-write inside a transaction via callback.

5. **Unit of Work pattern.** Interface in `app/command/port.go` (`UnitOfWork` composing a narrower `TransactionalUnitOfWork`); postgres implementation in `infra/postgres/uow/uow.go` via interface composition + struct embedding. Two modes through one accessor surface: auto-commit (single-aggregate writes via the embedded inner wrapper) and atomic transactional (multi-aggregate writes via `DoTransaction(ctx, fn)`).

6. **Postgres repo shape.** Private row struct with GORM tags lives next to the writer in `internal/infra/postgres/repo/<aggregate>.go`. Conversion via `xxxToRow` / `rowToXxx` helpers. Compile-time `var _ domain.Writer = (*XxxWriter)(nil)` assertion catches interface drift. GORM tags never appear on aggregate types.

The convention does NOT apply to `packages/go/` (see [ADR-0001](0001-single-responsibility-go-packages.md) — SRP category) or `tools/` (workspace generators, ad-hoc shape).

The aggregate identifier sub-decision (typed `ID` per aggregate, central `idgen` package, UUIDv7 algorithm) is its own ADR: [ADR-0004](0004-typed-aggregate-ids-uuidv7.md).

## Consequences

- **Positive**:
  - **One template per service.** New service contributors don't reinvent aggregate shape, port shape, or transaction handling — they copy the portal layout and substitute the aggregate name.
  - **Compile-time guard rails.** CQRS is enforced because `Writer` and `Reader` are separate types. The `var _ domain.Writer = (*XxxWriter)(nil)` assertion catches interface drift the moment a method signature changes. `TransactionalUnitOfWork` (narrower than `UnitOfWork`) lets handlers declare "must run inside a transaction" at the type level — there's no way to call `DoTransaction` from a `TransactionalUnitOfWork` value.
  - **Domain stays pure.** No GORM tags, no `*gorm.DB`, no `*sql.Tx` in `domain/`. Adapters convert at the package boundary; the domain has zero infrastructure imports.
  - **Transaction handles never leak.** Command handlers depend on `UnitOfWork`; they get accessor methods (`uow.Organizations()`, `uow.Staffs()`) returning typed `Writer` interfaces. `DoTransaction(ctx, fn)` opens transactions internally — the closure receives a `TransactionalUnitOfWork`, not a `*gorm.DB`.
  - **Read / write physically separated.** Two HTTP binaries (`cmd/http/command/main.go`, `cmd/http/query/main.go`) make CQRS a deployment fact, not just a code split. Future scaling (read replicas for the query side, leader-only writes for the command side) follows the binary boundary.
- **Negative**:
  - **More moving parts than CRUD.** Four layers (domain, app, delivery, infra), two binaries (command, query), and the UoW pattern add cognitive overhead. A trivial service (e.g., a health-check endpoint) is over-engineered with this shape — but the workspace is not optimising for trivial services.
  - **The two-binary split** assumes deployment can run two processes. Some hosting models (e.g., a single Cloud Run service per logical service) require manual reconciliation — either deploy two Cloud Run services or bundle both binaries behind a single dispatcher.
  - **Repository abstraction has cost.** Every command handler goes through `uow.Xs().Method()` — an extra layer of indirection vs calling a concrete repo directly. Faster prototyping suffers; this is the trade for testability and tx-safety.
  - **Wild Workouts uses different naming.** Anyone coming from Wild Workouts (`ports/`, `adapters/`) must translate to our `delivery/` (driving) and `infra/` (driven). The semantic mapping is documented in the convention to ease this, but the cognitive bridge is real.
- **Neutral**:
  - **Borrows from ThreeDotsLabs** but adapts to workspace naming. The dual-mode UoW is our own addition (Wild Workouts uses Firestore-style per-aggregate callbacks; we use a gorm-backed UoW closure that supports both auto-commit and atomic modes through a single accessor surface).
  - **Builds on [ADR-0001](0001-single-responsibility-go-packages.md).** Service modules are NOT SRP (they are multi-axis by design); this ADR documents the multi-axis shape that ADR-0001 explicitly excluded.
  - **Depends on [ADR-0002](0002-go-code-style.md)** for the rule that interfaces live at the consumer (so `port.go` is in the domain package, not a separate `ports/` package).

## Alternatives considered

- **Pure Clean Architecture (Uncle Bob — *Entities / Use Cases / Interface Adapters / Frameworks*).** Rejected because it's heavier on ceremony than DDD + Hexagonal, the four-layer naming doesn't map cleanly to Go's package conventions, and the four-layer rule is also less prescriptive about CQRS — which we want enforced at the port level.
- **Onion architecture (Jeffrey Palermo).** Similar to Hexagonal but less explicit about driving vs. driven ports. The "onion" metaphor is also harder to translate to a directory layout than ports / adapters — the layers blend into each other at the metaphorical centre.
- **ThreeDotsLabs Wild Workouts verbatim.** Rejected because their `ports/` (driving) + `adapters/` (driven) naming conflicts with the pre-existing `delivery/` + `infra/` choice in the portal scaffold. The user confirmed at review time that the portal naming should win; this ADR captures the reconciliation. The PATTERN is identical; only the directory names differ.
- **"Just CRUD" with handlers calling gorm directly.** Rejected because the user explicitly invoked DDD + CQRS + Hexagonal. The workspace also expects multiple services with shared patterns; deferring the architectural decision per-service would erode consistency.
- **Vertical slices (no shared domain).** Rejected because aggregates need cohesion across use cases. A `HireStaff` command and a `ListStaffByOrg` query both work on the Staff aggregate — they should share the domain model, not duplicate it.
- **Anemic domain model** (public fields on aggregates, all logic in services). Rejected because invariants leak: every caller has to know what makes an Organization valid. The factory + private fields pattern makes invariants enforceable in one place.
- **Generic Repository interface** (`Repository[T]` with `Save / Get / Update / Delete`). Rejected because (1) it forces all aggregates into the same method set, which forecloses use-case-shaped methods like `Update(ctx, id, updateFn)`; (2) it mixes mutations and queries on one interface, breaking CQRS at the port level.

## References

- [`docs/conventions/go/service-architecture.md`](../conventions/go/service-architecture.md) — the convention this ADR establishes.
- [`services/portal/AGENTS.md`](../../services/portal/AGENTS.md) — the canonical reference implementation.
- [ADR-0001](0001-single-responsibility-go-packages.md) — package SHAPE for SRP packages; service modules are explicitly excluded there, and this ADR fills the gap.
- [ADR-0002](0002-go-code-style.md) — per-file style; rule 5 (interfaces at consumer) underpins the `port.go` decision here.
- [ADR-0004](0004-typed-aggregate-ids-uuidv7.md) — typed aggregate identifiers and UUIDv7 generation, a sub-decision within this architectural ADR.
- [ThreeDotsLabs Wild Workouts](https://github.com/ThreeDotsLabs/wild-workouts-go-ddd-example) — the architectural source we adapted.
- [Go with the Domain (free book)](https://threedots.tech/go-with-the-domain/) — long-form rationale for the DDD + CQRS + Hexagonal pattern in Go.
- [Domain-Driven Design — Eric Evans](https://www.domainlanguage.com/ddd/) — the original DDD reference.
- [Hexagonal Architecture — Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/) — original ports-and-adapters paper (1994 — the term-of-art source for "ports" and "adapters").
- [CQRS — Greg Young](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) — the canonical CQRS write-up.
