# services/portal/

## OVERVIEW
Portal service. Scaffold-stage — directory tree exists, zero `.go` files. Clean Architecture + CQRS + DDD. Module path: `bootstrap/services/portal`.

## STRUCTURE
```
services/portal/
├── cmd/http/
│   ├── command/     # HTTP entrypoint binary — write side
│   └── query/       # HTTP entrypoint binary — read side
├── config/          # service config loader (use packages/go/env)
└── internal/
    ├── app/
    │   ├── command/ # write-side use cases (commands + handlers)
    │   └── query/   # read-side use cases (queries + handlers)
    ├── delivery/http/
    │   ├── command/ # HTTP handlers → app/command
    │   └── query/   # HTTP handlers → app/query
    ├── domain/      # entities, value objects, domain services (pure)
    └── infra/
        ├── postgres/
        │   ├── repo/  # repository implementations
        │   └── uow/   # unit-of-work / transaction boundary
        └── zitadel/   # Zitadel auth integration
```

## WHERE TO LOOK
| Adding... | Goes in... |
|-----------|------------|
| New write use case | `internal/app/command/<name>.go` |
| New read use case | `internal/app/query/<name>.go` |
| HTTP write route | `internal/delivery/http/command/<name>.go` |
| HTTP read route | `internal/delivery/http/query/<name>.go` |
| Domain entity / VO | `internal/domain/` |
| Postgres repo | `internal/infra/postgres/repo/<entity>_repo.go` |
| Transaction boundary | `internal/infra/postgres/uow/` |
| Service binary entrypoint | `cmd/http/{command,query}/main.go` |
| Service configuration | `config/` (use `bootstrap/packages/go/env`) |

## CONVENTIONS
- **Read/write split is physical**: command and query stacks have separate `cmd/`, `delivery/`, and `app/` subtrees; two HTTP binaries are intended, not one
- **`internal/domain/` is pure**: no imports from `infra/`, `delivery/`, or third-party I/O libs
- **Dependency direction**: `delivery/` → `app/` → `domain/` ← `infra/`; `app/` depends on interfaces, not concrete `infra/` types
- **Module path prefix**: `bootstrap/services/portal/...`

## ANTI-PATTERNS
- Do not call repos directly from `delivery/` — route through `app/{command,query}`
- Do not mix command and query handlers in the same package
- Do not put SQL or Zitadel SDK calls in `domain/`
- Do not create a single `cmd/http/main.go` that hosts both sides — two-binary split is intentional
