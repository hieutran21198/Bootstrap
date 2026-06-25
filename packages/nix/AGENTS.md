# packages/nix/

## OVERVIEW
Nix devenv modules for the workspace. `core/` provides mandatory tooling; `extra/` provides optional add-ons. Imported by root `devenv.yaml`.

## STRUCTURE
```
packages/nix/
├── core/                     # mandatory workspace tooling
│   ├── ai/                   # AI registry + agent renderers + claude/opencode aliases
│   │   ├── default.nix       # core.ai.tools registry schema + claude/opencode aliases
│   │   └── agents/
│   │       ├── explorer/     # research agent: gathers context + evidence (consumes the full registry)
│   │       └── spec-writer/  # synthesis agent: Explorer findings + user context → one spec (consumes a tight whitelist)
│   ├── docs/                 # documentation tracks (adrs / specs / conventions / glossary / findings / debt) + AI contributions
│   ├── workspace/            # enterShell scripts, mandatoryFolders enforcement, AI contributions for layout
│   ├── git/                  # pre-commit hooks, secret scanners, AI contributions for git tooling
│   ├── secrets/              # secret scanning config
│   └── toolchains/
│       ├── go/               # Go toolchain, golangci-lint, go-work, AI contributions for Go tooling
│       │   ├── go-work/      # go.work generation
│       │   └── golangci-lint/ # linter config generation
│       ├── markdown/         # markdown linting
│       ├── aws/              # AWS CLI + AI contributions for cloud-side tooling
│       └── terraform/        # Terraform toolchain (optional core)
└── extra/                    # opt-in extensions
    └── dev-container/        # devcontainer support
```

## CONVENTIONS
- **Import in `devenv.yaml`**: modules are imported via `packages/nix/core/devenv.yaml`; each submodule exports options via `options.<name>.*`
- **Module ordering**: use descriptive directory names; no numeric prefix (that was the `_nixenv` convention — retired)
- **Generated artifacts**: `workspace/default.nix` generates `.editorconfig`, `.info`; `toolchains/go/golangci-lint/default.nix` generates `.golangci.yml` — these are gitignored symlinks into Nix store; do not hand-edit
- **`extra/` modules**: not imported by default; add to root `devenv.yaml` manually when needed
- **AI tools registry — schema**: `core/ai/default.nix` declares `core.ai.tools` and the `core.ai.claude` / `core.ai.opencode` aliases. Every module contributes `{ permissions; sections; targetAgents; order; }` from inside its own `lib.mkIf cfg.enable { ... }` when relevant. `sections` is `attrsOf lines` keyed by free-form names — contributions populate the keys they have something to say about, and agents declare which keys they consume.
- **AI tools registry — section keys consumed by agents**: both `explorer` and `spec-writer` consume `inputs` (what the agent can read and where), `responsibilities` (what to write back), `toolGuidelines` (per-tool usage rules), `outputFormat` (file naming and structure). The agent's prompt frame owns role / methodology / discipline / generic output shape; all workspace-specific knowledge (folder layout, doc tracks, templates, per-track naming) lives in the contributing module's `sections.<key>`.
- **AI tools registry — two filtering dimensions**: every agent's `applicable` set is filtered twice. (1) `consumedContributions` on the agent (`null` = all, list = whitelist by contribution name) declares the agent's appetite — Explorer leaves it `null` to consume everything; Spec Writer narrows to `[ "workspace" "docs" "docs-specs" ]` so it excludes git/go/aws/findings/debt by name. (2) `targetAgents` on each contribution (`[]` = universal, list = restrict to those agents) declares the contribution's audience — used by per-write-target docs entries (`docs-findings` and `docs-debt` target explorer; `docs-specs` targets spec-writer). A contribution applies when **both** filters pass.
- **AI tools registry — docs splits per write-target**: `core/docs/default.nix` emits four contributions: `docs` (universal: track listing in `inputs`, generic `TEMPLATE.md` + `README.md` rule in `outputFormat`, heavy-evidence pattern), `docs-findings` (explorer-only responsibilities), `docs-debt` (explorer-only responsibilities), `docs-specs` (spec-writer-only responsibilities). Each write-target lives in a separate registry entry with `targetAgents` set to the agent whose role owns that writing responsibility. Per-track filename and lifecycle rules belong in the track's `README.md`, not in the contribution.
- **AI tools registry — order bands**: `0-29` foundation (workspace=10, docs=15, docs-findings=16, docs-debt=17, docs-specs=18, git=20), `30-69` languages and standard toolchains (go=50), `70-99` specialised / cloud-side toolchains (aws=80), `100+` ad-hoc additions. Lower numbers render first inside each section.

## ANTI-PATTERNS
- ✗ Place Nix module logic outside `packages/nix/core/` or `packages/nix/extra/`
- ✗ Hand-edit generated artifacts (`.golangci.yml`, `.editorconfig`, `.info`) — Nix regenerates them on `direnv reload`
- ✗ Use numeric prefixes for module dirs (`_nixenv` pattern is retired)
- ✗ Import `extra/` modules from `core/` — `extra/` is opt-in, not forced
- ✗ Embed any workspace-specific knowledge in agent files under `core/ai/agents/`. The agent owns *role* (identity, methodology, discipline, generic output shape); the workspace owns *knowledge* (folder paths like `docs/findings/`, doc track names, file templates like `TEMPLATE.md`, naming conventions like `YYYY-MM-DD`-kebab-case, evidence-layout patterns like `<filename>.assets/`, specific tool names, `optionalString awsEnabled "..."`-style conditionals). Knowledge belongs in the owning module via `core.ai.tools.<name>.sections.<key>`. If you find yourself adding a path, a tool name, or a convention to an agent file, stop — find the module that owns it and contribute from there. Agents are renderers; the registry is the source of truth.
- ✗ Wrap an entire `attrsOf X` attribute in `lib.mkIf` when assigning through an alias — e.g. `core.ai.claude.agents = lib.mkIf cond { explorer = "..."; }`. The module merger stores the raw `mkIf` wrapper (`_type`/`condition`/`content`) instead of unpacking it, and the downstream consumer sees a broken value. Instead, push `mkIf` down to the leaf: `core.ai.claude.agents.explorer = lib.mkIf cond "...";`.
- ✗ Guess the upstream `agents` schema. `claude.agents` (devenv `src/modules/integrations/claude.nix`) takes a **submodule** with `{ description; proactive; tools; model; prompt; permissionMode; }`. `opencode.agents` (devenv `src/modules/integrations/opencode.nix`) takes **`lines`** (markdown with YAML frontmatter). They are *not* the same; do not render one format and assume both consumers accept it. When adding a new agent, read the actual upstream module file in `/nix/store/<hash>-source/src/modules/integrations/` first.
