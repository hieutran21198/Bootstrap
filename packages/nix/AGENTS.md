# packages/nix/

## OVERVIEW

Nix devenv modules for the workspace. `core/` = mandatory tooling; `extra/` = opt-in add-ons (not imported by `core`). A consumer wires them in via its `devenv.yaml` `imports: [ <path>/packages/nix ]`, which loads `packages/nix/devenv.nix` → `core/default.nix` + `extra/default.nix`. Every module gates on an `enable` flag set in the consuming `devenv.nix`. Both the root and each service (e.g. `services/portal/`) import this same tree.

## STRUCTURE

```
packages/nix/
├── devenv.nix                  # imports core/ + extra/
├── devenv.yaml                 # nixpkgs input pin (standalone eval)
├── core/                       # mandatory — core/default.nix imports every module below
│   ├── utils/                  # option-builder helpers exposed as core.utils
│   ├── ai/                     # core.ai.*: agents / skills / mcps / commands + opencode + claude alias (CLAUDE.md→@AGENTS.md)
│   │   ├── agents/             # per-agent modules (00-orchestrator … 09-dev-environment): mode / posture / card / instructions (PROMPT.md)
│   │   ├── skills/             # skill catalog modules, each with an `agents` allow-list
│   │   ├── mcps/               # MCP server modules, each with an `agents` allow-list
│   │   ├── commands/           # opencode command modules
│   │   └── opencode/           # core.ai.opencode.enable — opencode settings + plugins
│   ├── git/                    # pre-commit hooks
│   ├── secrets/                # secret-scanning config
│   ├── services/postgres/      # core.services.postgres: admin/writer/reader (+ opt-in systemReader) roles, POSTGRES_* env, pg-info
│   ├── workspace/              # core.workspace: name/treeInfos/editorConfig; generates .info + .editorconfig; ws-info/ws-tree
│   ├── worktree/               # core.worktree: ws-worktree CLI + portOffset read from the .worktree-offset marker
│   └── toolchains/
│       ├── go/                 # Go toolchain
│       │   ├── go-work/        # go.work generation (core.toolchains.go.go-work.mods)
│       │   ├── golangci-lint/  # .golangci.yml generation
│       │   └── govulncheck/    # govuln-scan command (per-module govulncheck)
│       ├── markdown/           # markdownlint
│       ├── aws/                # AWS CLI + aws-vault
│       └── terraform/          # Terraform toolchain
└── extra/                      # opt-in — NOT imported by core
    └── dev-container/          # devcontainer support
```

## CONVENTIONS

- **Enable gating**: each module declares `options.<name>.enable` (possibly nested) and wraps its `config` in `lib.mkIf cfg.enable`. Consumers flip flags under `core.* = { ... }` in their `devenv.nix`. Root enables `ai` (agents 00–09 + linear/github MCPs), `git`, `worktree`, `toolchains.{go,markdown,aws}`, `workspace`; portal enables `worktree`, `services.postgres` (+ `systemReader`), `workspace`; workspace-docs enables `worktree`, `ai` (opencode with per-agent model selection), `workspace`, `toolchains.markdown`.
- **Option helpers**: build options through `config.core.utils.*` (`makeStrOption`, `makeIntOption`, `makeEnumOption`, `makeListOption`, `makeAttrsOption`, `makePackageOption`, `failWhen`) instead of raw `lib.mkOption`. `core.utils` is read-only, defined in `utils/default.nix`, consumed e.g. by `ai/opencode/agents/default.nix`.
- **Module dir naming**: descriptive names, no numeric prefix (the `tools/_nixenv/` numbering convention is retired).
- **Generated artifacts** — gitignored Nix-store symlinks, never hand-edit; regenerate on `direnv reload`:
  - `workspace/default.nix` → `.info` (from `core.workspace.treeInfos`) + `.editorconfig` (from `core.workspace.editorConfig` + base defaults)
  - `toolchains/go/golangci-lint/default.nix` → `.golangci.yml`
  - `toolchains/go/go-work/default.nix` → `go.work` (from `core.toolchains.go.go-work.mods`)
  - `ai/default.nix` → `.claude/settings.json` + `CLAUDE.md` (`@AGENTS.md`) + the per-agent `.opencode/agents/<NAME>.md` files (rendered from `core.ai.agents` metadata/posture/instructions plus the capability wiring)
  - `ai/skills/<skill>/default.nix` → the skill's `SKILL.md` written once to the shared catalog: `.claude/skills/<name>/SKILL.md` (when `core.ai.claude.enable`) and `.opencode/skills/<name>/SKILL.md` (when `core.ai.opencode.enable`), gated on the skill's own `enable` (e.g. `core.ai.skills.rls-patterns.enable`). Per-agent *access* is a separate gate rendered into the opencode agent files (see the AI-system bullet), not per-agent materialization. **Project-specific skill bodies are authored as plain markdown** under `tools/ai/skills/<name>/SKILL.md` and read with `builtins.readFile`; Nix only links them — it does not own the prose (see ADR-0007 §4)
- **AI system (opencode + claude)**: `core.ai.agents.<name>` (an `attrsOf submodule` declared in `ai/default.nix`) defines each agent: `mode` (`primary`/`subagent`), optional `model`, card metadata (`role`/`lane`/`description`/`capabilities`/`delegateWhen`/`avoidWhen`/`successCriteria`), an agent-owned `posture` (built-in-tool baseline — e.g. `edit`/`bash` = `deny` for read-only agents, `task` = `allow` on the orchestrator to force delegation), and `instructions` (`lib.mkDefault (builtins.readFile ./PROMPT.md)` — a sibling `PROMPT.md` in the agent's own module dir; `mkDefault` lets a consumer override it via `core.ai.agents.<name>.instructions`). Skills and MCPs are **not** set on agents: each `skills/<s>` and `mcps/<m>` module declares an `agents` allow-list, and the renderer in `ai/default.nix` inverts those into a per-agent opencode `permission` map (allow for listed agents, `deny` for the rest — default-deny) plus a generated `<tools>` prompt section from each capability's `toolDef`. The renderer emits every enabled agent's `.opencode/agents/<NAME>.md` (frontmatter `description`/`mode`/`permission` via `builtins.toJSON`, body = instructions + tools + the delegation/completion protocol) and the orchestrator's `## Registered Agents` cards. `core.ai.claude` is an alias for devenv's `claude.code`; when enabled it writes `.claude/settings.json` (agent-teams env) and `CLAUDE.md → @AGENTS.md`. To add an agent: create `agents/NN-<name>/default.nix` (metadata + posture) + a sibling `PROMPT.md`, import it in `agents/default.nix`, and set `core.ai.agents.<name>.enable` in the consuming `devenv.nix`; to wire a skill/MCP to it, add the agent to that capability's `agents` list. **Skills** are a separate axis from agents: each `skills/<skill>/default.nix` declares `core.ai.skills.<skill>` (at minimum an `enable` flag), obtains a `SKILL.md` body, and — when its own `enable` is set — materializes that body once into the shared catalog (`.opencode/skills/<name>/`, `.claude/skills/<name>/`). Which agents may load it is a separate gate: the skill's `agents` allow-list becomes a per-agent `permission.skill.<name>` (allow for listed agents, `deny` for the rest) in the rendered opencode agent files. The same body serves both agents (the full frontmatter — `name`/`description` for opencode, plus `user-invocable`/`allowed-tools` which Claude reads and opencode ignores — lives at the top of the `SKILL.md`). **Skill body authoring:** every `core.ai.skills.<skill>.content` default reads a plain-markdown `SKILL.md` with `builtins.readFile`; do not inline skill bodies in Nix. Generic/reusable skills keep `SKILL.md` beside their module at `packages/nix/core/ai/skills/<skill>/SKILL.md` and use `default = builtins.readFile ./SKILL.md;`. Project-specific skills keep `SKILL.md` under `tools/ai/skills/<name>/SKILL.md` and use `default = builtins.readFile (config.core.workspace.root + "/tools/ai/skills/<name>/SKILL.md");`. In both cases the file contains the full frontmatter + body served to Claude and opencode; Nix owns only the generated catalog artifacts, not the prose. To add a skill: create `skills/<skill>/default.nix`, add the appropriate `SKILL.md`, import it in `skills/default.nix`, declare the `agents` allow-list, and enable `core.ai.skills.<skill>.enable` in the consuming `devenv.nix`.
- **Postgres service**: `core.services.postgres` provisions devenv Postgres with idempotent `admin`/`writer`/`reader` (+ opt-in `systemReader`) login roles, exposes *structural* `POSTGRES_*` env vars (host/port/database/user/password — no DSN opinion), and registers a `pg-info` command via `core.workspace.toolchainCommandInfos`. The effective port is `port + core.worktree.portOffset`. Passwords come from `secretspec` in the consumer (see `services/portal/devenv.nix`).
- **`extra/` opt-in**: not imported by `core`; enable by importing in the consuming `devenv.yaml`/`devenv.nix` and flipping its flag (root: `extra.dev-container.enable`).

## ANTI-PATTERNS

- ✗ Place Nix module logic outside `core/` or `extra/`.
- ✗ Hand-edit generated artifacts (`.golangci.yml`, `.editorconfig`, `.info`, `go.work`, `.claude/*`, `CLAUDE.md`, `.opencode/*.json`) — Nix owns them.
- ✗ Reference a `core.docs` option or a `workspace.mandatoryFolders` option — **neither exists**. Folder descriptions come from `core.workspace.treeInfos` (descriptions only, no `.gitkeep` seeding); docs are plain markdown under root `docs/` and `services/<name>/docs/`, not a Nix module.
- ✗ Use numeric prefixes for module dirs (`_nixenv` pattern retired).
- ✗ Import `extra/` modules from `core/` — `extra/` is opt-in, not forced.
- ✗ Hand-set `skills`/`mcps` or hardcode tool access inside an agent module — capability modules own the `agents` allow-list and the renderer derives each agent's `permission` (default-deny). Agents own only identity, `posture`, and `instructions`.
- ✗ Build module options with raw `lib.mkOption` when a `core.utils.make*` helper fits — keep option shapes uniform.
- ✗ Wrap an entire `attrsOf X` attribute in `lib.mkIf` when assigning through an alias (e.g. `core.ai.claude.agents = lib.mkIf cond { … }`). The merger stores the raw `mkIf` wrapper and the consumer breaks. Push `mkIf` to the leaf: `core.ai.claude.agents.foo = lib.mkIf cond "…";`.
- ✗ Guess the upstream `claude.code` / `opencode` devenv submodule schema. Read the actual module under `/nix/store/<hash>-source/src/modules/integrations/` first; the native Claude Code agent schema (built-ins, frontmatter, tools/skills gating) is documented in [docs/findings/2026-06-26-claude-code-agent-configuration.md](../../docs/findings/2026-06-26-claude-code-agent-configuration.md).
