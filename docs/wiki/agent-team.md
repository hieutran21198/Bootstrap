# Agent Team — Quick Reference

> Informal quick-reference (outside the 8 formal `docs/` tracks). The machine
> source of truth is the agent modules in
> [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/) (identity,
> posture, prompt) plus the per-capability `agents` allow-lists in
> [`packages/nix/core/ai/mcps/`](../../packages/nix/core/ai/mcps/) and
> [`.../skills/`](../../packages/nix/core/ai/skills/). The renderer in
> [`ai/default.nix`](../../packages/nix/core/ai/default.nix) turns those into
> `.opencode/agents/*.md`. Keep this table in sync with them.

The workspace runs one **primary** agent (the orchestrator) plus seven
**subagents**. The orchestrator does not bulk-implement inline — it decomposes a
goal, routes each slice to the right subagent via a **Delegation Brief**, keeps
the plan/decision index, and enforces `writer ≠ reviewer`. See
[`docs/debt/agent-orchestration-no-delegation.md`](../debt/agent-orchestration-no-delegation.md).

## How wiring works

- **Posture** (agent-owned): each agent declares its intrinsic built-in-tool
  baseline. `explorer`/`researcher` are read-only (`edit`/`bash` denied);
  engineers are read-write; the orchestrator has `edit`/`bash` denied and `task`
  allowed to force delegation.
- **Skills & MCPs** (capability-owned): each skill/MCP module declares an
  `agents` allow-list (default in the module, overridable in `devenv.nix`). The
  renderer grants the capability to those agents and **denies it to every other
  agent** (default-deny) as an opencode `permission` entry. Nothing is hardcoded
  on the agent side.
- **Plugin skills** (`ce-*`, `context7-mcp`) come from the compound-engineering
  plugin, are globally available, and are not gated by this wiring.

## When to use which agent

| Role                       | Use Case                                                                                                                                        | Success Criteria                                                                                                                                                                                     | Wired tools (posture)                    | Wired skills                           |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | -------------------------------------- |
| **orchestrator** (primary) | Default entry point for any multi-step or multi-lane goal; planning, routing, and the review gate                                               | Every non-trivial slice delegated (not inline); self-contained briefs; final summary carries raw `go test` / `lint-go` proof; `writer ≠ reviewer` honored                                            | codegraph, `task` (`edit`/`bash` denied) | —                                      |
| **researcher**             | External / library / domain knowledge, option evaluation, upstream docs, impact analysis — read-only                                            | Completion Report with sourced findings + an explicit recommendation; claims cited; no code changes                                                                                                  | context7, gh_grep (read-only + web)      | —                                      |
| **explorer**               | "Where / how does X work" in _this_ repo; find files/symbols, trace call paths, survey an area — read-only                                      | Exact `file:line` locations + call paths + a concise map; no edits                                                                                                                                   | codegraph (read-only)                    | —                                      |
| **architect**              | Design decisions and tradeoffs; produce/validate ADRs & specs; define boundaries; independent review (`writer ≠ reviewer`)                      | Output matches the relevant `docs/` track format, or a review verdict with concrete findings; decisions → `adrs/`, designs → `specs/`, views → `architecture/`                                       | codegraph (edit docs, no bash)           | —                                      |
| **backend-engineer**       | Implement/refactor Go in `packages/go`, `services/portal`, `tools`; repos, migrations, echox, DB/RLS                                            | Follows Go conventions + SRP; `lint-go` + `go test` pass (raw output); RLS honored                                                                                                                   | codegraph (edit + bash)                  | go-pattern, rls-patterns, git-workflow |
| **frontend-engineer**      | Implement/refactor `apps/` UI; browser-verified polish (_`apps/workspace-docs/` is a real Docusaurus site; UI-heavy app work is still thin_)    | UI builds & renders; playwright QA passes; matches design; tests green                                                                                                                               | codegraph, playwright (edit + bash)      | git-workflow                           |
| **release-engineer**       | CI/CD + release coordination: GitHub Actions, git-hook/branch-protection wiring (calls git-guard), versioning/tagging/changelog, deploy/ config | CI green; hooks + branch protection enforce ADR-0012 via git-guard (no duplicated rules); release/CI commands return raw proof; no product/architecture/release-authority decision made unilaterally | codegraph (edit + bash)                  | git-workflow                           |
| **scribe**                 | Break PRDs/epics into tracked work items; maintain roadmap, debt register, and status; sync issues; write/triage tickets and status reports     | Work items w/ acceptance criteria + owners; `docs/` trackers updated; reconciles plan vs. done; no code or design                                                                                    | jira¹ (edit docs, no bash)               | git-workflow                           |

¹`jira` is wired to `scribe` but its MCP server is disabled by default
(`core.ai.mcps.jira.enable = false`); it only appears once enabled.

## Agent posture (built-in tools)

Posture is the agent-owned safety baseline over opencode's built-in tools,
declared as `core.ai.agents.<name>.posture` and emitted into each agent's
`permission` frontmatter. MCP and skill permissions (the table above) are layered
on top by the renderer.

| Agent                      | `edit` | `bash` | `task` | `webfetch` / `websearch` |
| -------------------------- | ------ | ------ | ------ | ------------------------ |
| **orchestrator** (primary) | deny   | deny   | allow  | allow                    |
| **researcher**             | deny   | deny   | —      | allow                    |
| **explorer**               | deny   | deny   | —      | —                        |
| **architect**              | allow  | deny   | —      | —                        |
| **backend-engineer**       | allow  | allow  | —      | —                        |
| **frontend-engineer**      | allow  | allow  | —      | —                        |
| **release-engineer**       | allow  | allow  | —      | —                        |
| **scribe**                 | allow  | deny   | —      | —                        |

- `—` = not declared, so the agent inherits opencode's default. Unset built-ins
  (`read`, `glob`, `grep`, `list`, and by default `webfetch`/`websearch`) stay
  **allowed** — every agent can read and search.
- Read-only agents (`explorer`, `researcher`) and the `orchestrator` deny `edit`
  and `bash`; the orchestrator additionally allows `task` (to delegate) — which
  is what stops it from implementing inline.
- `architect` and `scribe` may `edit` (they author docs/records) but not run
  `bash`; only the engineers get `bash`.

## Notes

- **`frontend-engineer` is thin**: `apps/workspace-docs/` is now a real,
  populated Docusaurus docs site, but UI-heavy app work is still minimal, so
  this lane has little to work on yet.
- The Tools/Skills columns mirror the wiring; the authoritative lists are the
  `agents` defaults in each capability module (overridable in `devenv.nix`). A
  future `tools/generators/` renderer could emit this table directly from
  `core.ai.agents` + the capability allow-lists.

## References

- Agent modules (identity / posture): [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/)
- Per-agent instructions: `PROMPT.md` beside each agent module in [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/) (default for the overridable `instructions` option)
- Capability wiring: [`.../mcps/`](../../packages/nix/core/ai/mcps/) · [`.../skills/`](../../packages/nix/core/ai/skills/) (each module's `agents` allow-list)
- Renderer (permission + default-deny + `<tools>`): [`packages/nix/core/ai/default.nix`](../../packages/nix/core/ai/default.nix)
- Delegation debt / protocol rationale: [`docs/debt/agent-orchestration-no-delegation.md`](../debt/agent-orchestration-no-delegation.md)
