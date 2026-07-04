# 0019. Add a Dev-Environment agent

- **Status**: Accepted
- **Date**: 2026-07-04
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

[ADR-0007](0007-nix-devenv-developer-environment.md) makes Nix + devenv the boundary for local tooling, generated agent artifacts, shell entry, workspace commands, and generated configuration. Agent modules live under `packages/nix/core/ai/agents/`; each agent owns identity, posture, an optional per-agent `model`, and a sibling `PROMPT.md`, while skills such as [`git-workflow`](../../tools/ai/skills/git-workflow/SKILL.md) are wired separately through capability allow-lists. [ADR-0014](0014-security-reviewer-agent.md) established the pattern for adding a dedicated subagent when an important review or operations lane should not remain implicit in another role.

[ADR-0016](0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) made Git worktrees the isolation mechanism for parallel AI-agent sessions. The concrete mechanic is `ws-worktree`: it creates, lists, and removes managed worktrees, writes the `.worktree-offset` marker used for local port isolation, copies opted-in ignored environment files, and prints follow-up steps such as `direnv allow`, `codegraph init`, and starting the agent CLI from the new directory.

That local-dev and workspace-tooling surface is now broad enough to need an owner. Worktree creation currently stretches the Release-Engineer lane, even though release engineering should stay focused on CI/CD, release mechanics, and branch-protection wiring. The same orphaned lane also covers devenv/Nix module toggles, direnv and shell ergonomics, local `.env` and secret bootstrap, `codegraph init` guidance, `ws-info` / `ws-tree` usage, and dev-environment edits under `packages/nix/`.

The workspace also has no `max` / `slim` model profiles to target for this kind of work. Cost and variance must be controlled per agent through `core.ai.agents.<name>.model`. Local-dev tasks are mostly mechanical command execution, config wiring, and checklist-driven setup, so they should not inherit a high-cost, high-judgment model from a broader engineering or release lane.

## Decision

**We will add a new `Dev-Environment` opencode subagent that owns the local-dev and workspace-tooling lane.** Its broad charter covers worktree lifecycle (`ws-worktree` create/list/remove and `.worktree-offset` handling), devenv/Nix module toggles, direnv and shell ergonomics, local `.env` / secret bootstrap for development, `codegraph init` guidance, `ws-info` / `ws-tree` usage, and dev-environment edits under `packages/nix/`.

The agent will use a cheap, low-variance model through the per-agent `core.ai.agents.dev-environment.model` field. We will not introduce or depend on `max` / `slim` model profiles. The cheap model is intentional: this lane is low-judgment, repetitive local-environment work where low cost and low-temperature behavior are more appropriate than expensive broad reasoning.

The Nix posture will allow the built-in tools the lane actually needs:

```nix
posture = {
  edit = "allow";
  bash = "allow";
};
```

That permission is bounded by the agent prompt, not by expanding its ownership. `bash` is allowed for dev-environment commands such as `ws-worktree`, `direnv`, workspace info/tree commands, local environment inspection, and Nix/devenv checks. `edit` is scoped to `packages/nix/` dev-environment modules and the `tools/` wiring those modules use. The agent does not touch application Go/domain code, CI/release workflows, branch-protection policy, or ADR/spec/design documents.

Ownership moves as follows:

- Worktree creation and preparation move off Release-Engineer and onto Dev-Environment.
- Release-Engineer keeps CI/CD, release mechanics, deployment sequencing, git-hook wiring, and branch-protection ownership.
- Dev-Environment uses `ws-worktree`; Backend-Engineer still owns the Go source for that tool under `tools/generators/ws-worktree/`, mirroring the existing split where a lane may call a tool without owning the tool's implementation.

The human boundary is explicit: the agent may create and prepare a worktree, but launching a new interactive agent session remains a human action. It can print or confirm the next steps (`cd`, `direnv allow`, `codegraph init`, `opencode` or another CLI), but no agent can start a new interactive session on the user's behalf.

The agent will load the `git-workflow` skill for the worktree mechanic and git convention reminders. Implementation must add `dev-environment` to that skill's `agents` allow-list; skill access remains a capability-module concern rather than an agent-local setting.

## Consequences

- **Positive**:
  - Local-dev and workspace-tooling work gains one accountable owner instead of being split across release engineering, backend engineering, and ad-hoc skill usage.
  - Worktree setup becomes cheaper to delegate because the mechanical lane gets its own low-cost per-agent model instead of borrowing a more expensive release or engineering model.
  - Release-Engineer's lane narrows back to CI/CD, release mechanics, deployment, hooks, and branch-protection concerns.
  - `packages/nix/` dev-environment edits now have an explicit owner while generated `.opencode/*`, `.claude/*`, and other Nix-owned artifacts remain non-hand-edited outputs.
- **Negative**:
  - Another subagent adds routing overhead and another prompt/module to keep current.
  - `bash = "allow"` is broader than read-only review agents; safety depends on the prompt boundary staying focused on dev-env commands and avoiding application, release, and design work.
  - A cheap model may miss ambiguous cross-lane trade-offs; the orchestrator must route design choices to Architect, application changes to Backend-Engineer, and release/CI changes to Release-Engineer.
- **Neutral**:
  - Implementation is explicitly out of scope for this ADR. Follow-up work includes creating `packages/nix/core/ai/agents/09-dev-environment/{default.nix,PROMPT.md}` (or the next available agent slot), importing it from `agents/default.nix`, adding `dev-environment` to the `git-workflow` skill allow-list, enabling the agent and setting `core.ai.agents.dev-environment.model` to a cheap model in the root `devenv.nix`, and regenerating `.opencode/agents/*` through the normal Nix/devenv pipeline.
  - The orchestrator prompt must be updated to route worktree creation and preparation to Dev-Environment instead of Release-Engineer.
  - The stale `max` / `slim` model-profile reference in the root `AGENTS.md` must be corrected separately; this decision records that model selection is per agent.
  - The `git-workflow` skill remains the operational worktree reference. This ADR changes ownership and routing, not the worktree mechanism from ADR-0016.

## Alternatives considered

- **Stretch Release-Engineer to own worktrees.** Rejected because worktree setup is local-dev environment work, not release/CI work. Without model profiles, keeping this on Release-Engineer also prevents isolating a cheap model for mechanical setup while preserving the release lane's higher-judgment model needs.
- **Keep worktrees as a skill capability any engineer fills on demand.** Rejected because it leaves no clear owner for recurring setup, cleanup, and support, and it provides no cost isolation for a repetitive low-judgment workflow.
- **Do not add an agent and keep the workflow manual.** Rejected because worktree and local-environment bootstrap friction is recurring, and the broader `packages/nix/` dev-environment ownership gap would remain orphaned.

## References

- [ADR-0007: Manage the developer environment with Nix + devenv](0007-nix-devenv-developer-environment.md) — Nix/devenv as the developer-environment and generated-agent-artifact boundary.
- [ADR-0014: Add a Security Reviewer agent](0014-security-reviewer-agent.md) — primary pattern for adding a dedicated subagent by ADR.
- [ADR-0016: Use git worktrees for parallel AI-agent sessions](0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) — worktree mechanism, port-offset marker, and `ws-worktree` contract.
- [`packages/nix/AGENTS.md`](../../packages/nix/AGENTS.md) — agent module shape, posture/model fields, generated artifacts, and skill allow-list wiring.
- [`packages/nix/core/ai/agents/08-security-reviewer/default.nix`](../../packages/nix/core/ai/agents/08-security-reviewer/default.nix) and [`PROMPT.md`](../../packages/nix/core/ai/agents/08-security-reviewer/PROMPT.md) — subagent card, posture, and prompt shape to mirror.
- [`packages/nix/core/ai/agents/07-release-engineer/default.nix`](../../packages/nix/core/ai/agents/07-release-engineer/default.nix) — release lane boundary that worktree ownership moves away from.
- [`tools/ai/skills/git-workflow/SKILL.md`](../../tools/ai/skills/git-workflow/SKILL.md) — operational worktree and git workflow skill the agent must load.
- [`tools/generators/ws-worktree/`](../../tools/generators/ws-worktree/) — worktree command used by the agent; Go source ownership stays with Backend-Engineer.
