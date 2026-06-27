# Claude Code v2.1.187 agent configuration model

> **Status**: Resolved
> **Authors**: Minh Hieu Tran <hieu.tran21198@gmail.com>
> **Investigated**: 2026-06-26
> **Tracks**: —

## Symptom

The workspace renders Claude Code agents from Nix (`packages/nix/core/ai/agents/*`),
but the custom `coder` / `explorer` / `spec-writer` modules were deprecated in favour
of v2.1.187 built-ins and Agent Teams without a written record of _what the upstream
agent configuration model actually is_. The question this finding answers: in Claude
Code **v2.1.187**, what agents ship built-in, where are custom agents defined, and how
are tools and skills assigned per-agent?

## Reproduction

```text
Research task: read code.claude.com/docs/en/sub-agents.md, skills.md, commands.md,
and the v2.1.187 changelog; cross-check against the generated agent frontmatter in
packages/nix/core/ai/agents/*/default.nix.
```

## Hypotheses considered

- **H1: Skills are gated by the same mechanism as tools.** Disproved — skills and tools
  are two _independent_ gates. `skills:` preloads content; the `Skill` tool grants
  on-demand invocation. Either, both, or neither can apply.
- **H2: Subagents inherit the parent conversation's skills.** Disproved by the docs —
  subagents do **not** inherit skills automatically; they must be preloaded via `skills:`
  or discovered through the `Skill` tool.
- **H3: There is a per-agent skill allowlist.** Disproved — v2.1.187 has no skill
  allowlist field. You preload specific skills (`skills:`) and/or open the whole catalog
  (`Skill` in `tools`); the only way to scope down is to omit `Skill`.

## Investigation

Sources: `code.claude.com/docs/en/sub-agents.md`, `.../skills.md`, `.../commands.md`,
`.../changelog.md` (v2.1.187, 2026-06-23), fetched 2026-06-26. Cross-referenced against
`packages/nix/core/ai/agents/coder/default.nix:189` and
`packages/nix/core/ai/agents/explorer/default.nix:180` (the `claudeAgent` renderers).

### Built-in agents (v2.1.187)

| Agent               | Model   | Tools                           | Role                                               |
| ------------------- | ------- | ------------------------------- | -------------------------------------------------- |
| `claude`            | inherit | `*`                             | Catch-all default                                  |
| `general-purpose`   | inherit | `*`                             | Multi-step research + action                       |
| `Explore`           | haiku   | read-only                       | Fast codebase search; skips CLAUDE.md + git status |
| `Plan`              | inherit | read-only                       | Plan-mode research                                 |
| `statusline-setup`  | sonnet  | Read, Edit                      | Statusline config                                  |
| `claude-code-guide` | haiku   | Bash, Read, WebFetch, WebSearch | Answers Claude Code questions                      |

Disable a built-in via `permissions.deny` with `Agent(<name>)` (e.g. `Agent(Explore)`).
Deny the bare `Agent` tool to block all delegation. SDK/headless:
`CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1`.

### Defining custom agents — locations & precedence

Markdown + YAML frontmatter, one agent per file. Highest precedence first:

1. Managed/enterprise settings
2. `--agents '{...}'` CLI flag (session-only JSON; body field is `prompt`, not markdown)
3. `.claude/agents/` — project, version-controlled
4. `~/.claude/agents/` — personal, all projects
5. Plugin `agents/` directory

Discovered **recursively** (subfolders allowed). On a name collision in nested project
dirs, the definition **closest to cwd wins** (v2.1.178+). On-disk edits need a session
restart; agents created via `/agents` apply immediately.

### Frontmatter fields (2.1.187)

`name` + `description` required; all else optional.

| Field                                                                   | Notes                                                                               |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `tools`                                                                 | Allowlist (comma list or YAML list). Omit → inherits all parent tools               |
| `disallowedTools`                                                       | Denylist, applied **before** `tools` resolves                                       |
| `model`                                                                 | `sonnet`/`opus`/`haiku`/`fable` / full id (`claude-opus-4-8`) / `inherit` (default) |
| `skills`                                                                | Preload full skill content into context at startup (does NOT gate access)           |
| `permissionMode`                                                        | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan`                 |
| `maxTurns`, `effort` (`low`→`max`), `background`, `isolation: worktree` | execution controls                                                                  |
| `memory`                                                                | `user`/`project`/`local` — cross-session memory                                     |
| `mcpServers`, `hooks`                                                   | per-agent (ignored for _plugin_ agents)                                             |
| `color`, `initialPrompt`                                                | display / main-thread bootstrap                                                     |

### Assigning tools

- Omitted `tools` → inherits the full parent toolset.
- MCP patterns: `mcp__<server>`, `mcp__<server>__*`, and `mcp__*` (denylist only).
- Restrict sub-spawning (when the agent is the main thread): `tools: Agent(worker, researcher)`.
  Bare `Agent` = spawn anything; omit `Agent` = no spawning. `Task` is the pre-2.1.63 alias.

### Assigning skills — the two-gate model

Skills and the `tools` list are **independent gates**:

- **`skills:` frontmatter** — injects _full skill content_ at startup (preload). Does not gate access.
- **`Skill` in `tools`** — lets the agent discover and invoke any project/user/plugin skill
  on demand. Without `Skill` in `tools` (or with it in `disallowedTools`), the agent
  **cannot invoke any skill**.
- Subagents do **not** inherit skills from the parent.
- No per-agent skill allowlist exists; scope down only by omitting `Skill`.

```yaml
---
name: api-developer
tools: Read, Edit, Grep, Skill # can invoke any skill on demand
skills: [api-conventions, error-handling-patterns] # these two preloaded
---
```

### `/agents` command

Tabbed UI — **Running** (live/recent agents, stop them) and **Library** (browse
built-in/user/project/plugin, "Generate with Claude", edit, pick tools/model/color/memory,
delete). Created agents are live immediately.

## Root cause

Not a defect — a knowledge gap. The native Claude Code v2.1.187 agent schema is richer
than the workspace renderer emits, and that mismatch was undocumented. Three concrete
gaps in `packages/nix/core/ai/agents/*/default.nix`:

1. **No `skills` field emitted**, and `Skill` is absent from `baseTools` in both `coder`
   and `explorer` — generated agents cannot invoke or preload skills at all.
2. **`model` enum is `opus|sonnet|haiku` only** — cannot express `inherit`, `fable`, or
   full model ids, which is _why_ the built-ins (all `inherit`/specific) could not be
   reproduced and the modules were deprecated rather than ported.
3. **`proactive = true`** is a devenv/opencode integration concept — native Claude Code
   has no `proactive` frontmatter field; proactive delegation is driven by `description`.

Note: the `claude.agents` schema referenced in
[packages/nix/AGENTS.md](../../packages/nix/AGENTS.md) anti-patterns is the **devenv
integration** submodule (`src/modules/integrations/claude.nix`), which is a renderer one
layer above this native schema — whether it exposes `skills`/`disallowedTools`/free-form
`model` must be verified against that upstream module before relying on it.

## Resolution

- This finding — the written reference for the v2.1.187 agent configuration model.
- Custom `coder`/`explorer`/`spec-writer` modules remain deprecated and disabled
  (superseded by `general-purpose · inherit`, `Explore · haiku`, and Agent Teams); no
  code change required for the migration itself.
- **Open follow-up (no change shipped here):** if custom Nix-rendered agents are revived,
  extend the `claude.agents` submodule to emit `skills` and a free-form `model`, and add
  `Skill` to `baseTools` — but first verify the devenv integration module accepts those
  fields.

## References

- https://code.claude.com/docs/en/sub-agents.md
- https://code.claude.com/docs/en/skills.md
- https://code.claude.com/docs/en/commands.md
- https://code.claude.com/docs/en/changelog.md (v2.1.187, 2026-06-23)
- https://code.claude.com/docs/en/agent-teams (migration target)
- `packages/nix/core/ai/agents/coder/default.nix`, `.../explorer/default.nix` (renderers + deprecation headers)
