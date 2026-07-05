# 0021. Artifact-mediated agent communication and the `.sdlc/` scratch workspace

- **Status**: Accepted
- **Date**: 2026-07-05
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace already runs AI work through an orchestrator plus specialized
subagents. That runtime has deliberate isolation properties: subagents start with
fresh context windows, sibling subagents cannot see each other, and transcripts
are not a durable source a future contributor can audit. The existing prompts and
wiki pages therefore push the orchestrator toward thin Delegation Briefs, raw
Completion Reports, `writer ≠ reviewer`, and Rule 4 traceability back to `docs/`
and Linear.

The gap is a durable hand-off substrate for work that is important during a task
but not yet a project record. Today that material can live only in a chat window,
in ad-hoc untracked files, or prematurely in formal tracks. Those choices create
different failures: transcript-only context is not independently reviewable;
unstructured local files are hard to route between agents; and premature
`docs/` entries blur the lifecycle of PRDs, specs, ADRs, findings, and debt.

The constraints that shape this decision:

- The project source of truth is `docs/`; Linear is the operation source of truth
  for delivery state and close-out evidence.
- Formal `docs/` tracks have explicit lifecycles. Gate-pending PRDs, specs, and
  ADRs must be born in their proper track as `Status: Draft` or
  `Status: Proposed`, where humans can review them and where Rule 4 links can
  point from the moment the record exists.
- Local-only dot directories such as `.opencode/`, `.claude/`, `.codex/`, and
  `.codegraph/` are already treated as per-checkout or per-worktree state.
- Parallel agent work happens in independent Git worktrees, so scratch state must
  be worktree-local rather than shared across branches.

## Decision

We will keep agent communication hub-and-spoke through the orchestrator, with
hand-offs mediated by durable artifacts on disk and Linear; we will not introduce
peer-to-peer agent channels, shared transcript stores, or a message bus.

We will add a repository-root `.sdlc/` scratch workspace for disposable,
worktree-local deliberation artifacts, organized per work item as
`.sdlc/<task-slug>/`. Deliberation belongs in `.sdlc/`; durable records belong in
`docs/` and are born there in the proper formal-track status. Promotion from
scratch to record is re-authoring into the target track by the owning agent, not
moving a scratch file into `docs/`.

The living protocol rules are recorded in
[docs/conventions/agents/artifact-mediated-communication.md](../conventions/agents/artifact-mediated-communication.md).

## Consequences

- **Positive**:
  - Agent hand-offs become auditable without giving up fresh subagent contexts:
    every delegated claim can point at `docs/`, code, Linear, or a task-local
    scratch file instead of an invisible transcript.
  - The orchestrator remains the coordination hub, preserving role boundaries,
    `writer ≠ reviewer`, and the human gates documented in the implementation
    workflow.
  - Formal-track drafts stay visible in `docs/` from creation, so `Tracks`,
    `Realized by`, and Linear references can be minted at filing time and remain
    stable through acceptance.
  - Parallel worktrees get independent scratch spaces, preventing one agent's
    investigation notes or staged evidence from bleeding into another branch.
- **Negative**:
  - Contributors and agents must maintain another local workspace during active
    work and clean it up when the task closes.
  - Re-authoring scratch notes into formal records costs more than moving a file,
    and important learning can still be lost if the owning agent fails to route it
    before deletion.
  - Enforcement starts as prompt-, review-, and convention-driven behavior; the
    `.gitignore` and prompt-template updates are a later implementation slice.
- **Neutral**:
  - `docs/conventions/` gains an `agents/` topic for communication and scratch
    workspace rules.
  - Concurrency isolation derives from ADR-0016's one-session-per-checkout model,
    not from `.sdlc/<task-slug>` uniqueness.
  - `.sdlc/` is not a new documentation track and does not change the lifecycle of
    PRDs, ADRs, specs, findings, debt, glossary, conventions, or wiki pages.
  - Heavy investigation evidence still lands beside the durable finding in
    `findings/<file>.assets/` once the Scribe or owning agent files the record.

## Alternatives considered

- **Peer-to-peer agent channels or a message bus.** Rejected because they would
  create another operational system to inspect, secure, and reconcile while
  weakening the orchestrator's responsibility for routing, review loops, and
  human-facing summaries.
- **Shared transcript stores as the hand-off medium.** Rejected because
  transcripts are session-shaped rather than artifact-shaped: they are noisy,
  difficult to cite by stable path, and encourage agents to rely on prior chat
  context instead of externalizing the claim future contributors need to audit.
- **Commit `.sdlc/` into the repository.** Rejected because scratch deliberation,
  staged evidence, and interim review reports are not durable project records;
  committing them would clutter history and increase the risk of preserving
  local-only or sensitive working material.
- **Stage formal PRD/spec/ADR drafts in `.sdlc/` and move them into `docs/` on
  acceptance.** Rejected because moving files would break the stable identity of
  gate-pending drafts, hide them from normal `docs/` review, and make Rule 4
  traceability fragile: Linear and `Tracks` / `Realized by` links need valid
  `docs/` paths at filing time.
- **Use `docs/wiki/` or `docs/findings/` for all scratch material.** Rejected
  because those are durable records. Scratch notes may feed a wiki page, finding,
  debt item, or formal draft, but the promotion step must be intentional
  re-authoring into the track's format.

## References

- [Agent artifact-mediated communication convention](../conventions/agents/artifact-mediated-communication.md)
- [Implementation workflow](../wiki/implementation-workflow.md) — pipeline, Rule 4 traceability, Rule 5 human authority, and human gates.
- [Agile roles RACI](../wiki/agile-roles.md) — orchestrator coordination, architect review, and human accountability.
- [Agent team quick reference](../wiki/agent-team.md) — current orchestrator/subagent responsibilities.
- [Agent orchestration delegation debt](../debt/agent-orchestration-no-delegation.md) — the debt this decision resolves.
- [`packages/nix/core/ai/default.nix`](../../packages/nix/core/ai/default.nix) — current prompt renderer for Delegation Brief and Completion Report templates.
- [ADR-0016: Use git worktrees for parallel AI-agent sessions](0016-use-git-worktrees-for-parallel-ai-agent-sessions.md)
- [ADR-0017: Evidence-based delivery](0017-evidence-based-delivery.md)
