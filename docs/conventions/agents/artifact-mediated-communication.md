# Artifact-mediated communication

> **Scope**: every AI-agent delegation, completion report, technical review verdict, and `.sdlc/` scratch artifact in this workspace.
> **Status**: Active
> **Decided by**: [ADR-0021](../../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)
> **Last reviewed**: 2026-07-05

**Rule.** Exchange agent context only through orchestrator-routed Delegation Briefs, Completion Reports, review verdicts, Linear updates, and disk paths to `docs/`, code, or `.sdlc/<task-slug>/`; never rely on peer-to-peer messages, shared transcripts, or paraphrased prior-agent findings.

**Rationale.** Subagents start with fresh context, cannot inspect sibling sessions, and leave transcripts that are not a durable project record. That isolation is useful: it forces each agent to externalize what another role needs to inspect, lets the orchestrator preserve `writer ≠ reviewer`, and keeps the human-facing audit trail out of hidden chat state. The `.sdlc/` scratch workspace gives active work a place for deliberation that is more durable than a transcript but less permanent than `docs/`. The boundary matters: a scratch note can feed a PRD, spec, ADR, finding, debt item, wiki page, Linear comment, or PR, but the durable record must be authored in its own track format and lifecycle.

**Apply.**

- **Route through the orchestrator.** Agents do not create side-channel agreements with sibling agents. The orchestrator owns the index of who did what, which disk artifacts are authoritative inputs, which task IDs are resumed, and which durable records or Linear issues must be updated.
- **Use disk-path inputs, not transcript summaries.** Every Delegation Brief includes an `Inputs:` field containing only disk paths: files in `docs/`, code paths, or files under `.sdlc/<task-slug>/`. Do not write "as the researcher found" unless the sentence points at the file that contains the research.
- **Use `.sdlc/<task-slug>/` for deliberation only.** Create one worktree-local scratch folder per work item, preferably using the Linear key, branch slug, or short capability slug; keep `.sdlc/` local-only and gitignored. Recommended layout:
  ```text
  .sdlc/<task-slug>/
  ├── README.md       # optional task index: owner, docs/ refs, Linear refs, cleanup checklist
  ├── research/       # investigation notes and source lists feeding PRDs/specs/findings
  ├── coordination/   # scratch coordination notes for multi-agent or multi-engineer work
  ├── handoffs/       # Delegation Briefs, Completion Reports, and review verdicts across loops
  ├── evidence/       # raw verification/log bundles staged before Linear attach or docs promotion
  └── learnings/      # finding/debt/wiki candidates awaiting Scribe triage
  ```
- **Treat slugs as identifiers, not locks.** `.sdlc/` is worktree-local: isolation comes from the one-interactive-session-per-checkout invariant, where the main checkout is itself a valid single-session workspace at offset `0` (see [ADR-0016](../../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) and [git worktree conventions](../git/worktrees.md)); slug uniqueness is not a concurrency mechanism. Prefer the Linear key as `<task-slug>` so same-task folders across worktrees are recognizably the same work item. Within one session, the orchestrator assigns parallel subagents distinct paths under `.sdlc/<task-slug>/`; parallel writers never share a file.
- **Keep records born in `docs/`.** Formal PRD, spec, and ADR drafts are never staged in `.sdlc/` for later moving. Create them directly in the proper `docs/` track with the track's draft/proposed status, then promote by status transition. Scratch promotion means re-authoring, not moving a file.
- **Preserve finding evidence in the finding track.** Heavy investigation evidence may be staged under `.sdlc/<task-slug>/evidence/` while work is active, but once a durable finding exists the heavy evidence belongs in `findings/<file>.assets/` per the findings convention.
- **Return complete Completion Reports.** Every delegated agent returns these sections, even when a section is empty: `Summary`, `Files changed`, `Raw verification output`, `Open questions`, and `Durable learnings`. Raw verification output is the exact command output or an explicit "not run" reason. Non-empty durable learnings are routed by the orchestrator to the Scribe for `findings/`, `debt/`, or `wiki/` triage.
- **Resume review loops.** Rework goes back to the same implementer `task_id` with the reviewer verdict quoted verbatim. The fix returns to the same reviewer session for a re-verdict. If either session is unavailable, the orchestrator creates a replacement brief that points at the prior reports and states why the same session could not be resumed.
- **Delete scratch at close.** When the work item closes, the orchestrator or Scribe verifies that needed evidence, learnings, and durable records have been attached to Linear or re-authored into `docs/`; the orchestrator then routes a deletion brief to the Dev-Environment agent to remove `.sdlc/<task-slug>/`. Agents without shell access do not execute cleanup themselves. Nothing in `.sdlc/` is the long-term source of truth.

**Examples.**

✓ Good:
```markdown
# Delegation brief

## Task
Implement the accepted staff invitation repository change.

## Inputs
- docs/specs/staff-invitations.md
- .sdlc/portal-staff-invite/research/rls-notes.md
- services/portal/internal/app/command/port.go

## Context
Use the inputs above as the only prior-agent context; preserve Rule 4 traceability.

## Boundaries
Do not edit docs/adrs/ or change the RLS role contract.

# Completion report

## Summary
Implemented the repository change and added coverage for expired invitations.

## Files changed
- services/portal/internal/infra/postgres/repo/staff.go
- services/portal/internal/infra/postgres/repo/staff_test.go

## Raw verification output
$ go test ./services/portal/internal/infra/postgres/repo/...
ok  bootstrap/services/portal/internal/infra/postgres/repo  0.241s

## Open questions
- None.

## Durable learnings
- Finding candidate: .sdlc/portal-staff-invite/learnings/rls-expiry-index.md
```

✗ Bad:
```markdown
# Delegation brief

## Task
Implement the repository change.

## Inputs
- The previous researcher chat
- What the architect said in the transcript

## Context
As the researcher found, RLS needs a special case. Move .sdlc/portal-staff-invite/spec.md
into docs/specs/ after the human accepts it.

# Completion report

Done. Tests are green.
```

**Enforcement.** Manual review and prompt distribution enforce this rule. The orchestrator rejects briefs that contain transcript-only inputs, asks agents to re-issue Completion Reports missing required sections, resumes the same `task_id` for rework/re-review where the agent runtime permits it, and routes non-empty durable learnings to the Scribe. The rendered agent prompts are the distribution point: [`packages/nix/core/ai/default.nix`](../../../packages/nix/core/ai/default.nix) currently emits the Delegation Brief and Completion Report stubs under each agent's `Communication Protocols` section, and the later implementation slice must update those templates to match this convention. Code review rejects committed `.sdlc/` files; the later `.gitignore` slice will make that local-only boundary mechanical, but until then contributors must not stage `.sdlc/` and must delete task folders at close.

## See also

- [Agent conventions index](README.md)
- [ADR-0021](../../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md) — the decision that established this rule.
- [Implementation workflow](../../wiki/implementation-workflow.md) — pipeline, Rule 4 traceability, Rule 5 human authority, and human gates.
- [Agile roles RACI](../../wiki/agile-roles.md) — role boundaries for orchestrator, architect, Scribe, and human authority.
- [Evidence-based delivery](../delivery/evidence-based-delivery.md) — Linear evidence requirements that `.sdlc/<task-slug>/evidence/` can stage before close.
- [Agent orchestration delegation debt](../../debt/agent-orchestration-no-delegation.md) — prior debt motivating artifact-mediated delegation.
