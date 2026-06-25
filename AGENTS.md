**Generated:** 2026-06-25T08:55:03Z
**Commit:** 3c5e1f1
**Branch:** main

## OVERVIEW
A greenfield Go monorepo scaffold managed by Nix and devenv. Three Go modules are bound via go.work; the value lives in conventions enforced by tooling, not in code volume.

## STRUCTURE
```
bootstrap/
├── apps/               # platform-specific apps (scaffold)
├── deploy/             # infra defs (scaffold)
├── docs/               # ADRs / specs / conventions / glossary
├── packages/
│   ├── go/             # shared Go module (env, gormx, server/echox)
│   └── nix/            # Nix devenv modules (replaces tools/_nixenv/)
├── services/portal/    # Clean Arch + CQRS service (scaffold)
├── tools/              # workspace tooling Go module + generators
│   └── generators/ws-tree/  # tree + .info description inliner
├── devenv.nix          # workspace name + mandatoryFolders
├── devenv.yaml         # imports packages/nix/ modules
└── go.work             # binds packages/go, services/portal, tools
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add ADR | `docs/adrs/` | See [docs/AGENTS.md](docs/AGENTS.md) for format |
| Add convention | `docs/conventions/` | See [docs/AGENTS.md](docs/AGENTS.md) for lifecycle |
| Add workspace folder | `devenv.nix` → `workspace.mandatoryFolders` | Auto-seeds `.gitkeep` + `.info` row |
| Add Nix devenv module | `packages/nix/core/` | See [packages/nix/AGENTS.md](packages/nix/AGENTS.md) |
| Add Go code to portal | `services/portal/internal/` | See [services/portal/AGENTS.md](services/portal/AGENTS.md) |
| Add shared Go library | `packages/go/` | See [packages/go/AGENTS.md](packages/go/AGENTS.md) for SRP governance |
| Add workspace CLI tool | `tools/generators/<name>/` | See [tools/AGENTS.md](tools/AGENTS.md) |
| Configure agent models | `tools/ai/` | scaffold |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| env.Loader | type | packages/go/env/port.go:6 | env-var loader interface |
| env.FileLoader | func | packages/go/env/env.go:28 | loads from .env file |
| env.OSLoader | func | packages/go/env/env.go:43 | loads from OS env |
| env.Parse | func | packages/go/env/env.go:58 | typed parser |
| gormx/postgres.New | func | packages/go/gormx/postgres/postgres.go:50 | postgres dialector constructor |
| gormx/sqlite.New | func | packages/go/gormx/sqlite/sqlite.go:27 | sqlite dialector constructor |
| echox.New | func | packages/go/server/echox/echox.go:44 | echo v4 server constructor |

## CONVENTIONS
- **Whitespace**: `.editorconfig` (Nix-generated) — Go uses tabs; all others 2-space indent; Markdown preserves trailing spaces
- **Go module paths**: `bootstrap/<segment>/<module>` — no domain prefix; workspace name is the prefix
- **Go version**: `1.26.3` pinned across all `go.mod` + `go.work`; match when adding modules
- **New folders**: add to `workspace.mandatoryFolders` in `devenv.nix` — devenv seeds `.gitkeep` + `.info` automatically
- **Commits**: Conventional Commits enforced by commitizen pre-commit hook
- **ADRs + conventions**: append-only ADRs; living conventions — see [docs/AGENTS.md](docs/AGENTS.md)

## ANTI-PATTERNS (THIS PROJECT)
- **Generated files**: do not hand-edit `.pre-commit-config.yaml`, `.golangci.yml`, `.editorconfig`, `go.work`, `.info` — Nix regenerates them on `direnv reload`
- **Go import paths**: no vanity domain prefixes; `bootstrap/` is the root
- **No Makefile / setup.sh / bootstrap.sh**: devenv scripts are the only runner
- **File size cap**: 1 MB (`check-added-large-files --maxkb=1024`)
- **Local-only dirs**: `.opencode/`, `.claude/`, `.codex/`, `.omo/` are gitignored per-developer agent configs — do not commit

## UNIQUE STYLES
- `tools/_nixenv/` prefix **retired** — Nix modules moved to `packages/nix/core/` during migration
- No numeric prefixes for module dirs in `packages/nix/` — descriptive names only (numbered `_nixenv` convention retired)
- `enterShell` auto-runs `ws-info` on every `cd` with direnv enabled
- `ws-tree` reads `.info` file for inline descriptions in tree output

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
- Scaffold-stage: most product dirs contain only `.gitkeep` placeholders — treat as placement contracts
- Hidden dirs (`.opencode/`, `.omo/`, `.claude/`, `.codex/`) are gitignored; local-only agent configs live there
- `packages/nix/extra/` — optional Nix modules (dev-container, AI agents); not imported by default
