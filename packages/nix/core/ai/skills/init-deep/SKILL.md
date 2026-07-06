---
name: init-deep
description: Deep, codegraph-driven regeneration of this workspace's hierarchical AGENTS.md knowledge base — root plus scored subdirectory files. Use when bootstrapping AGENTS.md for a new area or refreshing it after the architecture shifts.
user-invocable: true
allowed-tools: Read, Grep, Glob, Task, TodoWrite, mcp__codegraph__codegraph_explore
---

# Init Deep

Regenerate this repo's durable agent memory: one root `AGENTS.md` always refreshed,
plus only the subdirectory `AGENTS.md` files that **earn their placement**. This
is the deep alternative to `/init`: multi-pass, parallel, codegraph-led, and
opinionated about this workspace's Nix/devenv + Go monorepo shape.

## When this applies

- Bootstrapping `AGENTS.md` for a new package, service, docs tree, or tooling area.
- Refreshing the hierarchy after architecture, module boundaries, or commands shift.
- Re-scoring which directories deserve local guidance instead of root-only notes.
- Auditing existing `AGENTS.md` files for drift, duplication, stale commands, or stale code maps.

## Operating model

- Track every phase with `TodoWrite`; keep the user informed at phase boundaries.
- You are the orchestrator: drive discovery, scoring, and review; delegate actual file
  writes to an engineer. No writes are delegated until the Phase 2 dry-run gate passes.
- The delegated writing engineer holds `Write`/`Edit`/`bash`; the orchestrator does not.
- Prefer `Edit` for existing `AGENTS.md` files and preserve still-true content; use
  `Write` only for brand-new files approved by the dry-run gate.
- Never run broad regeneration blindly. First read every existing `AGENTS.md` and decide
  what remains true.
- Trust `codegraph_explore` for symbols, call paths, and blast radius. Do not re-grep the
  CODE MAP or copy codegraph output wholesale into child files.
- One overriding constraint: **AGENTS.md files point; they never duplicate what ws-tree,
  codegraph, READMEs/runbooks, docs tracks, or parent AGENTS.md already provide.**

## Phase 1 — discovery (parallel, read-only)

Fan out read-only discovery in parallel. Scale the number of explorer-agent tasks with
repo size: more files, lines, depth, modules, or services means more parallel probes.

- Read all existing `AGENTS.md` files first: root, `docs/`, `packages/nix/`,
  `packages/go/`, `services/portal/`, `tools/`, and any service/package/app-local files.
- Run `codegraph_explore` concurrently for structure, entry points, key symbols, call
  paths, reference centrality, and blast radius. Codegraph is the mandated code-map engine.
- Cover repo layout, apps, Go modules, Nix/devenv modules, commands, build/test/lint flows,
  docs ownership, service boundaries, and generated artifacts.
- Discover candidate directories for subdirectory `AGENTS.md` files plus stale facts in
  existing ones. Mark stale facts for removal rather than rewriting from scratch.
- Exclude generated, vendor, build, cache, and local-agent trees from all scoring and
  candidate lists: `.git`, `.devenv`, `.docusaurus`, `build/`, `node_modules`,
  `.opencode`, `.claude`, `.codegraph`, `.info`.

## Phase 2 — placement decision + dry-run gate

Each candidate directory `D` is scored on **residual** surface (subtract child subtrees
that already have or are approved to get their own `AGENTS.md`). Root is always refreshed
— never scored.

| Signal | Score |
|---|---:|
| S1: non-generated residual files > 20 | +1 |
| S2: residual subdirs > 5, or max residual depth > 2 | +1 |
| S3: hard boundary — Go module root, Nix module root, service root, app root with own `devenv.nix`, or deployment root with own `devenv.nix`/`devenv.yaml` | +2 |
| S4: durable unique conventions/gotchas not appropriate for parent/root | +2 |
| S5: codegraph exported-symbol/reference density > 10 | +1 |

| Score | Missing file | Existing file |
|---:|---|---|
| ≥4 | CREATE | REFRESH / KEEP |
| 2–3 | DEFER (watch list, no file) | DEFER-WATCH; refresh only if content passes contract, else propose MERGE-UP |
| 1 | no file; merge useful facts upward | MERGE-UP |
| 0 | no file | RETIRE |

**Overrides** (demote to no-file / MERGE-UP / RETIRE regardless of score):

- Content is fully derivable from filenames, tree shape, or codegraph.
- Content is mainly a procedure or runbook → belongs in a README or skill.
- Content is only navigation → belongs in `ws-tree`/`treeInfos` or parent `WHERE TO LOOK`.
- Directory is a container whose meaningful children have their own approved `AGENTS.md`.
- Content duplicates parent, sibling, or `docs/` conventions.

**Dry-run gate** (end of Phase 2, before any writes): present a table:

```text
Directory | Existing? | S1..S5 | Score | Override? | Verdict | Action | Notes
```

Explicit user approval is required for every CREATE / MERGE-UP / RETIRE. MERGE-UP and
RETIRE are destructive — never delegate them without approval. Only after the gate passes
do you proceed to Phase 3 and delegated writes.

## Phase 3 — content contract

**Root** (order): visible header (`Generated`+`Commit`+`Branch`, gathered fresh by
the writing engineer from `date -uIseconds`, `git rev-parse --short HEAD`, current
branch) → OVERVIEW → STRUCTURE → WHERE TO LOOK → CODE MAP (root-only, codegraph-derived,
skip if <10 non-generated files) → CONVENTIONS → ANTI-PATTERNS (THIS PROJECT) →
UNIQUE STYLES (optional) → COMMANDS → NOTES. Budget: soft 50–150 lines, hard cap 200.

**Subdirectory**: required `# <relative-path>/` H1 + one-line OVERVIEW that is a
**delta** over the parent (not a paraphrase). Optional sections that pass the
earns-its-place tests: STRUCTURE (only >5 local subdirs lacking own `AGENTS.md`, or
non-obvious shape), WHERE TO LOOK (local dispatch only), CONVENTIONS (only if different
from parent), ANTI-PATTERNS (local only), GOVERNANCE (e.g. `packages/go/`), COMMANDS
(local-only), NOTES (durable exceptions). Forbidden in child files: CODE MAP; repeated
parent anti-patterns; full ws-tree mirrors; runbook procedures owned by a README.
Budget: soft 30–80 lines, hard cap 100.

**Earns-its-place** — drop a line, row, or section if ANY of these is true:

1. An agent gets it right from normal language or framework knowledge.
2. It duplicates parent, sibling, README, or `docs/` conventions.
3. It is a procedure or runbook → move or link to README or a skill.
4. It is discoverable via filenames, codegraph, or `ws-tree`.
5. It contradicts another source → fix the canonical source; don't keep both.
6. It describes code older than the header Commit and touched since, without re-verification.
7. It is a bare folder description → `treeInfos` owns that.
8. It is task-specific or temporary → issue, spec, debt, or finding.

**Staleness procedure** (before reusing existing content): parse root `Commit` header
(missing/unreachable ⇒ whole hierarchy stale). The writing engineer checks commits since
header Commit touching described paths; re-verifies CODE MAP + referenced symbols via
codegraph; verifies listed commands run in the owning devenv; re-scores placement when:
a new `go.mod`/`package.json`/`devenv.nix`/`devenv.yaml` appears; a directory crosses
S1 or S2 thresholds; an existing file re-scores <2; local rules have moved to root or
`docs/` conventions. Every stale fact is refreshed, linked to its canonical source, or
dropped.

## Phase 4 — generate via delegated writes

- Delegate only the actions approved in the dry-run gate.
- The writing engineer gathers header values fresh at write time (orchestrator has
  `bash = deny`); never copy stale values from the previous file.
- `Edit` existing files — refresh stale sections, drop passed earns-its-place tests,
  preserve still-true content. Never wholesale-replace an existing `AGENTS.md`.
- `Write` only new files approved as CREATE.
- Use existing files as format exemplars. Keep prose telegraphic, high-signal, and
  repo-specific.

## Phase 5 — review, deduplicate, verify

**TOC ownership — single rule: point, don't duplicate.**

| Mechanism | Owns | AGENTS.md rule |
|---|---|---|
| `ws-tree` + `.info`/`treeInfos` | filesystem existence + dir purpose | never mirror full tree or folder descriptions |
| STRUCTURE | condensed logical shape agent holds in context | root default; subdir only for complex local shape |
| WHERE TO LOOK | task → location dispatch | root owns workspace-wide rows; child owns strictly local rows |
| README / runbook | operational procedures | link, never copy steps |
| docs tracks | durable policy/lifecycle/decisions/specs | link to canonical docs |
| markdown links / imports | progressive disclosure | point to source; no prose copying |
| codegraph | symbols, call paths, blast radius | root CODE MAP summary only |

**Dedup pass**: compare each child section vs nearest parent `AGENTS.md`, siblings,
READMEs, and `ws-tree`/`treeInfos`. At ≥70% overlap → trim to pointer or propose
MERGE-UP. If overlap removal eliminates the only local delta, re-open the placement
verdict (approval required before retiring or merging).

**Final verification**: confirm all commands run in their owning devenv; verify module
paths against `go.work`/`go.mod`; cross-check CODE MAP symbols against codegraph; audit
section order, line budgets, and table shapes.

## Guardrails for this workspace

- `AGENTS.md` is authored by init-deep. These are generated and off-limits:
  `.pre-commit-config.yaml`, `.golangci.yml`, `.editorconfig`, `go.work`, every
  `.info` file, `.claude/*`, `.opencode/*`, and `CLAUDE.md`.
- `CLAUDE.md` is Nix-generated as `@AGENTS.md`; never edit it and do not create or
  symlink per-directory `CLAUDE.md` files.
- Folder descriptions are not free text. They live in `core.workspace.treeInfos` in the
  owning `devenv.nix` and render into `.info`. Init-deep documents structure in
  `AGENTS.md`; it does not seed `.gitkeep` or edit `.info`.
- Respect service ownership. Root files cover workspace-wide rules;
  `services/<name>/AGENTS.md` and `services/<name>/docs/` cover service-local rules.
  The docs model is two-tier: workspace-wide in root `docs/`; service-owned under
  `services/<name>/docs/`. Per the architect ruling, this workspace tracks knowledge in
seven formal tracks (adrs, conventions, debt, findings, glossary, prds, specs) plus
`wiki/` for informal content (including architecture views per ADR-0020).
- Check existence before edits. Existing `AGENTS.md` → `Edit`/refresh; missing
  `AGENTS.md` → `Write` only if approved as CREATE in the dry-run gate.
- Do not touch other skills, agent prompts, generated opencode/Claude artifacts, or Nix
  module imports as part of an init-deep run.

## Anti-patterns

- Running init-deep as a single pass or a single-agent read of the tree.
- Replacing existing `AGENTS.md` content wholesale without preserving still-true facts.
- Creating child files because a directory exists rather than because the scoring
  heuristic justifies it.
- Creating `AGENTS.md` for procedure-only README areas.
- Repeating the root anti-patterns in every child file.
- Using grep-derived symbol lists for `CODE MAP` when codegraph already provides
  symbols, callers, and blast radius.
- Copying codegraph output wholesale into child files (CODE MAP is root-only).
- Duplicating `ws-tree` output in STRUCTURE trees.
- Editing generated files, `.info` descriptions, or any `CLAUDE.md` variant.

## References

- ADR-0007 §4 — Nix owns generated AI skill artifacts; skill prose remains source-controlled markdown/readFile content.
- `packages/nix/AGENTS.md` — current skill-body authoring convention for generic sibling `SKILL.md` files and project-specific `tools/ai/skills/<name>/SKILL.md` files.
- Format exemplars: root `AGENTS.md`, `docs/AGENTS.md`, `packages/nix/AGENTS.md`,
  `packages/go/AGENTS.md`, `services/portal/AGENTS.md`, `tools/AGENTS.md`.
