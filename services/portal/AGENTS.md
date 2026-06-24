# services/portal/

## OVERVIEW

Portal service. **Scaffold-stage** — directory tree exists, zero `.go` files. Layout encodes Clean Architecture + CQRS + DDD; treat each leaf as a **placement contract**.

Module path: `bootstrap/services/portal`.

## STRUCTURE

```
services/portal/
├── cmd/http/
│   ├── command/         # HTTP entrypoint binary for write side
│   └── query/           # HTTP entrypoint binary for read side
├── config/              # service config loader (intended to use packages/go/env)
└── internal/
    ├── app/
    │   ├── command/     # write-side use cases (commands + handlers)
    │   └── query/       # read-side use cases (queries + handlers)
    ├── delivery/http/
    │   ├── command/     # HTTP handlers → app/command
    │   └── query/       # HTTP handlers → app/query
    ├── domain/          # entities, value objects, domain services (pure)
    └── infra/
        ├── postgres/
        │   ├── repo/    # repository implementations
        │   └── uow/     # unit-of-work / transaction boundary
        └── zitadel/     # Zitadel auth integration
```

## WHERE TO LOOK

| Adding...                       | Goes in...                                                          |
| ------------------------------- | ------------------------------------------------------------------- |
| New write use case              | `internal/app/command/<name>.go`                                    |
| New read use case               | `internal/app/query/<name>.go`                                      |
| HTTP route → write              | `internal/delivery/http/command/<name>.go`                          |
| HTTP route → read               | `internal/delivery/http/query/<name>.go`                            |
| Domain entity / VO              | `internal/domain/`                                                  |
| Postgres repo                   | `internal/infra/postgres/repo/<entity>_repo.go`                     |
| Transaction boundary            | `internal/infra/postgres/uow/`                                      |
| Service binary entrypoint       | `cmd/http/{command,query}/main.go`                                  |
| Service configuration           | `config/` (use `bootstrap/packages/go/env`)                         |

## CONVENTIONS

- **Read/write split is physical**: command and query stacks have separate `cmd/`, `delivery/`, and `app/` subtrees. Two HTTP binaries are intended, not one.
- **`internal/domain/` is pure** — no imports from `infra/`, `delivery/`, or third-party I/O libs. Only stdlib and other pure domain code.
- **Dependency direction**: `delivery/` → `app/` → `domain/` ← `infra/`. `app/` does not import `delivery/` or concrete `infra/` types — depends on interfaces declared near `domain/` or `app/`.
- **Module path prefix**: `bootstrap/services/portal/...` (workspace-name root, not a vanity domain).

## ANTI-PATTERNS

- **Do not** call repos directly from `delivery/`. Always route through `app/{command,query}`.
- **Do not** mix command and query handlers in the same package — keeping them split is the point of the layout.
- **Do not** put SQL or Zitadel SDK calls in `domain/`. Those belong in `infra/`.
- **Do not** add a single `cmd/http/main.go` that hosts both sides — the two-binary split is intentional.
