# services/portal/

## OVERVIEW

Portal service. Clean Architecture + CQRS + DDD; canonical example of the workspace's service-layer patterns. Module path: `bootstrap/services/portal`.

The architectural conventions this service implements are documented workspace-wide:

- [docs/conventions/go/code-style.md](../../docs/conventions/go/code-style.md) — file naming, doc comments, errors, imports, interface placement.
- [docs/conventions/go/service-architecture.md](../../docs/conventions/go/service-architecture.md) — DDD aggregates, CQRS ports, UoW pattern, postgres repo shape.

The sections below are portal-specific decisions on top of those conventions.

Portal-only documentation (service ADRs, specs, findings, debt) lives in [docs/](docs/) — see [docs/README.md](docs/README.md) for the global-vs-service split. Workspace-wide standards stay in the repo-root [docs/](../../docs/).

## STRUCTURE

```
services/portal/
├── docs/            # service-scoped docs: adrs / specs / findings / debt (see docs/README.md)
├── cmd/
│   ├── http/
│   │   └── query/   # read-side HTTP binary stub (placeholder package main; no main yet)
│   └── migrate/     # migration CLI (up/down/status) — main.go (exists)
├── config/          # service config loader (planned; use packages/go/env)
└── internal/
    ├── app/
    │   ├── command/ # write-side use cases + UnitOfWork port
    │   └── query/   # read-side use cases + read-model ports
    ├── delivery/http/ # planned/empty
    │   ├── command/ # HTTP handlers → app/command
    │   └── query/   # HTTP handlers → app/query
    ├── domain/<aggregate>/   # pure domain, one package per aggregate (organization, staff)
    └── infra/postgres/
        ├── migrations/  # goose SQL migrations
        ├── repo/        # Writer / Reader implementations (one file per aggregate)
        ├── readstore/   # read-side query-model stores
        └── uow/         # UnitOfWork implementation
# infra/zitadel/ — planned: the ONLY package that imports zitadel-go or reads urn:zitadel:* claims;
#   expose app-facing auth ports per convention (ADR-0006 Accepted;
#   contract in docs/conventions/auth/oidc-provider-integration.md)
```

## WHERE TO LOOK

| Adding...                                 | Goes in...                                                                          |
| ----------------------------------------- | ----------------------------------------------------------------------------------- |
| New write use case                        | `internal/app/command/<verb>_<aggregate>.go`                                        |
| New read use case                         | `internal/app/query/<verb>_<aggregate>.go`                                          |
| HTTP write route                          | `internal/delivery/http/command/<name>.go`                                          |
| HTTP read route                           | `internal/delivery/http/query/<name>.go`                                            |
| Domain aggregate                          | `internal/domain/<aggregate>/` (new package: aggregate + value objects + `port.go`) |
| Domain value object                       | `internal/domain/<aggregate>/<name>.go`                                             |
| Domain port (Writer/Reader/NotFoundError) | `internal/domain/<aggregate>/port.go`                                               |
| Postgres repo                             | `internal/infra/postgres/repo/<aggregate>.go`                                       |
| Read model / query-side store             | `internal/infra/postgres/readstore/<name>.go`                                       |
| Transaction boundary                      | `internal/infra/postgres/uow/`                                                      |
| Database migration (SQL)                  | `internal/infra/postgres/migrations/` (scaffold via `migrate-new <name>`)           |
| Migration CLI                             | `cmd/migrate/` (run with `migrate-up` / `migrate-down` / `migrate-status`)          |
| Service binary entrypoint                 | `cmd/migrate/main.go` (exists); `cmd/http/query/main.go` stub (placeholder, does not compile yet); `cmd/http/command/` planned — dir absent |
| Service configuration                     | `config/` (use `bootstrap/packages/go/env`)                                         |
| Portal-specific doc                       | `docs/` (adrs/specs/findings/debt) — see [docs/README.md](docs/README.md)           |

## CONVENTIONS

### Layer split

- **Read/write split is physical**: command and query stacks have separate `cmd/`, `delivery/`, and `app/` subtrees; two HTTP binaries are intended, not one.
- **`internal/domain/<aggregate>/` is pure**: stdlib only. No imports from `infra/`, `delivery/`, or third-party I/O libs.
- **Dependency direction**: `delivery/` → `app/` → `domain/` ← `infra/`. `app/` depends on interfaces (`command.UnitOfWork`, `organization.Writer`, etc.), never on concrete `infra/` types.
- **Module path prefix**: `bootstrap/services/portal/...`.

### Aggregate boundary

- Each aggregate is its own package under `internal/domain/`.
- Cross-aggregate references are by UUID string, never by direct pointer.
- The factory constructor `NewXxx(...) (*Xxx, error)` enforces every invariant; `UnmarshalXxxFromDatabase(...)` is the ONLY way to bypass validation and is reserved for repo adapters.
- See [service-architecture.md § Domain layer](../../docs/conventions/go/service-architecture.md#domain-layer) for the full pattern.

### Ports

- Per-aggregate `port.go` contains `NotFoundError`, `Writer` (mutations only), and `Reader` (queries only).
- CQRS is enforced at the port level — Writer and Reader never share methods.
- `Writer.Create(ctx, *T)` inserts a new aggregate; `Writer.Update(ctx, *T)` overwrites an existing row keyed on `T.ID()` and returns `NotFoundError` when no row matches. No callback parameters. Read-modify-write atomicity is composed by the caller via `UnitOfWork.DoOrganizationTransaction` — see [ADR-0005](../../docs/adrs/0005-collection-style-repositories.md).

### Unit of Work

- Interface lives in `internal/app/command/port.go` (`UnitOfWork` + the accessor surface `TransactionalUnitOfWork` + the `TransactionalUnitOfWorkHandler` closure type).
- Postgres implementation lives in `internal/infra/postgres/uow/uow.go`.
- **Every write is tenant-scoped.** `UnitOfWork` exposes a single entry point, `DoOrganizationTransaction(ctx, id organization.ID, handler)`: it validates `id` (`idgen.Validate`), binds the org to the connection for Row-Level Security via `set_config('app.organization_id', …, true)` (transaction-local) in `bindOrganizationRLS`, then runs `handler` with a tx-scoped `TransactionalUnitOfWork`. Writers reached through it are filtered to that one organization; the closure commits or rolls back as one unit.
- There is **no scope-less / auto-commit write path** — RLS requires every write to declare a scope. The scope-less `DoTransaction` is left commented out in `uow.go` for non-multi-tenant systems only.
- **Two RLS scopes ([ADR-0008](../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md), [ADR-0009](../../docs/adrs/0009-safe-system-scope-rls.md), [ADR-0011](../../docs/adrs/0011-org-root-rls-hardening.md))**: `organization` (bound to one tenant) and `system` (cross-tenant). Organization-scoped writes are implemented above. The read-side `system` scope is implemented in this service; the write-side system entry point (`DoSystemTransaction`) is still planned. Both scopes run under `NOBYPASSRLS` roles — `system` widens policy via `app.scope = system`, it does not bypass RLS.
- RLS policy authoring + the GUC contract (`app.scope` / `app.organization_id`) are documented in the `rls-patterns` skill (`packages/nix/core/ai/skills/rls-patterns/`).

### Read Store

- Interface lives in `internal/app/query/port.go` (`ReadStore` + the accessor surface `TransactionalReadStore` + the `TransactionalReadStoreHandler` closure type).
- Postgres implementation lives in `internal/infra/postgres/readstore/readstore.go`.
- **Every read is RLS-scoped too.** Organization reads use `DoOrganizationQuery(ctx, id organization.ID, handler)`: it validates `id`, binds transaction-local `app.organization_id`, and does not set `app.scope`; then it runs `handler` with a tx-scoped `TransactionalReadStore`. Readers reached through it are filtered to that one organization.
- **System-scope reads are implemented here.** `ReadStore.DoSystemQuery(ctx, capability, handler)` accepts an unforgeable `query.SystemReadCapability` produced by `SystemScopeAuthorizer`, derives the `app.organization_allowlist` GUC (`*` or comma-joined UUIDv7 ids) from the capability inside `bindSystemRLS`, binds `app.scope='system'` + that allowlist, then runs the same tx-scoped reader surface for cross-tenant read models. There is still **no scope-less read path** — unbound reads fail closed against `FORCE`d RLS policies.

### Postgres repo

- One file per aggregate: `internal/infra/postgres/repo/<aggregate>.go`. **No `_repo` suffix** — would stutter inside `package repo`.
- Each file contains: private row struct with GORM tags, exported `XxxWriter` (or `XxxReader`) struct + constructor, conversion helpers, and a compile-time `var _ xxx.Writer = (*XxxWriter)(nil)` assertion.
- Row structs are package-internal; aggregates cross the boundary.

## ANTI-PATTERNS

- Do not call repos directly from `delivery/` — route through `app/{command,query}`.
- Do not mix command and query handlers in the same package.
- Do not put SQL, GORM tags, or Zitadel SDK calls in `domain/`.
- Do not import `github.com/zitadel/zitadel-go/...` — or use a `urn:zitadel:…` claim key — outside planned `internal/infra/zitadel/`. Per ADR-0006 and [OIDC provider integration](../../docs/conventions/auth/oidc-provider-integration.md), `app`/`delivery` should depend on slim app-facing auth ports, not provider SDKs or provider claim keys.
- Do not create a single `cmd/http/main.go` that hosts both sides — the two-binary split is intentional.
- Do not return `*gorm.DB` or `*sql.Tx` from `app/` code — UoW encapsulates the transaction handle.
- Do not give domain aggregates pointer references to other aggregates — use UUID strings.
- Do not name repo files `<entity>_repo.go` — package is already `repo`, the suffix stutters.
- Do not write a Repository interface that mixes mutations and queries — CQRS is enforced at the port level.
- Do not call `panic` for invalid input in factory constructors — return `error`.
