# Handoff audit log

> **Status**: Accepted
> **Authors**: Architect
> **Last reviewed**: 2026-07-05
> **Tracks**: [ADR-0021](../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)

## Problem

ADR-0021 and the agent communication convention require artifact-mediated
hand-offs, but today the most important hand-off payloads still live first as
ephemeral `task` tool arguments and results. A human can inspect them only while
the tool-call UI remains visible, and a later reviewer cannot reliably answer
"what exactly did the orchestrator ask this subagent to do?" from disk.

The current posture model also prevents the obvious manual workaround. The
orchestrator, researcher, and other read-only agents are intentionally denied
shell/edit access, so asking them to persist their own briefs or reports either
fails, spends extra tokens routing cleanup work, or pressures us to weaken their
posture. The runtime already observes every tool call, so mechanical capture in
an opencode plugin can make hand-offs durable without changing agent permissions
or adding prompt burden.

## Goals

- Persist every opencode `task` invocation as a paired brief/report under the
  active worktree's `.sdlc/<task-slug>/handoffs/` directory.
- Capture the exact prompt sent to the subagent, the tool result returned to the
  caller, and enough metadata to correlate them (`callID`, `sessionID`,
  timestamps, target agent, description, caller agent when known).
- Keep the plugin passive: it must not mutate tool arguments, must not block the
  agent loop on capture failure, and must log diagnostics through
  `client.app.log` instead of `console.log`.
- Materialize the local plugin through the Nix/opencode generation path so the
  authored source is versioned and the emitted `.opencode/` artifact remains
  gitignored and reproducible.
- Preserve ADR-0021 boundaries: audit logs are scratch deliberation artifacts,
  not durable project records, and they are deleted with the task's `.sdlc/`
  folder after needed content is re-authored into `docs/` or attached to Linear.

## Non-goals

- No capture of non-`task` tools in phase 1.
- No peer-to-peer agent messaging, shared transcript store, or durable log under
  `docs/`; this spec realizes the ADR-0021 hand-off mechanism, not a new source
  of truth.
- No changes to agent posture, prompt templates, or the Delegation Brief /
  Completion Report convention.
- No network export, telemetry, or upload of prompts/results.
- No phase-1 brief linter. Missing `## Inputs`, missing `## Boundaries`, or
  transcript-only context may be warned on by a later phase via
  `client.app.log`, but this feature only records what the runtime observed.
- No attempt to reconstruct full child-session transcripts unless phase-1 smoke
  testing proves the task tool result is insufficient.

## Background

- [ADR-0021](../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)
  decides that agent communication stays hub-and-spoke and artifact-mediated, and
  that `.sdlc/<task-slug>/` is the worktree-local scratch workspace for
  deliberation.
- The [artifact-mediated communication convention](../conventions/agents/artifact-mediated-communication.md)
  defines `.sdlc/<task-slug>/handoffs/` as the place for Delegation Briefs,
  Completion Reports, and review verdicts across loops; it also defines task-slug
  guidance and delete-at-close behavior.
- `packages/nix/core/ai/opencode/default.nix` currently enables opencode, sets
  `OPENCODE_CONFIG_DIR` to `${config.core.workspace.root}/.opencode`, and passes
  the configured `plugin` list to opencode settings.
- `packages/nix/AGENTS.md` documents the generated-artifact pattern: project AI
  prose is authored under `tools/ai/`, while Nix materializes gitignored
  `.opencode/` artifacts. Project-specific skills use `tools/ai/skills/<name>/SKILL.md`
  as the versioned source (currently `rls-patterns`); generic/reusable skills
  inline the body string directly in their Nix module at
  `packages/nix/core/ai/skills/<name>/default.nix` (currently `git-workflow`,
  `go-pattern`, `init-deep`). In both cases `.opencode/skills/<name>/SKILL.md` is
  the generated runtime artifact.
- Opencode local plugins auto-load from `.opencode/plugins/<name>.ts` or `.js`.
  The documented v1 plugin shape is `export const Foo: Plugin = async (ctx) =>
  ({ ...hooks })`; the plugin init context includes `client`, `project`,
  `directory`, `worktree`, `serverUrl`, Bun's `$`, and
  `experimental_workspace`.
- The v1 hook contract relevant to this feature is:

  ```ts
  "tool.execute.before"?: (input: { tool: string; sessionID: string; callID: string }, output: { args: any }) => Promise<void>
  "tool.execute.after"?:  (input: { tool: string; sessionID: string; callID: string; args: any }, output: { title: string; output: string; metadata: any }) => Promise<void>
  ```

- `callID` is the natural join key between the before/after hooks for one tool
  call. `sessionID` is the parent session for `task` invocations. Task args are
  expected to expose `prompt`, `subagent_type`, and `description`; `task_id` may
  appear for resumed sessions. Exact arg names must be verified during
  implementation.
- `tool.execute.*` hooks do not identify the calling agent. The implementation
  should cache `sessionID -> agent` from the chat/message hook that exposes
  `input.agent`; missing caller identity is recorded as `unknown`.
- Hooks are awaited, have full Bun/Node filesystem access, and can mutate args or
  block calls if they throw from `tool.execute.before`. This feature must do
  neither.
- The forward-looking Effect-based v2 plugin API is unstable, so this spec targets
  the documented v1 hook system.

## Design

### Source, packaging, and enablement

Author the plugin source in the repository under:

```text
tools/ai/plugins/handoff-audit-log/
└── index.ts
```

Nix materializes that source into the opencode config directory as:

```text
.opencode/plugins/handoff-audit-log.ts
```

The emitted `.opencode/` file is generated and gitignored; the `tools/ai/`
source is the reviewable project artifact. This mirrors the AI skill-body pattern
from ADR-0007 and `packages/nix/AGENTS.md`: Nix owns the runtime link/copy, not
the authored TypeScript.

Add a gated opencode option for the plugin, exposed as:

```nix
core.ai.opencode.plugins.handoff-audit-log.enable
```

The option is effective only when `core.ai.opencode.enable = true`. The workspace
root should enable it by default so ADR-0021 hand-offs are mechanically captured;
consumers may disable it only for an explicit local/runtime incompatibility.

### Hook flow

The plugin registers `tool.execute.before` and `tool.execute.after`, and ignores
every tool except `task`.

Before hook behavior:

1. Return immediately unless `input.tool === "task"`.
2. Clone the observed args without mutating `output.args`.
3. Resolve the task slug and handoff directory.
4. Allocate the next sequence number for this handoff.
5. Write `NN-brief-<agent>.md` with metadata and the exact observed prompt.
6. Cache `callID -> { sequence, agent, paths, beforeTimestamp, argsSnapshot }` in
   memory so the after hook can write the paired report.

After hook behavior:

1. Return immediately unless `input.tool === "task"`.
2. Look up the pending before-hook record by `callID`.
3. Write `NN-report-<agent>.md` with metadata, `output.title`, `output.output`,
   and JSON-serialized `output.metadata`.
4. If the before record is missing, still write a report using the observed
   `input.args`, a newly allocated sequence, and a metadata note that the brief
   was not captured.

Both hooks are wrapped in `try/catch`. Any exception is logged with
`client.app.log({ body: { service: "handoff-audit-log", level: "warn" | "error",
message, extra } })` and swallowed. Log metadata should include paths, call IDs,
and error names, but not full prompt/report bodies.

### Task slug inference

Resolve the scratch root relative to the opencode init context:

- Prefer `worktree` when provided; it is the Git worktree root.
- Fall back to `directory` only when `worktree` is absent.

Resolve `<task-slug>` in this order:

1. If the active Git branch is a work branch, slugify that branch by replacing
   `/` with `-` and replacing other unsafe filename characters with `-`.
2. If the worktree path is under `.worktrees/`, use the worktree directory name.
3. If the session is running in the main checkout on `main`, on a protected
   branch, or in a detached/non-Git state, use `session-<short-sessionID>`.

This keeps branch/worktree sessions grouped by recognizable work item while
preventing unrelated main-checkout dogfood sessions from piling into
`.sdlc/main/`. Slug uniqueness is not a concurrency mechanism; isolation still
comes from the convention's one-interactive-session-per-checkout model.

### Handoff file layout and sequencing

The plugin writes only under:

```text
.sdlc/<task-slug>/handoffs/
├── NN-brief-<agent>.md
└── NN-report-<agent>.md
```

`<agent>` comes from `args.subagent_type`, sanitized for filenames. If missing,
use `unknown-agent` and record the missing field in metadata.

`NN` is a monotonically increasing sequence per handoff directory, zero-padded to
at least two digits (`01`, `02`, ..., `100`). On startup or first write, initialize
the counter from the highest existing `NN-` prefix in the directory. Use an
in-process async queue/mutex for sequence allocation so parallel `task` calls in
one opencode process cannot receive the same number.

Each `task` tool invocation receives a new `NN`, including resumed `task_id`
iterations. Do not append to an earlier brief/report pair: a rework or re-review
call is a new hand-off event, and the previous pair remains an immutable scratch
record for the loop.

### Brief file format

The brief file is Markdown. It includes:

- `callID`
- parent `sessionID`
- cached caller agent, or `unknown`
- target `subagent_type`, or `unknown-agent`
- `description`, or empty
- `task_id` when present
- `captured_at` timestamp
- `task_slug`
- `directory` and `worktree` from plugin init context
- a JSON snapshot of non-prompt task args
- the exact observed `prompt`

The prompt body must be rendered without losing bytes. The implementation should
choose a Markdown fence delimiter that does not occur in the payload; if it
cannot, it should write the prompt as JSON string content instead of truncating or
normalizing it.

### Report file format

The report file is Markdown. It includes:

- the same correlation metadata as the brief (`callID`, parent `sessionID`,
  target agent, `task_id` when present, `NN`)
- `completed_at` timestamp
- link to the paired brief path
- `output.title`
- `output.output` exactly as provided by the task tool
- JSON-serialized `output.metadata`

Phase 1 records `output.output` as-is. If smoke testing shows that the task tool
returns only a summarized result rather than the full subagent Completion Report,
the follow-up design may fetch the child session messages through the opencode
SDK; this spec does not require that extra read.

### Caller-agent cache

Register the chat/message hook that exposes `input.agent` and cache
`sessionID -> agent` in memory. Tool hooks do not include caller identity, so the
cache is best-effort. Missing cache entries must not fail capture; the files
record `caller_agent: unknown`.

### Failure and safety posture

- The plugin never throws from its hooks.
- The plugin never mutates `output.args` or `input.args`.
- Capture failures are visible through `client.app.log`, not through blocked tool
  calls.
- File I/O is limited to creating `.sdlc/<task-slug>/handoffs/` and writing the
  two Markdown files for `task` calls.
- Diagnostics never include full prompt or report bodies.
- Existing files are not overwritten. If a collision is detected, allocate a new
  sequence or write a `-duplicate-<shortCallID>` suffix and log a warning.
- If `tool.execute.after` does not fire because a subagent crashes, the brief file
  remains as evidence of the attempted hand-off; no synthetic success report is
  created.

## Alternatives considered

- **Manual `.sdlc/` writes by the orchestrator or subagents.** Rejected because
  read-only agents intentionally cannot write files, and adding a manual write
  instruction to every brief/report increases token cost while still being easy
  to forget.
- **Capture all tool calls.** Rejected for phase 1 because ADR-0021's enforcement
  gap is specifically delegated hand-offs; capturing reads, greps, shell output,
  or edits would add noise and increase the chance of preserving sensitive local
  material.
- **Store hand-off logs under `docs/`.** Rejected because the logs are
  deliberation artifacts. Durable records must be authored in their proper tracks;
  scratch promotion remains re-authoring, not moving audit files.
- **Block malformed briefs in `tool.execute.before`.** Rejected for phase 1
  because throwing in the before hook blocks the tool call. The audit log must be
  passive first; warning-only lint can be added later once capture is proven.
- **Use an opencode transcript/session export as the audit record.** Rejected
  because ADR-0021 deliberately avoids shared transcript stores and requires
  artifact-shaped hand-offs that can be cited by disk path.
- **Target the unstable v2 Effect plugin API now.** Rejected because the documented
  v1 hook system is available today and matches the needed passive interception
  model.

## Open questions

- Verify the exact `task` arg schema in the current opencode version, especially
  `prompt`, `subagent_type`, `description`, and resumed-session `task_id`.
- Verify whether `output.output` is the full subagent Completion Report or a
  summarized task result. If summarized, decide whether a follow-up should call
  `client.session.messages()` for the child session.
- Verify whether `tool.execute.after` fires when the subagent crashes or is
  cancelled; the design tolerates a missing report, but implementation evidence
  should document the behavior.
- Inspect `output.metadata` for task calls and decide whether any fields deserve
  first-class rendering beyond JSON capture.
- Confirm the correct chat/message hook name and payload for `sessionID -> agent`
  caching in the opencode version pinned by the workspace.
- Confirm hook ordering when multiple plugins observe or mutate task args; this
  plugin records what its hook sees and must remain passive regardless of order.

## Implementation plan

- [ ] **Dev-Environment:** Add `tools/ai/plugins/handoff-audit-log/index.ts` with
  pure helpers for slug inference, filename sanitization, sequence allocation,
  Markdown fence selection, metadata rendering, and safe app logging.
- [ ] **Dev-Environment:** Add the opencode/Nix module surface for
  `core.ai.opencode.plugins.handoff-audit-log.enable`, import it from the
  opencode module tree, and materialize the authored TypeScript into
  `.opencode/plugins/handoff-audit-log.ts` when enabled.
- [ ] **Dev-Environment:** Enable the plugin for the root opencode config and
  regenerate; verify the generated `.opencode/plugins/handoff-audit-log.ts` is
  present and gitignored.
- [ ] **Dev-Environment:** Smoke-test a successful `task` delegation and show the
  resulting `NN-brief-<agent>.md` and `NN-report-<agent>.md` under
  `.sdlc/<task-slug>/handoffs/` with matching `callID`/`sessionID`.
- [ ] **Dev-Environment:** Smoke-test failure posture by forcing a write/logging
  error in a controlled way and proving the task call is not blocked.
- [ ] **Architect:** Review the implementation against this spec and the
  artifact-mediated communication convention, including phase-1 non-goals.
- [ ] **Security reviewer:** Confirm only `task` payloads are captured, prompt and
  report bodies are not duplicated into `client.app.log`, and all writes stay
  under gitignored `.sdlc/<task-slug>/handoffs/`.
- [ ] **Scribe:** After the feature is accepted or implemented, update any living
  workflow notes only by linking to this spec/convention; do not restate the hook
  contract in wiki pages.

## References

- [ADR-0021: Artifact-mediated agent communication and the `.sdlc/` scratch workspace](../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)
- [Artifact-mediated communication convention](../conventions/agents/artifact-mediated-communication.md)
- [ADR-0007: Manage the developer environment with Nix + devenv](../adrs/0007-nix-devenv-developer-environment.md)
- [`packages/nix/core/ai/opencode/default.nix`](../../packages/nix/core/ai/opencode/default.nix)
- [`packages/nix/AGENTS.md`](../../packages/nix/AGENTS.md)
- [Opencode plugin documentation](https://opencode.ai/docs/plugins)
