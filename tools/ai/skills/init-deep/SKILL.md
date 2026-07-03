---
name: init-deep
description: Deep, codegraph-driven regeneration of this workspace's hierarchical AGENTS.md knowledge base — root plus scored subdirectory files. Use when bootstrapping AGENTS.md for a new area or refreshing it after the architecture shifts.
user-invocable: true
allowed-tools: Read, Grep, Glob, Task, TodoWrite, mcp__codegraph__codegraph_explore
---

# Init Deep

Regenerate this repo's durable agent memory: one root `AGENTS.md` plus only the
subdirectory `AGENTS.md` files that earn their keep. This is the deep alternative
to `/init`: multi-pass, parallel, codegraph-led, and opinionated about this
workspace's Nix/devenv + Go monorepo shape.

## When this applies

- Bootstrapping `AGENTS.md` for a new package, service, docs tree, or tooling area.
- Refreshing the hierarchy after architecture, module boundaries, or commands shift.
- Re-scoring which directories deserve local guidance instead of root-only notes.
- Auditing existing `AGENTS.md` files for drift, duplication, stale commands, or stale code maps.

## Operating model

- Track every phase with `TodoWrite`; keep the user informed at phase boundaries.
- You are the orchestrator: drive discovery/review, then delegate actual file writes to an engineer.
- `Write` and `Edit` are exercised by the delegated writing engineer, not by the orchestrator/direct runner.
- Prefer `Edit` for existing `AGENTS.md` files and preserve still-true content; use `Write` only for brand-new files.
- Never run broad regeneration blindly. First read every existing `AGENTS.md` and decide what remains true.
- Trust `codegraph_explore` for symbols, call paths, and blast radius. Do not re-grep the CODE MAP.

## Phase 1 — discovery (parallel, read-only)

Fan out read-only discovery in parallel. Scale the number of `explorer`-agent tasks with repo size:
more files, lines, depth, modules, or services means more parallel probes.

- Read all existing `AGENTS.md` files first: root, `docs/`, `packages/nix/`, `packages/go/`,
  `services/portal/`, `tools/`, and any new service/package/app-local files.
- Run `codegraph_explore` concurrently for structure, entry points, key symbols, call paths,
  reference centrality, and blast radius. Codegraph is the mandated code-map engine here, not LSP.
- Cover repo layout, apps, Go modules, Nix/devenv modules, commands, build/test/lint flows,
  docs ownership, service boundaries, and generated artifacts.
- Distinguish placeholder/scaffold directories from populated app/devenv roots. Score populated
  app subtrees such as `apps/workspace-docs/`; skip empty scaffolds unless they have unique rules.
- Preserve true project facts already present; mark stale facts for removal rather than rewriting from scratch.

## Phase 2 — score locations

Root `AGENTS.md` is always written. Subdirectory files are earned with a weighted heuristic:

- File count and line count: enough surface area to need local guidance.
- Subdirectory count and depth: enough navigation complexity to justify a map.
- Code density: source-heavy areas beat placeholder-only trees.
- Module/service/app boundary: Go module, Nix module tree, service root, app root, or local
  `devenv.nix` scores high.
- Symbol density and reference centrality from codegraph: exported APIs, callers, and call paths matter.
- Unique conventions or anti-patterns: local rules that should not clutter the root.

This repo is already hierarchical: root plus `docs/`, `packages/nix/`, `packages/go/`,
`services/portal/`, and `tools/`, with populated app roots now present too (currently
`apps/workspace-docs/`, a Docusaurus app with its own `devenv.nix`). Treat init-deep here
primarily as a refresh. Respect the two-tier docs model: workspace-wide docs and guidance at
root; service-owned docs and guidance under `services/<name>/`. Do not collapse a service
subtree into the root file.

## Phase 3 — generate

Use the existing files as format exemplars. Keep prose telegraphic, high-signal, and repo-specific.

Root `AGENTS.md` sections, in order:

```markdown
**Generated:** <ISO8601>
**Commit:** <short-sha>
**Branch:** <branch>

## OVERVIEW
## STRUCTURE
## WHERE TO LOOK
## CODE MAP
## CONVENTIONS
## ANTI-PATTERNS (THIS PROJECT)
## UNIQUE STYLES
## COMMANDS
## NOTES
```

The delegated writing engineer must gather the header values fresh at write time:
current ISO8601 timestamp, `git rev-parse --short HEAD`, and current branch. The
orchestrator has `bash = deny`, so it delegates this shell work; never copy stale
header values from the previous file.

- `OVERVIEW`: 1–2 sentences — what the repo is and the core stack.
- `STRUCTURE`: compact tree; explain non-obvious purposes only.
- `WHERE TO LOOK`: `| Task | Location | Notes |` table.
- `CODE MAP`: `| Symbol | Type | Location | Role |` from codegraph; skip only when the repo has fewer than 10 files.
- `CONVENTIONS`: deviations from standard behavior only.
- `ANTI-PATTERNS (THIS PROJECT)`: things that are specifically wrong here.
- `UNIQUE STYLES`, `COMMANDS`, `NOTES`: short, durable gotchas and runnable commands.
- Right-size root to roughly 50–150 lines.

Subdirectory `AGENTS.md` files start with a path H1 and default to the scoped sections:

- First line: `# <relative-path>/`.
- `OVERVIEW` — one line.
- `STRUCTURE` — only if the directory has more than five subdirectories.
- `WHERE TO LOOK`.
- `CONVENTIONS` — only if different from the parent.
- `ANTI-PATTERNS`.
- Preserve justified local sections already present and still true, such as `GOVERNANCE` or `NOTES`.
- Never repeat parent content; link upward mentally by scope, not by duplication.
- Right-size subdir files to roughly 30–80 lines.

## Phase 4 — review and deduplicate

- Strip generic advice an agent could know without this repo.
- Remove duplicate parent guidance from child files.
- Verify all commands, module paths, and ownership claims against current discovery.
- Check telegraphic style, section order, line budgets, and table shape.
- Re-check that every existing true fact was preserved and every stale fact was removed.

## Guardrails for this workspace

- `AGENTS.md` is authored by init-deep. These are generated and off-limits: `.pre-commit-config.yaml`,
  `.golangci.yml`, `.editorconfig`, `go.work`, every `.info` file, `.claude/*`, `.opencode/*`,
  and `CLAUDE.md`.
- `CLAUDE.md` is Nix-generated as `@AGENTS.md`; never edit it and do not create or symlink
  per-directory `CLAUDE.md` files.
- Folder descriptions are not free text. They live in `core.workspace.treeInfos` in the owning
  `devenv.nix` and render into `.info`. Init-deep documents structure in `AGENTS.md`; it does
  not seed `.gitkeep` or edit `.info`.
- Respect service ownership. Root files cover workspace-wide rules; `services/<name>/AGENTS.md`
  and `services/<name>/docs/` cover service-local rules.
- Check existence before edits. Existing `AGENTS.md` → `Edit`/refresh; missing `AGENTS.md` → `Write`.
- Do not touch other skills, agent prompts, generated opencode/Claude artifacts, or Nix module imports
  as part of an init-deep run.

## Anti-patterns

- Running init-deep as a single pass or a single-agent read of the tree.
- Replacing existing `AGENTS.md` content wholesale without preserving still-true facts.
- Creating child files because a directory exists rather than because the scoring heuristic justifies it.
- Repeating the root anti-patterns in every child file.
- Using grep-derived symbol lists for `CODE MAP` when codegraph already provides symbols, callers,
  and blast radius.
- Editing generated files, `.info` descriptions, or any `CLAUDE.md` variant.

## References

- ADR-0007 §4 — project-specific skill bodies live under `tools/ai/skills/<name>/SKILL.md`
  and are readFile-linked by Nix.
- `packages/nix/AGENTS.md` — AI system wiring, generated artifact boundaries, and skill catalog rules.
- Format exemplars: root `AGENTS.md`, `docs/AGENTS.md`, `packages/nix/AGENTS.md`,
  `packages/go/AGENTS.md`, `services/portal/AGENTS.md`, `tools/AGENTS.md`.
