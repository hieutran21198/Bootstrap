# BOOTSTRAP - PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-24 16:18 +07
**Commit:** 2c0d9ff
**Branch:** main

## OVERVIEW

Greenfield Go monorepo scaffold managed by Nix/devenv. Three Go modules stitched via [go.work](go.work). Most product folders are still skeletons (`.gitkeep` placeholders) — the value lives in **conventions enforced by tooling**, not in code yet.

## STRUCTURE

```
bootstrap/
├── apps/                # platform-specific UI apps (scaffold)
├── deploy/              # infra defs (scaffold; only deploy/local/ exists)
├── docs/                # ADRs / specs / conventions / glossary  → see docs/AGENTS.md
├── packages/go/         # shared Go module (currently: env loader)
├── services/portal/     # Clean Arch + CQRS service scaffold     → see services/portal/AGENTS.md
├── tools/               # workspace tooling Go module + nix env  → see tools/AGENTS.md
├── devenv.nix           # workspace name + mandatoryFolders contract
├── devenv.yaml          # imports tools/_nixenv/{001,002,003}
├── go.work              # binds packages/go, services/portal, tools
└── .envrc               # direnv → `use devenv`
```

## WHERE TO LOOK

| Task                       | Location                                                                          |
| -------------------------- | --------------------------------------------------------------------------------- |
| Add an ADR                 | [docs/adrs/TEMPLATE.md](docs/adrs/TEMPLATE.md) → new numbered file                |
| Add a workspace folder     | [devenv.nix](devenv.nix) → `mandatoryFolders` (auto-creates `.gitkeep` + `.info`) |
| Add a Nix dev module       | [tools/\_nixenv/](tools/_nixenv/) — see its AGENTS.md                             |
| Add Go code to portal      | [services/portal/](services/portal/) — see its AGENTS.md                          |
| Add shared Go library code | [packages/go/](packages/go/) (package path: `bootstrap/packages/go/<name>`)       |
| Add a workspace CLI tool   | [tools/generators/](tools/generators/) (e.g. better-tree pattern)                 |
| Configure agent models     | [.opencode/oh-my-openagent.json](.opencode/oh-my-openagent.json) (local-only)     |

## ENTRYPOINT

This is a **devenv/direnv repo** — no `Makefile`, no `setup.sh`.

```bash
# one-time
direnv allow             # auto-loads devenv shell on cd

# inside the shell
ws-info                  # workspace overview (auto-runs on enterShell)
better-tree              # tree + descriptions from .info
go-info                  # Go toolchain info
devenv shell             # explicit re-entry
```

## CODE MAP

Only one populated production package; everything else is structural.

| Symbol           | Type      | Location                                                                     | Role                                                       |
| ---------------- | --------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `env.Loader`     | interface | [packages/go/env/port.go:6](packages/go/env/port.go:6)                       | `Load(ctx) → map[string]string`                            |
| `env.FileLoader` | func      | [packages/go/env/env.go:28](packages/go/env/env.go:28)                       | godotenv `.env` reader (missing file = empty)              |
| `env.OSLoader`   | func      | [packages/go/env/env.go:43](packages/go/env/env.go:43)                       | `os.Environ()` reader                                      |
| `env.Parse[T]`   | generic   | [packages/go/env/env.go:58](packages/go/env/env.go:58)                       | Merge loaders (later overrides earlier) → caarlos0/env v11 |
| `better-tree`    | main      | [tools/generators/better-tree/main.go](tools/generators/better-tree/main.go) | Wraps `tree`, inlines `.info` descriptions                 |

## CONVENTIONS

- **Whitespace**: 2-space default, **Go uses tabs** (gofmt-enforced), Makefile uses tabs, Markdown preserves trailing spaces. Source: [.editorconfig](.editorconfig).
- **Go module path**: `bootstrap/<segment>/<module>` — e.g. `bootstrap/packages/go`, `bootstrap/services/portal`, `bootstrap/tools`. **Do not** use a domain (`github.com/...`); the prefix is the workspace name.
- **Go version**: pinned to 1.26.3 in every `go.mod` and `go.work`. Match when adding modules.
- **Mandatory folders**: Adding a key to `workspace.mandatoryFolders` in [devenv.nix](devenv.nix) auto-seeds `.gitkeep` + a row in `.info`. Do not create scaffold dirs manually.
- **Commits**: Conventional Commits enforced via commitizen pre-commit hook.
- **ADRs**: append-only, `NNNN-kebab-case-title.md`, status lifecycle `Proposed → Accepted → Superseded by ADR-NNNN | Deprecated`. See [docs/AGENTS.md](docs/AGENTS.md).

## ANTI-PATTERNS (THIS PROJECT)

- **Do not edit** [`.pre-commit-config.yaml`](.pre-commit-config.yaml) — generated by `cachix/git-hooks.nix` via [tools/\_nixenv/002-git-hooks/devenv.nix](tools/_nixenv/002-git-hooks/devenv.nix). Change the source, not the artifact.
- **Do not edit** `.info` — generated from `mandatoryFolders` in `devenv.nix`. Edit the source.
- **Do not edit** `.editorconfig` (it is `lib.mkDefault` from [tools/\_nixenv/001-workspace/devenv.nix](tools/_nixenv/001-workspace/devenv.nix)) unless you intend to override the workspace default.
- **Do not commit** AI agent config: `.opencode/`, `.claude/`, `.codex/` are gitignored — they are local-only per-developer.
- **No file >1 MB** committed (pre-commit `check-added-large-files --maxkb=1024`).
- **Do not introduce** `Makefile`, `setup.sh`, `bootstrap.sh` — devenv scripts are the workspace runner.

## UNIQUE STYLES

- **`_nixenv` prefix**: leading underscore marks Nix devenv modules as workspace-internal (analogous to Go's lowercase = unexported). See [tools/\_nixenv/AGENTS.md](tools/_nixenv/AGENTS.md).
- **Numbered module ordering**: `NNN-name` inside `_nixenv` (e.g. `001-workspace`). Lower number = depended-on by higher.
- **`enterShell` runs `ws-info`** automatically — every shell entry is self-documenting.
- **`better-tree` reads descriptions** from `.info` (native `tree --info` syntax) OR `$WORKSPACE_TREE_DESCRIPTIONS` JSON env var.

## NOTES

- Project is **scaffold-stage**: [`services/portal`](services/portal/) has a full Clean Architecture + CQRS directory tree but zero `.go` files. Treat empty internal dirs as **placement contracts**, not gaps.
- Hidden top-level dirs (`.devenv/`, `.direnv/`, `.codegraph/`, `.omo/`) are local tooling state and gitignored.
- `apps/`, `deploy/`, `scripts/`, `tools/{ai,validators,scripts}/`, `docs/{conventions,glossary,specs}/` are all `.gitkeep`-only contracts waiting for content.
