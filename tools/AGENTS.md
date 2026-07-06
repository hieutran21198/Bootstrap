# tools/

## OVERVIEW

Workspace-wide tooling. Go module `bootstrap/tools`. Nix devenv modules have **moved** to `packages/nix/core/` -- look there for shell, linting, and git-hook configuration.

## STRUCTURE

```text
tools/
├── ai/
│   └── skills/     # rls-patterns skill body (generic skills are inlined in packages/nix/core/ai/skills/)
├── generators/
│   ├── ws-tree/    # directory listing tool that injects .info metadata (Go binary)
│   └── ws-worktree/ # managed git worktrees (.worktrees/<slug>): create/ref/pr/list/remove + port offsets
├── scripts/        # setup-branch-protection.sh GitHub ruleset helper
├── validators/
│   └── git-guard/  # git rules CLI (hooks + CI single source of truth)
└── go.mod          # bootstrap/tools
```

## WHERE TO LOOK

| Adding... | Goes in... |
|-----------|-----------|
| New CLI generator | `generators/<name>/` (package main; follow ws-tree pattern) |
| One-off dev shell helper | `scripts/<name>` |
| Workspace structure validator | `validators/<name>/` |
| Add/extend a git rule | `validators/git-guard/` (`branch.go` / `commit.go`; add a subcommand) |
| Server-side branch protection | `scripts/setup-branch-protection.sh` |
| Project-specific AI skill body | `ai/skills/<name>/SKILL.md` (plain markdown; the `core.ai.skills.<skill>` Nix module readFile-links it into `.claude/`/`.opencode/`) |
| Prompt / eval / agent helper | `ai/` |
| Nix devenv module (lint, hooks, Go toolchain) | Nix core modules under `packages/nix/` -- consult the sibling AGENTS guide |

## CONVENTIONS

- Generators: each is its own `package main` under `generators/<name>/`; compiled + injected into dev shell as a Nix package -- see `ws-tree` in `packages/nix/core/workspace/default.nix`, `ws-worktree` in `packages/nix/core/worktree/default.nix`
- `ws-worktree` delegates branch validation to `git-guard` (`branch-name` / `branch-protect`) -- git rules stay single-source; its `.worktreeinclude` file (repo root) lists gitignored files copied into new worktrees (simple `filepath.Match` globs + exact paths); behavior contract: `docs/specs/parallel-agent-worktrees.md`
- Validators follow the `git-guard` shape: `package main`, subcommand dispatcher in `main.go`, domain split into peer files, and per-validator `*_test.go`.
- Git rules are defined once in `validators/git-guard/` and shared by hooks + CI (no regex duplication). Subcommands: `commit-msg`, `commit-range`, `pr-title`, `branch-name`, `branch-protect`; ADR-0012.
- `scripts/setup-branch-protection.sh` is the idempotent GitHub ruleset applier (`gh` + `jq`): squash-only, delete-branch-on-merge, PR+review+passing-CI on `main`/`release/**`; ADR-0012.
- External binary deps: inject via `wrapProgram ... --prefix PATH` in the Nix derivation, NOT via `exec.LookPath` discovery
- Args parsing: small switch over `os.Args[1:]` for tiny CLIs; no `flag`/`cobra` unless complex
- Env-var contracts for tool-to-script communication: JSON-in-env-var (e.g. `WORKSPACE_TREE_DESCRIPTIONS`), not many flags

## ANTI-PATTERNS

- Do not ship a generator that depends on an external binary without wrapping it via Nix
- Do not put a generator under `services/portal/` or `apps/`
- Do not put Nix module logic in tools/ -- it belongs in `packages/nix/core/`
- Do not add heavy frameworks to `tools/go.mod`; keep generators stdlib-leaning
