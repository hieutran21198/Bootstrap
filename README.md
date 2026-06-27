# Bootstrap

A greenfield Go monorepo scaffold managed by [Nix](https://nixos.org/) + [devenv](https://devenv.sh/). Three Go modules bound via [`go.work`](go.work); toolchain, shell environment, linters, pre-commit hooks, documentation conventions, and AI agents are all defined as code under [`packages/nix/`](packages/nix/).

> **Early-stage.** Some product folders (`apps/`, parts of `tools/`) are still `.gitkeep` placeholders — treat them as placement contracts. `packages/go/`, `services/portal/internal/`, and `deploy/local/` now carry real code; the value is in the conventions enforced by tooling.

## Quick start

Prerequisites: [Nix](https://nixos.org/download) with flakes enabled, [direnv](https://direnv.net/), [devenv](https://devenv.sh/).

```bash
git clone <repo> bootstrap
cd bootstrap
direnv allow            # one-time consent; auto-enters the dev shell on every cd
ws-info                 # workspace overview (auto-runs on shell entry)
```

Provisions: Go `1.26.3` + delve + gopls + `golangci-lint v2.12.2`, AWS CLI + aws-vault, markdownlint, [`prek`](https://github.com/j178/prek) pre-commit runner, commitizen, secret scanners (`ripsecrets`, `trufflehog`, `detect-aws-credentials`, `detect-private-keys`). No `Makefile`, no `setup.sh` — devenv scripts are the runner.

`secretspec` is wired to the `protonpass` provider on the `development` profile in [`devenv.yaml`](devenv.yaml); change the provider there if you use something else. The default [`secretspec.toml`](secretspec.toml) declares no secrets, so shell entry works out of the box.

## Layout

```
bootstrap/
├── apps/                   # platform-specific apps                        (scaffold)
├── deploy/                 # infra defs + deploy/local (ZITADEL docker-compose)
├── docs/                   # GLOBAL docs: adrs / specs / conventions / glossary / findings / debt
├── packages/
│   ├── go/                 # shared Go module (env, gormx, idgen, migrate, server/echox)
│   └── nix/                # devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/        # Clean Arch + CQRS service (+ its own docs/)
├── tools/
│   ├── ai/skills/          # installable AI agent skills                   (scaffold)
│   ├── generators/
│   │   └── ws-tree/        # tree + inline .info description renderer
│   ├── scripts/            # dev helper scripts                            (scaffold)
│   └── validators/         # workspace / arch validators                   (scaffold)
├── devenv.nix              # workspace name + module enablement
├── devenv.yaml             # imports packages/nix
└── go.work                 # binds packages/go, services/portal, tools (Nix-generated symlink)
```

Every populated subtree has its own `AGENTS.md` — terse knowledge base for humans and AI agents:

| Path                                                   | Covers                                                  |
| ------------------------------------------------------ | ------------------------------------------------------- |
| [AGENTS.md](AGENTS.md)                                 | Canonical project knowledge base — start here for depth |
| [docs/AGENTS.md](docs/AGENTS.md)                       | ADRs, specs, conventions, glossary, findings, debt      |
| [packages/go/AGENTS.md](packages/go/AGENTS.md)         | Shared Go library governance (SRP per-package)          |
| [packages/nix/AGENTS.md](packages/nix/AGENTS.md)       | Nix devenv module conventions + opencode/claude AI setup |
| [services/portal/AGENTS.md](services/portal/AGENTS.md) | Clean Architecture + CQRS module layout                 |
| [tools/AGENTS.md](tools/AGENTS.md)                     | Generators, validators, scripts                         |

### Nix module structure

[`packages/nix/`](packages/nix/) splits into two trees with different opt-in semantics:

- **[`core/`](packages/nix/core/)** — mandatory: `utils` (option-builder helpers), `ai` (opencode agents/profiles + claude alias), `git`, `secrets`, `services/postgres`, `workspace`, `toolchains/{go,markdown,aws,terraform}`. Each module gates on its own `enable` flag declared in [`devenv.nix`](devenv.nix).
- **[`extra/`](packages/nix/extra/)** — opt-in add-ons that are not imported by the root by default: currently `dev-container`. Living outside `core/` signals "default off"; flip the enable flag to wire it in.

## Shell commands

Available after entering the shell (i.e. any `cd` into the repo with direnv enabled):

| Command                        | What                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------- |
| `ws-info`                      | Workspace overview (root, name, layout, available commands). Auto-runs on entry.  |
| `ws-tree`                      | Directory tree with inline `.info` descriptions.                                  |
| `ws-tree --tabular --doc-only` | Compact docs-only map (the format AI agents quote when describing the workspace). |
| `go-info`                      | Go toolchain `version` + `env` summary + `go.work` module list.                   |
| `lint-go`                      | `golangci-lint` across every `go.work` module (pass `--fix` to auto-fix).         |
| `devenv up`                    | Spin up workspace services (when defined).                                        |
| `devenv shell`                 | Explicit shell entry (bypassing direnv).                                          |

## Conventions

- **Whitespace**: [`.editorconfig`](.editorconfig) (Nix-generated symlink) — Go uses tabs (`indent_size = 4`); all others 2-space; `trim_trailing_whitespace = true` and `insert_final_newline = true` universally.
- **Go module path**: `bootstrap/<segment>/<module>`. No domain prefix; the workspace name _is_ the prefix.
- **Go version**: `1.26.3` across all `go.mod` + `go.work`. Match when adding modules.
- **Folder descriptions**: Add the path to `core.workspace.treeInfos` in the owning [`devenv.nix`](devenv.nix) (root or a service) — it generates the `.info` row `ws-tree` inlines. It writes **descriptions only**; create the directory and its `.gitkeep` yourself.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) via `commitizen` ran by [`prek`](https://github.com/j178/prek).
- **Documentation is two-tier**: workspace-wide standards live in root [`docs/`](docs/) (six tracks — adrs/specs/conventions/glossary/findings/debt, each with its own `TEMPLATE.md` + `README.md`); service-only docs live under `services/<name>/docs/` (e.g. [services/portal/docs/](services/portal/docs/)). ADRs are append-only and numbered; specs/conventions/glossary are living; findings are append-only after `Resolved`; debt has an append-only _Encounters_ ledger. See [docs/AGENTS.md](docs/AGENTS.md) for per-track rules.
- **Local-only (gitignored)**: `.opencode/`, `.claude/`, `.codex/`, `.omo/`, `.codegraph/` — per-developer agent config + caches.
- **File size cap**: 1 MB (`check-added-large-files --maxkb=1024`).

### Generated files — do not hand-edit

All are Nix-store symlinks regenerated on `direnv reload`. Gitignored.

| File                      | Source                                                                                                                                              |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.pre-commit-config.yaml` | devenv `git-hooks.hooks.*` definitions in [packages/nix/core/git/default.nix](packages/nix/core/git/default.nix) and other modules' contributions   |
| `.golangci.yml`           | [packages/nix/core/toolchains/go/golangci-lint/default.nix](packages/nix/core/toolchains/go/golangci-lint/default.nix)                              |
| `go.work`                 | [packages/nix/core/toolchains/go/go-work/default.nix](packages/nix/core/toolchains/go/go-work/default.nix) from `core.toolchains.go.go-work.mods`   |
| `.info`                   | [packages/nix/core/workspace/default.nix](packages/nix/core/workspace/default.nix) from `core.workspace.treeInfos`                                  |
| `.editorconfig`           | [packages/nix/core/workspace/default.nix](packages/nix/core/workspace/default.nix) (`core.workspace.editorConfig` plus per-toolchain contributions) |
| `.claude/settings.json`, `CLAUDE.md` | [packages/nix/core/ai/default.nix](packages/nix/core/ai/default.nix) when `core.ai.claude.enable = true` (`CLAUDE.md` is just `@AGENTS.md`)             |
| `.opencode/<plugin>.json` | the active opencode profile under [packages/nix/core/ai/opencode/profiles/](packages/nix/core/ai/opencode/profiles/) when `core.ai.opencode.enable = true` |

Edit the Nix source, run `direnv reload`, and the artifact regenerates.

## Linting

`golangci-lint v2.12.2` is configured entirely in Nix:

- **Source of truth**: [packages/nix/core/toolchains/go/golangci-lint/default.nix](packages/nix/core/toolchains/go/golangci-lint/default.nix)
- **Artifact**: `.golangci.yml` at the repo root is a **read-only symlink** into the Nix store, regenerated on every shell entry. Gitignored.
- **Set**: standard linters (`errcheck`, `govet`, `ineffassign`, `staticcheck`, `unused`) plus `bodyclose`, `errorlint`, `gocritic`, **`gocyclo`**, `gosec`, `misspell`, `nakedret`, `nilerr`, `nolintlint`, `prealloc`, `revive`, `unconvert`, `unparam`, `usestdlibvars`.
- **govet shadow analyzer** enabled. **`gocyclo` threshold**: 15.
- **Formatters**: `gofumpt` + `goimports` (`-local bootstrap/`).
- **Runner**: `lint-go` iterates over every module declared in `core.toolchains.go.go-work.mods`, skips modules with no Go packages, and exits non-zero on the first failure.

To change lint rules:

```bash
$EDITOR packages/nix/core/toolchains/go/golangci-lint/default.nix
direnv reload                       # regenerate the .golangci.yml symlink
lint-go                             # verify clean across all modules
```

## AI agents

AI tooling is configured under [`packages/nix/core/ai/`](packages/nix/core/ai/) and toggled via `core.ai.{claude,opencode}.enable` in [`devenv.nix`](devenv.nix).

- **opencode** — `core.ai.opencode.profile` selects one of two plugin presets: `"max"` (the `oh-my-openagent` plugin) or `"slim"` (`oh-my-opencode-slim`). A single set of _abstract_ agents (`orchestrator`, `architecturer`, `researcher`, `codeExplorer`, `designer`, `worker`, …) is declared once in [`core/ai/opencode/agents/default.nix`](packages/nix/core/ai/opencode/agents/default.nix) — each carrying a `model`, `fallbacks`, `variant`, `skills`, and `mcps`. Each profile under [`core/ai/opencode/profiles/`](packages/nix/core/ai/opencode/profiles/) maps those abstract agents onto the plugin's named roles and writes `.opencode/<plugin>.json`.
- **claude** — `core.ai.claude` is an alias for devenv's `claude.code` integration. When enabled it writes `.claude/settings.json` (the experimental agent-teams flag) and a `CLAUDE.md` that re-exports `@AGENTS.md`, so Claude Code and every other agent read the same knowledge base.

The root enables `profile = "max"`; `services/portal/` uses `profile = "slim"`. See [packages/nix/AGENTS.md](packages/nix/AGENTS.md) for the option schema and the agent→preset wiring.

## Further reading

- [AGENTS.md](AGENTS.md) — full project knowledge base (this README is the 30-second tour; AGENTS.md is the full map)
- [docs/adrs/](docs/adrs/) — Architecture Decision Records (start with [ADR-0001](docs/adrs/0001-single-responsibility-go-packages.md))
- [docs/conventions/](docs/conventions/) — workspace-wide rules
- [packages/nix/AGENTS.md](packages/nix/AGENTS.md) — how to add a Nix devenv module + how the opencode/claude AI system is wired
