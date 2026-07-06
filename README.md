# Bootstrap

Bootstrap is a reusable starter repository for teams that want a **Nix/devenv-managed Go workspace with an AI-agent operating model and SDLC process already wired in**. Fork it, copy it, or mine it for patterns; the intent is not that every adopter keeps the sample services forever, but that the workspace rules, generated tooling, and delivery workflow are ready on day one.

The template ships four pillars, in this order of importance:

1. **Declarative-first workspace** — [Nix](https://nixos.org/) + [devenv](https://devenv.sh/) define the development environment as code: toolchain versions, shell scripts, linters, pre-commit hooks, docs-tree descriptions, `go.work`, and AI agent config all come from [`packages/nix/`](packages/nix/). Generated artifacts such as `.golangci.yml`, `.editorconfig`, `.info`, `go.work`, `.opencode/agents/*`, `.claude/*`, and `CLAUDE.md` are Nix-store symlinks; edit the Nix source and reload, never hand-maintain the artifact.
2. **Built-in AI agent team** — one orchestrator plus nine subagents (researcher, explorer, architect, backend-engineer, frontend-engineer, scribe, release-engineer, security-reviewer, dev-environment) are wired through `core.ai.agents`. Agent posture controls built-in tool permissions; skills and MCPs declare capability-owned allow-lists that render into default-deny per-agent permissions. Inter-agent context travels only through artifact-mediated Delegation Briefs and Completion Reports backed by disk paths — not shared transcript memory.
3. **Full SDLC workflow baked in** — the default operating model is Idea → PRD → Epic/Spec → Implementation → Review → Release → Learning, with three inline human authority gates: PRD acceptance, product/DoD sign-off, and release go/no-go. The durable project source of truth is the seven formal [`docs/`](docs/) tracks (`prds`, `adrs`, `specs`, `conventions`, `glossary`, `findings`, `debt`) plus informal `wiki/`; Linear is the delivery/operation source of truth and closure requires evidence.
4. **Everything else is a scaffold to build on** — the Go workspace (`go.work` binding `packages/go`, `services/portal`, and `tools`), the example Clean Architecture/CQRS `services/portal` module, and the `apps/workspace-docs` Docusaurus site are illustrative starting points. Keep, replace, or extend those modules for your product while preserving the Nix/devenv/agent/SDLC scaffolding.

> `packages/go/`, `services/portal/internal/`, `deploy/local/`, and `tools/` carry real code, but the reusable value is in the conventions enforced by tooling, docs, and generated shell wiring. `services/portal/internal/` has domain/app/infra code; `delivery/http`, `config/`, and `infra/zitadel/` are still planned scaffolding.

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

## What to keep vs. replace when adopting

- **Keep the template spine**: [`packages/nix/`](packages/nix/), generated-file ownership, root [`docs/`](docs/) tracks, [`AGENTS.md`](AGENTS.md), the AI agent protocol, `git-guard`, `ws-tree`, `ws-worktree`, and the devenv-first runner model.
- **Customize the product surface**: `packages/go/`, `services/portal/`, `apps/workspace-docs/`, and `deploy/local/` are useful examples. Rename, replace, or add modules/services as your product requires, then update `core.toolchains.go.go-work.mods`, `core.workspace.treeInfos`, service/app devenvs, and docs pointers in the Nix source.
- **Do not edit generated artifacts directly**: if a file appears in the generated-files table below, change the owning Nix module and run `direnv reload`.

## Layout

```text
bootstrap/
├── apps/
│   └── workspace-docs/     # Docusaurus docs site (own devenv; renders root + portal docs)
├── deploy/                 # deployment devenv + deploy/local ZITADEL docker-compose
├── docs/                   # GLOBAL docs: 7 formal tracks + wiki/ (informal; architecture views per ADR-0020)
├── packages/
│   ├── go/                 # shared Go module (env, errorsx, aws/ssmx, gormx, idgen, migrate, echox)
│   └── nix/                # devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/        # example Clean Arch + CQRS service (+ its own docs/; domain/app/infra built, delivery/config/zitadel planned)
├── tools/                  # workspace tooling Go module
│   ├── ai/skills/          # project-specific AI skill bodies (currently rls-patterns only; git-workflow/go-pattern/init-deep now inline under packages/nix/core/ai/skills/)
│   ├── generators/
│   │   ├── ws-tree/        # tree + inline .info description renderer
│   │   └── ws-worktree/    # parallel-agent worktree manager
│   ├── scripts/            # dev helper scripts (setup-branch-protection.sh)
│   └── validators/         # workspace / arch validators (git-guard)
├── devenv.nix              # workspace name + core.workspace.treeInfos + module toggles
├── devenv.yaml             # imports packages/nix
└── go.work                 # binds packages/go, services/portal, tools (Nix-generated symlink)
```

Every populated subtree has its own `AGENTS.md` — terse knowledge base for humans and AI agents:

| Path                                                   | Covers                                                  |
| ------------------------------------------------------ | ------------------------------------------------------- |
| [AGENTS.md](AGENTS.md)                                 | Canonical project knowledge base — start here for depth |
| [docs/AGENTS.md](docs/AGENTS.md)                       | Seven formal doc tracks (prds, adrs, specs, conventions, glossary, findings, debt) + informal wiki |
| [apps/workspace-docs/AGENTS.md](apps/workspace-docs/AGENTS.md) | Docusaurus docs site wiring + conventions            |
| [packages/go/AGENTS.md](packages/go/AGENTS.md)         | Shared Go library governance (SRP per-package)          |
| [packages/nix/AGENTS.md](packages/nix/AGENTS.md)       | Nix devenv module conventions + opencode/claude AI setup |
| [services/portal/AGENTS.md](services/portal/AGENTS.md) | Clean Architecture + CQRS module layout                 |
| [tools/AGENTS.md](tools/AGENTS.md)                     | Generators, validators, scripts                         |

### Nix module structure

[`packages/nix/`](packages/nix/) splits into two trees with different opt-in semantics:

- **[`core/`](packages/nix/core/)** — mandatory: `utils` (option-builder helpers), `ai` (opencode agents/profiles + claude alias), `git`, `secrets`, `services/postgres`, `workspace`, `worktree`, `toolchains/{go,markdown,aws,terraform}`. Each module gates on its own `enable` flag declared in [`devenv.nix`](devenv.nix) or the consuming service/app devenv.
- **[`extra/`](packages/nix/extra/)** — opt-in add-ons that are not imported by `core` by default: currently `dev-container`. Living outside `core/` signals "default off"; flip the enable flag to wire it in.

Consumers import the shared module tree via `devenv.yaml` (`imports: [ <path>/packages/nix ]`). The root, `services/portal/`, and `apps/workspace-docs/` each own a devenv and enable only the modules they need.

## Shell commands

Available after entering the shell (i.e. any `cd` into the repo with direnv enabled):

| Command                        | What                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------- |
| `ws-info`                      | Workspace overview (root, name, layout, available commands). Auto-runs on entry.  |
| `ws-tree`                      | Directory tree with inline `.info` descriptions.                                  |
| `ws-tree --tabular --doc-only` | Compact docs-only map (the format AI agents quote when describing the workspace). |
| `go-info`                      | Go toolchain `version` + `env` summary + `go.work` module list.                   |
| `lint-go`                      | `golangci-lint` across every `go.work` module (pass `--fix` to auto-fix).         |
| `govuln-scan`                  | `govulncheck` across every `go.work` module.                                      |
| `ws-worktree`                  | Managed git worktrees under `.worktrees/<slug>` for parallel agent sessions.      |
| `devenv up`                    | Spin up workspace services (when defined).                                        |
| `devenv shell`                 | Explicit shell entry (bypassing direnv).                                          |

Scoped devenv shells add local commands: `services/portal` has `migrate-up` / `migrate-down` / `migrate-status` / `migrate-new` / `pg-info`; `apps/workspace-docs` has `docs-install` / `docs-dev` / `docs-build` / `docs-serve`.

## SDLC workflow

The template's workflow is documented in [`docs/wiki/implementation-workflow.md`](docs/wiki/implementation-workflow.md):

| # | Stage | Durable artifact / system | Default actor(s) | Human gate |
|---|-------|---------------------------|------------------|------------|
| 1 | Idea | Raw signal | Orchestrator routes; Researcher / Explorer discover | — |
| 2 | PRD | `docs/prds/` | Scribe drafts; Researcher supplies context | **PRD acceptance** |
| 3 | Epic / Task / Spec | `docs/specs/` + `docs/adrs/` + Linear | Architect designs; Scribe files work | — |
| 4 | Implementation | Code + PR | Backend / Frontend engineers | — |
| 5 | Review | Technical verdict + DoD | Architect reviews (`writer ≠ reviewer`) | **Product / DoD sign-off** |
| 6 | Release | Version, changelog, staged config, tag/deploy | Release-engineer prepares/executes | **Release go/no-go** |
| 7 | Learning | `docs/findings/`, `docs/debt/`, `docs/wiki/` | Scribe records; Architect promotes decisions/designs when needed | — |

Two sources of truth are deliberate: `docs/` owns durable project intent/history, while Linear owns live delivery state. `.sdlc/<task-slug>/` is only worktree-local scratch space for active agent hand-offs; promotion into `docs/` means re-authoring into the correct formal track, not moving scratch files.

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
| `.claude/skills/<name>/SKILL.md`, `.opencode/skills/<name>/SKILL.md` | enabled skills under [packages/nix/core/ai/skills/](packages/nix/core/ai/skills/) — each enabled `core.ai.skills.*` links its `SKILL.md` into the shared catalog (`.claude/` when `core.ai.claude.enable`, `.opencode/` when `core.ai.opencode.enable`); per-agent access is gated in the rendered agent files via each skill's `agents` allow-list. **Two authoring modes:** project-specific skill bodies are authored as plain markdown under [`tools/ai/skills/<name>/SKILL.md`](tools/ai/skills/) and read via `builtins.readFile` (currently `rls-patterns`); generic, reusable skills inline the body string directly in their Nix module at `packages/nix/core/ai/skills/<name>/default.nix` (currently `git-workflow`, `go-pattern`, `init-deep`). See [ADR-0007 §4](docs/adrs/0007-nix-devenv-developer-environment.md) |

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

The core operating roster is:

| Role | Lane | Use when |
| ---- | ---- | -------- |
| **orchestrator** | Primary coordinator | Break down multi-step goals, route work, preserve plan/decision indexes, enforce `writer ≠ reviewer`. |
| **researcher** | External research | Evaluate libraries, upstream docs, ecosystem options, or domain facts; read-only. |
| **explorer** | Repository discovery | Trace how this repo works, find files/symbols, map call paths; read-only. |
| **architect** | Design + review | Produce/validate ADRs and specs; provide independent technical review gates. |
| **backend-engineer** | Go/backend implementation | Implement/refactor Go in `packages/go`, `services/portal`, and `tools`. |
| **frontend-engineer** | App/UI implementation | Work on `apps/` UI, including the Docusaurus docs site. |
| **scribe** | Delivery record | File/sync work items, maintain status, debt, roadmap, and evidence-backed closeout. |
| **release-engineer** | CI/CD + release | Maintain hooks/CI/release wiring, prepare releases, run release commands after human go/no-go. |
| **security-reviewer** | Security & authz review | Independently review RLS/authz-sensitive DB changes for tenant/system scoping, role/GUC contracts, and `SystemReadCapability` use ([ADR-0014](docs/adrs/0014-security-reviewer-agent.md)). |
| **dev-environment** | Local dev & workspace tooling | Own worktree lifecycle, devenv/Nix toggles, direnv/local env bootstrap, codegraph setup guidance, and `.sdlc/` cleanup ([ADR-0019](docs/adrs/0019-dev-environment-agent.md)). |

Posture is agent-owned: read-only agents and the orchestrator deny `edit`/`bash`; engineers and dev-environment get edit + shell for their lanes; architect and scribe may edit docs but do not run shell. Capability access is owned by skill/MCP modules and rendered default-deny for every unlisted agent.

All hand-offs follow [`docs/conventions/agents/artifact-mediated-communication.md`](docs/conventions/agents/artifact-mediated-communication.md): the orchestrator sends a Delegation Brief with disk-path inputs, the subagent returns a Completion Report with raw verification output, and durable learnings are promoted into the right docs track by the owning role.

See [docs/wiki/agent-team.md](docs/wiki/agent-team.md) and [packages/nix/AGENTS.md](packages/nix/AGENTS.md) for the full posture/capability wiring.

## Further reading

- [AGENTS.md](AGENTS.md) — full project knowledge base (this README is the landing page; AGENTS.md is the operational map)
- [docs/wiki/implementation-workflow.md](docs/wiki/implementation-workflow.md) — seven-stage SDLC pipeline and human gates
- [docs/wiki/agent-team.md](docs/wiki/agent-team.md) — agent roster, posture, and capability model
- [docs/adrs/0007-nix-devenv-developer-environment.md](docs/adrs/0007-nix-devenv-developer-environment.md) — why Nix + devenv own the developer environment
- [docs/adrs/0017-evidence-based-delivery.md](docs/adrs/0017-evidence-based-delivery.md) — Linear + evidence-backed delivery rule
- [docs/adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md](docs/adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md) — agent hand-off protocol and `.sdlc/` scratch workspace
- [docs/conventions/](docs/conventions/) — workspace-wide rules
- [packages/nix/AGENTS.md](packages/nix/AGENTS.md) — how to add a Nix devenv module and how the opencode/claude AI system is wired
