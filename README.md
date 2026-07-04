# Bootstrap

A greenfield Go monorepo scaffold managed by [Nix](https://nixos.org/) + [devenv](https://devenv.sh/). Three Go modules bound via [`go.work`](go.work); toolchain, shell environment, linters, pre-commit hooks, and AI agents are all defined as code under [`packages/nix/`](packages/nix/). Documentation conventions live under [`docs/conventions/`](docs/conventions/).

> `packages/go/`, `services/portal/internal/`, `deploy/local/`, and `tools/` now carry real code; the value is in the conventions enforced by tooling.

## Quick start

Prerequisites: [Nix](https://nixos.org/download) with flakes enabled, [direnv](https://direnv.net/), [devenv](https://devenv.sh/).

```bash
git clone <repo> bootstrap
cd bootstrap
direnv allow            # one-time consent; auto-enters the dev shell on every cd
ws-info                 # workspace overview (auto-runs on shell entry)
```

Provisions: Go `1.26.4` + delve + gopls + `golangci-lint v2.12.2`, AWS CLI + aws-vault, [`prek`](https://github.com/j178/prek) pre-commit runner, `commitizen` + `git-guard` (commit/branch enforcement, ADR-0012), `ws-worktree`, secret scanners (`ripsecrets`, `trufflehog`, `detect-aws-credentials`, `detect-private-keys`). No `Makefile`, no `setup.sh` — devenv scripts are the runner.

`secretspec` is wired to the `dotenv://.env.local` provider on the `local` profile in [`devenv.yaml`](devenv.yaml); change the provider there if you use something else. Secret declarations live in tracked [`secretspec.toml`](secretspec.toml) — the `local` profile declares no additional secrets, so values are read from the untracked `.env.local` and shell entry works out of the box.

## Layout

```
bootstrap/
├── apps/
│   └── workspace-docs/     # Docusaurus docs site (own devenv; renders root + portal docs)
├── deploy/                 # infra defs + deploy/local (ZITADEL docker-compose)
├── docs/                   # GLOBAL docs: prds / adrs / architecture / specs / conventions / glossary / findings / debt / wiki
├── packages/
│   ├── go/                 # shared Go module (env, gormx, idgen, migrate, server/echox)
│   └── nix/                # devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/        # Clean Arch + CQRS service (+ its own docs/)
├── tools/
│   ├── ai/skills/          # AI agent skill bodies (plain SKILL.md; Nix readFile-links them)
│   ├── generators/
│   │   ├── ws-tree/        # tree + inline .info description renderer
│   │   └── ws-worktree/    # parallel-agent worktree manager
│   ├── scripts/            # dev helper scripts (setup-branch-protection.sh)
│   └── validators/         # workspace / arch validators (git-guard)
├── devenv.nix              # workspace name + module enablement
├── devenv.yaml             # imports packages/nix
└── go.work                 # binds packages/go, services/portal, tools (Nix-generated symlink)
```

Every populated subtree has its own `AGENTS.md` — terse knowledge base for humans and AI agents:

| Path                                                   | Covers                                                  |
| ------------------------------------------------------ | ------------------------------------------------------- |
| [AGENTS.md](AGENTS.md)                                 | Canonical project knowledge base — start here for depth |
| [docs/AGENTS.md](docs/AGENTS.md)                       | Eight formal doc tracks (prds, adrs, architecture, specs, conventions, glossary, findings, debt) + informal wiki |
| [apps/workspace-docs/AGENTS.md](apps/workspace-docs/AGENTS.md) | Docusaurus docs site wiring + conventions            |
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

- **Whitespace**: [`.editorconfig`](.editorconfig) (Nix-generated symlink) — Go uses tabs (`indent_size = 4`); all others 2-space; `insert_final_newline = true` universally. Markdown preserves trailing spaces; all other files trim them.
- **Go module path**: `bootstrap/<segment>/<module>`. No domain prefix; the workspace name _is_ the prefix.
- **Go version**: `1.26.4` across all `go.mod` + `go.work`. Match when adding modules.
- **Folder descriptions**: Add the path to `core.workspace.treeInfos` in the owning [`devenv.nix`](devenv.nix) (root, service, or app) — it generates the `.info` row `ws-tree` inlines (descriptions only).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/). Format via `commitizen` template + stricter scope/type rules enforced by `git-guard` in local hooks and CI (ADR-0012).
- **Documentation is two-tier**: workspace-wide standards live in root [`docs/`](docs/) (seven formal tracks — prds/adrs/specs/conventions/glossary/findings/debt, each with its own `TEMPLATE.md` + `README.md`, plus informal [`wiki/`](docs/wiki/)); service-only docs live under `services/<name>/docs/` (e.g. [services/portal/docs/](services/portal/docs/)). ADRs are append-only and numbered; specs/conventions/glossary are living; findings are append-only after `Resolved`; debt has an append-only _Encounters_ ledger. Architecture views are informal wiki pages under [`docs/wiki/architecture/`](docs/wiki/architecture/) (ADR-0020, superseded the formal `docs/architecture/` track). See [docs/AGENTS.md](docs/AGENTS.md) for per-track rules.
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
| `.opencode/agents/<NAME>.md` | per-agent files rendered by [packages/nix/core/ai/default.nix](packages/nix/core/ai/default.nix) from `core.ai.agents` + the capability wiring, when `core.ai.opencode.enable = true` |
| `.claude/skills/<name>/SKILL.md`, `.opencode/skills/<name>/SKILL.md` | enabled skills under [packages/nix/core/ai/skills/](packages/nix/core/ai/skills/) — each enabled `core.ai.skills.*` links its `SKILL.md` into the shared catalog (`.claude/` when `core.ai.claude.enable`, `.opencode/` when `core.ai.opencode.enable`); per-agent access is gated in the rendered agent files via each skill's `agents` allow-list. Project-specific skill bodies are authored as plain markdown under [`tools/ai/skills/<name>/SKILL.md`](tools/ai/skills/) and read via `builtins.readFile` (see [ADR-0007 §4](docs/adrs/0007-nix-devenv-developer-environment.md)) |

Edit the Nix source, run `direnv reload`, and the artifact regenerates.

## Linting

`golangci-lint v2.12.2` is configured entirely in Nix:

- **Source of truth**: [packages/nix/core/toolchains/go/golangci-lint/default.nix](packages/nix/core/toolchains/go/golangci-lint/default.nix)
- **Artifact**: `.golangci.yml` at the repo root is a **read-only symlink** into the Nix store, regenerated on every shell entry. Gitignored.
- **Set**: standard linters (`errcheck`, `govet`, `ineffassign`, `staticcheck`, `unused`) plus `bodyclose`, `errorlint`, `gocritic`, **`gocyclo`**, `gosec`, `misspell`, `nakedret`, `nilerr`, `nolintlint`, `prealloc`, `revive`, `unconvert`, `unparam`, `usestdlibvars`.
- **govet shadow analyzer** enabled. **`gocyclo` threshold**: 15.
- **Runner**: `lint-go` iterates over every module declared in `core.toolchains.go.go-work.mods`, skips modules with no Go packages, and exits non-zero on the first failure.

To change lint rules:

```bash
$EDITOR packages/nix/core/toolchains/go/golangci-lint/default.nix
direnv reload                       # regenerate the .golangci.yml symlink
lint-go                             # verify clean across all modules
```

## AI agents

AI tooling is configured under [`packages/nix/core/ai/`](packages/nix/core/ai/) and toggled via `core.ai.{claude,opencode}.enable` in [`devenv.nix`](devenv.nix).

- **opencode** — enabled via `core.ai.opencode.enable`. Each agent is defined once in [`core/ai/agents/`](packages/nix/core/ai/agents/) (`core.ai.agents.<name>`: `mode`, `posture`, card metadata, and `instructions` defaulting to a sibling `PROMPT.md` in the agent's module dir, overridable per consumer). Skills and MCPs each declare an `agents` allow-list; the renderer in [`core/ai/default.nix`](packages/nix/core/ai/default.nix) inverts those into every agent's opencode `permission` (allow for listed agents, deny for the rest) and writes `.opencode/agents/<NAME>.md`.
- **claude** — `core.ai.claude` is an alias for devenv's `claude.code` integration. When enabled it writes `.claude/settings.json` (the experimental agent-teams flag) and a `CLAUDE.md` that re-exports `@AGENTS.md`, so Claude Code and every other agent read the same knowledge base.

See [packages/nix/AGENTS.md](packages/nix/AGENTS.md) for the agent submodule schema and the capability→agent wiring.

## Further reading

- [AGENTS.md](AGENTS.md) — full project knowledge base (this README is the 30-second tour; AGENTS.md is the full map)
- [docs/adrs/](docs/adrs/) — Architecture Decision Records (start with [ADR-0001](docs/adrs/0001-single-responsibility-go-packages.md))
- [docs/conventions/](docs/conventions/) — workspace-wide rules
- [packages/nix/AGENTS.md](packages/nix/AGENTS.md) — how to add a Nix devenv module + how the opencode/claude AI system is wired
