# Bootstrap

A greenfield Go monorepo scaffold managed by [Nix](https://nixos.org/) + [devenv](https://devenv.sh/). Three Go modules bound via [`go.work`](go.work); toolchain, shell environment, linters, pre-commit hooks, documentation conventions, and AI agents are all defined as code under [`packages/nix/`](packages/nix/).

> **Scaffold-stage.** Most product folders are `.gitkeep` placeholders — the value is in the conventions enforced by tooling, not in the code yet. Treat empty directories as placement contracts.

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
├── deploy/                 # infra defs                                    (scaffold)
├── docs/                   # adrs / specs / conventions / glossary / findings / debt
├── packages/
│   ├── go/                 # shared Go module (env, gormx, server/echox)
│   └── nix/                # devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/        # Clean Arch + CQRS service                     (scaffold)
├── tools/
│   ├── ai/skills/          # installable AI agent skills                   (scaffold)
│   └── generators/
│       └── ws-tree/        # tree + inline .info description renderer
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
| [packages/nix/AGENTS.md](packages/nix/AGENTS.md)       | Nix devenv module conventions + AI tools registry       |
| [services/portal/AGENTS.md](services/portal/AGENTS.md) | Clean Architecture + CQRS module layout                 |
| [tools/AGENTS.md](tools/AGENTS.md)                     | Generators, validators, scripts                         |

### Nix module structure

[`packages/nix/`](packages/nix/) splits into two trees with different opt-in semantics:

- **[`core/`](packages/nix/core/)** — mandatory: `workspace`, `git`, `secrets`, `docs`, `toolchains/{go,markdown,aws,terraform}`, `ai` (tools registry + explorer + spec-writer agents). Each module gates on its own `enable` flag declared in [`devenv.nix`](devenv.nix).
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
- **New folders**: Add a key to `workspace.mandatoryFolders` in [`devenv.nix`](devenv.nix) — devenv seeds `.gitkeep` + a row in `.info` automatically. Do not create scaffold dirs manually.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) via `commitizen` ran by [`prek`](https://github.com/j178/prek).
- **Documentation tracks**: six tracks under [`docs/`](docs/), each with its own `TEMPLATE.md` + `README.md` and distinct lifecycle. ADRs are append-only and numbered; specs/conventions/glossary are living; findings are append-only after `Resolved`; debt items have static sections plus an append-only _Encounters_ ledger. See [docs/AGENTS.md](docs/AGENTS.md) for per-track rules.
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
| `.claude/agents/*.md`     | [packages/nix/core/ai/agents/](packages/nix/core/ai/agents/) when `core.ai.claude.enable = true`                                                    |

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

The workspace ships two AI agents rendered from a declarative `core.ai.tools` registry. Every module contributes tool permissions and named prompt sections (`inputs`, `responsibilities`, `toolGuidelines`, `outputFormat`); agents assemble their final prompt by consuming the registry through two filters — `consumedContributions` (agent's appetite) and `targetAgents` (contribution's audience).

| Agent                                                        | Role                                                                                                                                         | Rendered at                  |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| [explorer](packages/nix/core/ai/agents/explorer/default.nix) | Read-only research — gathers context and evidence across the codebase, the internet, available CLIs, MCP servers, and registered toolchains. | `.claude/agents/explorer.md` |

| [spec-writer](packages/nix/core/ai/agents/spec-writer/default.nix) | Synthesis — turns Explorer findings + user design intent into one spec under [`docs/specs/`](docs/specs/) following the track's `TEMPLATE.md` and lifecycle. | `.claude/agents/spec-writer.md` |

Toggle per agent via `core.ai.agents.<name>.enable` in [`devenv.nix`](devenv.nix); toggle the claude / opencode renderer via `core.ai.{claude,opencode}.enable`. The registry schema, section keys, order bands, and contribution anti-patterns are documented in [packages/nix/AGENTS.md](packages/nix/AGENTS.md).

## Further reading

- [AGENTS.md](AGENTS.md) — full project knowledge base (this README is the 30-second tour; AGENTS.md is the full map)
- [docs/adrs/](docs/adrs/) — Architecture Decision Records (start with [ADR-0001](docs/adrs/0001-single-responsibility-go-packages.md))
- [docs/conventions/](docs/conventions/) — workspace-wide rules
- [packages/nix/AGENTS.md](packages/nix/AGENTS.md) — how to add a Nix devenv module + how the AI tools registry works
