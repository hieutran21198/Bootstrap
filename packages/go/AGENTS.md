# packages/go/

## OVERVIEW
Shared Go library module (`bootstrap/packages/go`). SRP-stateful governance per [ADR-0001](../../docs/adrs/0001-single-responsibility-go-packages.md).

## STRUCTURE
```
packages/go/
├── env/                # env-var loaders + typed parser (pre-governance, function-based)
├── gormx/              # gorm v2 wrapper
│   ├── postgres/       # postgres dialector (gorm.io/driver/postgres)
│   └── sqlite/         # sqlite dialector (pure Go, no CGO)
└── server/echox/       # echo v4 server with middleware + HTTP timeouts
```

## GOVERNANCE — the shape SRP-stateful packages take
The contract below comes from [ADR-0001](../../docs/adrs/0001-single-responsibility-go-packages.md) and the canonical template [`stateful.go.tmpl`](../../docs/conventions/go/templates/stateful.go.tmpl). Packages that own state (servers, clients, connections, caches) follow this shape. When uncertain whether a package belongs here, classify it first with [`creating-new-package.md`](../../docs/conventions/go/creating-new-package.md).

A stateful package exposes **three elements and nothing more**:

1. **One exported `Config` struct** that holds every knob the package exposes. Pass by value into `New`. Treat it as frozen inside the package. Zero values must be valid (defaults applied in `New`) unless a field is fundamentally required for the package to work.
2. **One target struct** whose exported name matches the package (`echox.Echox`, `gormx.Gormx`). Keep fields unexported.
3. **One constructor named `New`** — never `NewWithLogger`, `NewFromEnv`, or `NewEchox`. The package name already carries the noun. Two signatures are permitted:
   - `func New(cfg Config) *Target` — when construction needs no I/O.
   - `func New(ctx context.Context, cfg Config) (*Target, error)` — when construction performs I/O (dial, ping, open a file, etc.).

Additional rules:
- `context.Context` is always the first parameter whenever it appears, in constructors and methods.
- Wrap every error: `fmt.Errorf("packagename: <operation>: %w", err)`.

### Canonical shape
```go
// Config holds all configuration for Target.
type Config struct { /* knobs */ }

// Target is <what it does>.
type Target struct { /* fields; cfg stays internal */ }

// New constructs a Target from cfg.
func New(ctx context.Context, cfg Config) (*Target, error) {
    if err := ctx.Err(); err != nil {
        return nil, fmt.Errorf("packagename: new: %w", err)
    }
    // validate cfg, perform I/O, populate target
    return &Target{}, nil
}
```

## ANTI-PATTERNS
- ✗ Multiple constructors (`NewWithLogger`, `NewFromEnv`, `NewEchox`, ...). One `New`, one `Config` — extend `Config` instead.
- ✗ Functional options (`Option func(*Target)`) parallel to `Config`. `Config` is the only knob surface.
- ✗ Mutating `cfg` after `New` returns. Store the value (or just the fields needed) and freeze it.
- ✗ Storing `context.Context` inside the target struct. Pass it through methods.
- ✗ Third-party dependencies in `env/`. That package stays at stdlib + `caarlos0/env` + `godotenv`.
- ✗ Vanity import domains. Module path is `bootstrap/packages/go/<segment>/<name>`.

## NOTES
- `env/` predates governance; it uses a function-based design. No exception granted to new packages.
- `gormx` and `echox` are the first SRP-stateful examples in this module.
- New packages go here without moving `go.mod`. Run `go mod tidy` from this directory after adding dependencies.
