**Generated:** 2026-06-27T05:39:07Z
**Commit:** 503beeb
**Branch:** main

## OVERVIEW
A greenfield Go monorepo scaffold managed by Nix and devenv. Three Go modules are bound via go.work; the value lives in conventions enforced by tooling, not in code volume.

## STRUCTURE
```
bootstrap/
├── apps/               # platform-specific apps (scaffold)
├── deploy/             # infra defs + deploy/local (ZITADEL docker-compose)
├── docs/               # GLOBAL docs: ADRs / specs / conventions / glossary / findings / debt
├── packages/
│   ├── go/             # shared Go module (env, gormx, idgen, migrate, server/echox)
│   └── nix/            # Nix devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/    # Clean Arch + CQRS service (carries its own docs/)
├── tools/              # workspace tooling Go module
│   ├── ai/             # AI agent skills/presets (scaffold)
│   ├── generators/ws-tree/  # tree + .info description inliner
│   ├── scripts/        # dev helper scripts (scaffold)
│   └── validators/     # workspace / arch validators (scaffold)
├── devenv.nix          # workspace name + core.workspace.treeInfos + module toggles
├── devenv.yaml         # imports packages/nix/ modules
└── go.work             # binds packages/go, services/portal, tools
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add workspace-wide ADR / convention | `docs/adrs/`, `docs/conventions/` | See [docs/AGENTS.md](docs/AGENTS.md) for per-track format + lifecycle |
| Add portal-specific doc | `services/portal/docs/` | Service-scoped ADRs/specs/findings/debt — see [services/portal/docs/README.md](services/portal/docs/README.md) |
| Add a folder description | `core.workspace.treeInfos` in the owning `devenv.nix` | Generates the `.info` row `ws-tree` inlines (descriptions only — no `.gitkeep` seeding) |
| Add Nix devenv module | `packages/nix/core/` (or `extra/` for opt-in) | See [packages/nix/AGENTS.md](packages/nix/AGENTS.md) |
| Add Go code to portal | `services/portal/internal/` | See [services/portal/AGENTS.md](services/portal/AGENTS.md) |
| Add shared Go library | `packages/go/` | See [packages/go/AGENTS.md](packages/go/AGENTS.md) for SRP governance |
| Add workspace CLI tool | `tools/generators/<name>/` | See [tools/AGENTS.md](tools/AGENTS.md) |
| Configure AI agents | `packages/nix/core/ai/opencode/` | opencode agents + `max`/`slim` profiles |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| env.Loader | type | packages/go/env/port.go:6 | env-var loader interface |
| env.FileLoader | func | packages/go/env/env.go:29 | loads from .env file |
| env.OSLoader | func | packages/go/env/env.go:44 | loads from OS env |
| env.Parse | func | packages/go/env/env.go:59 | typed parser (generic) |
| gormx.New | func | packages/go/gormx/gormx.go:38 | gorm.DB wrapper constructor (stateful) |
| gormx/postgres.New | func | packages/go/gormx/postgres/postgres.go:50 | postgres dialector constructor |
| gormx/sqlite.New | func | packages/go/gormx/sqlite/sqlite.go:27 | sqlite dialector constructor |
| echox.New | func | packages/go/server/echox/echox.go:44 | echo v4 server constructor |
| idgen.NewFor | func | packages/go/idgen/idgen.go:38 | typed UUIDv7 ID generator (generic, stateless) |
| idgen.Validate | func | packages/go/idgen/idgen.go:58 | UUIDv7 validation at boundaries |
| migrate.New | func | packages/go/migrate/migrate.go:45 | goose migrator constructor (stateful) |

## CONVENTIONS
- **Whitespace**: `.editorconfig` (Nix-generated) — Go uses tabs; all others 2-space indent; Markdown preserves trailing spaces
- **Go module paths**: `bootstrap/<segment>/<module>` — no domain prefix; workspace name is the prefix
- **Go version**: `1.26.3` pinned across all `go.mod` + `go.work`; match when adding modules
- **Folder descriptions**: add the path to `core.workspace.treeInfos` in the owning `devenv.nix` (root or per-service) — generates the `.info` row `ws-tree` inlines (descriptions only; create the dir + `.gitkeep` yourself)
- **Commits**: Conventional Commits enforced by commitizen pre-commit hook
- **Docs are two-tier**: workspace-wide standards in root [`docs/`](docs/); service-only docs in `services/<name>/docs/` (e.g. [services/portal/docs/](services/portal/docs/)). ADRs append-only; conventions living — see [docs/AGENTS.md](docs/AGENTS.md)

## ANTI-PATTERNS (THIS PROJECT)
- **Generated files**: do not hand-edit `.pre-commit-config.yaml`, `.golangci.yml`, `.editorconfig`, `go.work`, `.info` — Nix regenerates them on `direnv reload`
- **Go import paths**: no vanity domain prefixes; `bootstrap/` is the root
- **No Makefile / setup.sh / bootstrap.sh**: devenv scripts are the only runner
- **File size cap**: 1 MB (`check-added-large-files --maxkb=1024`)
- **Local-only dirs**: `.opencode/`, `.claude/`, `.codex/`, `.omo/`, `.codegraph/` are gitignored per-developer agent configs/caches — do not commit

## UNIQUE STYLES
- No numeric prefixes for module dirs in `packages/nix/` — descriptive names only (the numbered `tools/_nixenv/` convention is retired)
- `enterShell` auto-runs `ws-info` on every `cd` with direnv enabled
- `ws-tree` reads `.info` for inline descriptions in tree output
- Each service is its own devenv: `services/portal/devenv.nix` imports `packages/nix` and declares its own `treeInfos` + `.info`

## COMMANDS
```bash
direnv allow     # one-time consent; auto-enters dev shell on every cd
ws-info          # workspace overview (auto-runs on shell entry)
ws-tree          # tree + inline .info descriptions
go-info          # Go toolchain version + env
lint-go          # golangci-lint across all go.work modules (--fix to auto-fix)
devenv shell     # explicit shell entry
```

## NOTES
- Scaffold-stage is uneven: `apps/` and parts of `tools/` are `.gitkeep` placeholders (placement contracts), but `packages/go/`, `services/portal/internal/`, and `deploy/local/` now carry real code
- `packages/nix/extra/` — optional Nix modules (currently `dev-container`); not imported by `core`, opt in via root `devenv.yaml`
- ZITADEL: deploy compose lives in `deploy/local/`; portal's `internal/infra/zitadel/` is planned (ADR-0006, `Proposed`) and does not exist yet
