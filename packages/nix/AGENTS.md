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
│   ├── ai/                     # core.ai.claude alias (→ claude.code) + CLAUDE.md→@AGENTS.md
│   │   └── opencode/           # core.ai.opencode: enable + profile (max|slim)
│   │       ├── agents/         # abstract agent defs: model / fallbacks / variant / skills / mcps
│   │       └── profiles/
│   │           ├── max/        # oh-my-openagent plugin preset (sisyphus, oracle, prometheus, …)
│   │           └── slim/       # oh-my-opencode-slim plugin preset (orchestrator, oracle, council, …)
│   ├── git/                    # pre-commit hooks
│   ├── secrets/                # secret-scanning config
│   ├── services/postgres/      # core.services.postgres: admin/writer/reader roles, POSTGRES_* env, pg-info
│   ├── workspace/              # core.workspace: name/treeInfos/editorConfig; generates .info + .editorconfig; ws-info/ws-tree
│   └── toolchains/
│       ├── go/                 # Go toolchain
│       │   ├── go-work/        # go.work generation (core.toolchains.go.go-work.mods)
│       │   └── golangci-lint/  # .golangci.yml generation
│       ├── markdown/           # markdownlint
│       ├── aws/                # AWS CLI + aws-vault
│       └── terraform/          # Terraform toolchain
└── extra/                      # opt-in — NOT imported by core
    └── dev-container/          # devcontainer support
```

## CONVENTIONS

- **Enable gating**: each module declares `options.<name>.enable` (possibly nested) and wraps its `config` in `lib.mkIf cfg.enable`. Consumers flip flags under `core.* = { ... }` in their `devenv.nix`. Root enables `ai`, `git`, `toolchains.{go,markdown,aws}`, `workspace`; portal additionally enables `services.postgres`.
- **Option helpers**: build options through `config.core.utils.*` (`makeStrOption`, `makeIntOption`, `makeEnumOption`, `makeListOption`, `makeAttrsOption`, `makePackageOption`, `failWhen`) instead of raw `lib.mkOption`. `core.utils` is read-only, defined in `utils/default.nix`, consumed e.g. by `ai/opencode/agents/default.nix`.
- **Module dir naming**: descriptive names, no numeric prefix (the `tools/_nixenv/` numbering convention is retired).
- **Generated artifacts** — gitignored Nix-store symlinks, never hand-edit; regenerate on `direnv reload`:
  - `workspace/default.nix` → `.info` (from `core.workspace.treeInfos`) + `.editorconfig` (from `core.workspace.editorConfig` + base defaults)
  - `toolchains/go/golangci-lint/default.nix` → `.golangci.yml`
  - `toolchains/go/go-work/default.nix` → `go.work` (from `core.toolchains.go.go-work.mods`)
  - `ai/default.nix` → `.claude/settings.json` + `CLAUDE.md` (`@AGENTS.md`); the chosen opencode profile writes `.opencode/<plugin>.json`
  - `ai/skills/<skill>/default.nix` → one `SKILL.md` per enabled agent: `.claude/skills/<name>/SKILL.md` (when `core.ai.claude.enable`) and `.opencode/skills/<name>/SKILL.md` (when `core.ai.opencode.enable`), gated additionally on the skill's own `enable` (e.g. `core.ai.skills.dbRLSPatterns.enable`)
- **AI system (opencode + claude)**: `core.ai.opencode.profile` is an enum — `"max"` (plugin `oh-my-openagent`) or `"slim"` (plugin `oh-my-opencode-slim`). `core.ai.opencode.agents.<name>` defines *abstract* agents (`model`, `fallbacks`, `variant`, `skills`, `mcps`): `orchestrator`, `orchestrator-minion`, `looker`, `architecturer`, `researcher`, `codeExplorer`, `designer`, `worker`. Each profile (`profiles/<p>/default.nix`) maps those abstract agents onto the plugin's named roles. `core.ai.claude` is an alias for devenv's `claude.code`; when enabled it writes `.claude/settings.json` (agent-teams env) and `CLAUDE.md → @AGENTS.md`. To add/retune an agent: edit `agents/default.nix`, then wire it into each `profiles/<profile>/default.nix` preset. **Skills** are a separate axis from agents: each `skills/<skill>/default.nix` declares `core.ai.skills.<skill>` (an `enable` flag + skill-specific options like `statements.whenInvocation`), builds a `SKILL.md` body, and — when its own `enable` is set — materializes that body once per enabled agent via `lib.optionalAttrs`-gated `files."<agent>/skills/<name>/SKILL.md".text`. The same body serves both agents (frontmatter is the overlapping subset: `name`/`description` for opencode, plus `user-invocable`/`allowed-tools` which Claude reads and opencode ignores). To add a skill: create `skills/<skill>/default.nix`, import it in `skills/default.nix`, and flip `core.ai.skills.<skill>.enable` in the consuming `devenv.nix`.
- **Postgres service**: `core.services.postgres` provisions devenv Postgres with idempotent `admin`/`writer`/`reader` login roles, exposes *structural* `POSTGRES_*` env vars (host/port/database/user/password — no DSN opinion), and registers a `pg-info` command via `core.workspace.toolchainCommandInfos`. Passwords come from `secretspec` in the consumer (see `services/portal/devenv.nix`).
- **`extra/` opt-in**: not imported by `core`; enable by importing in the consuming `devenv.yaml`/`devenv.nix` and flipping its flag (root: `extra.dev-container.enable`).

## ANTI-PATTERNS

- ✗ Place Nix module logic outside `core/` or `extra/`.
- ✗ Hand-edit generated artifacts (`.golangci.yml`, `.editorconfig`, `.info`, `go.work`, `.claude/*`, `CLAUDE.md`, `.opencode/*.json`) — Nix owns them.
- ✗ Reference a `core.docs` option or a `workspace.mandatoryFolders` option — **neither exists**. Folder descriptions come from `core.workspace.treeInfos` (descriptions only, no `.gitkeep` seeding); docs are plain markdown under root `docs/` and `services/<name>/docs/`, not a Nix module.
- ✗ Use numeric prefixes for module dirs (`_nixenv` pattern retired).
- ✗ Import `extra/` modules from `core/` — `extra/` is opt-in, not forced.
- ✗ Set `core.ai.opencode.profile` to anything but `"max"` or `"slim"` (enum; e.g. `"slim-go-openai"` fails evaluation).
- ✗ Build module options with raw `lib.mkOption` when a `core.utils.make*` helper fits — keep option shapes uniform.
- ✗ Wrap an entire `attrsOf X` attribute in `lib.mkIf` when assigning through an alias (e.g. `core.ai.claude.agents = lib.mkIf cond { … }`). The merger stores the raw `mkIf` wrapper and the consumer breaks. Push `mkIf` to the leaf: `core.ai.claude.agents.foo = lib.mkIf cond "…";`.
- ✗ Guess the upstream `claude.code` / `opencode` devenv submodule schema. Read the actual module under `/nix/store/<hash>-source/src/modules/integrations/` first; the native Claude Code agent schema (built-ins, frontmatter, tools/skills gating) is documented in [docs/findings/2026-06-26-claude-code-agent-configuration.md](../../docs/findings/2026-06-26-claude-code-agent-configuration.md).
