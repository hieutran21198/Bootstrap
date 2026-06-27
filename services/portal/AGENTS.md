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
│   │   ├── command/ # write-side HTTP binary (planned — dir only)
│   │   └── query/   # read-side HTTP binary (planned — dir only)
│   └── migrate/     # migration CLI (up/down/status) — main.go (exists)
├── config/          # service config loader (use packages/go/env)
└── internal/
    ├── app/
    │   ├── command/ # write-side use cases + UnitOfWork port
    │   └── query/   # read-side use cases + read-model ports
    ├── delivery/http/
    │   ├── command/ # HTTP handlers → app/command
    │   └── query/   # HTTP handlers → app/query
    ├── domain/<aggregate>/   # pure domain, one package per aggregate (organization, staff)
    └── infra/postgres/
        ├── migrations/  # goose SQL migrations
        ├── repo/        # Writer / Reader implementations (one file per aggregate)
        ├── readstore/   # read-side query-model stores
        └── uow/         # UnitOfWork implementation
# infra/zitadel/ — planned (ADR-0006, Proposed); not yet created
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
| Database migration (SQL)                  | `internal/infra/postgres/migrations/` (scaffold via `migrate-new <name>`)            |
| Migration CLI                             | `cmd/migrate/` (run with `migrate-up` / `migrate-down` / `migrate-status`)           |
| Service binary entrypoint                 | `cmd/migrate/main.go` (exists); `cmd/http/{command,query}/main.go` (planned)         |
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
- `Writer.Create(ctx, *T)` inserts a new aggregate; `Writer.Update(ctx, *T)` overwrites an existing row keyed on `T.ID()` and returns `NotFoundError` when no row matches. No callback parameters. Read-modify-write atomicity is composed by the caller via `UnitOfWork.DoTransaction` — see [ADR-0005](../../docs/adrs/0005-collection-style-repositories.md).

### Unit of Work

- Interface lives in `internal/app/command/port.go` (`UnitOfWork` + narrower `TransactionalUnitOfWork`).
- Postgres implementation lives in `internal/infra/postgres/uow/uow.go` — dual-mode via interface composition + struct embedding.
- Handlers depending on `UnitOfWork` get both auto-commit and transactional modes; handlers depending on `TransactionalUnitOfWork` are restricted to inside-DoTransaction by type.

### Postgres repo

- One file per aggregate: `internal/infra/postgres/repo/<aggregate>.go`. **No `_repo` suffix** — would stutter inside `package repo`.
- Each file contains: private row struct with GORM tags, exported `XxxWriter` (or `XxxReader`) struct + constructor, conversion helpers, and a compile-time `var _ xxx.Writer = (*XxxWriter)(nil)` assertion.
- Row structs are package-internal; aggregates cross the boundary.

## ANTI-PATTERNS

- Do not call repos directly from `delivery/` — route through `app/{command,query}`.
- Do not mix command and query handlers in the same package.
- Do not put SQL, GORM tags, or Zitadel SDK calls in `domain/`.
- Do not create a single `cmd/http/main.go` that hosts both sides — the two-binary split is intentional.
- Do not return `*gorm.DB` or `*sql.Tx` from `app/` code — UoW encapsulates the transaction handle.
- Do not give domain aggregates pointer references to other aggregates — use UUID strings.
- Do not name repo files `<entity>_repo.go` — package is already `repo`, the suffix stutters.
- Do not write a Repository interface that mixes mutations and queries — CQRS is enforced at the port level.
- Do not call `panic` for invalid input in factory constructors — return `error`.
