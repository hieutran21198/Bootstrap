# 0014. Add a Security Reviewer agent

- **Status**: Accepted
- **Date**: 2026-07-03
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

[ADR-0007](0007-nix-devenv-developer-environment.md) makes the AI system part of the Nix-owned developer environment: agent modules live under `packages/nix/core/ai/agents/`, generated `.opencode/*` / `.claude/*` artifacts are never hand-edited, and project skills such as [`rls-patterns`](../../tools/ai/skills/rls-patterns/SKILL.md) are authored as reviewable markdown then exposed through `core.ai.skills.*`. The agent modules own card metadata, `posture`, and `instructions = builtins.readFile ./PROMPT.md`; skills are a separate allow-list on the skill module, not an agent-local setting.

RLS and tenant isolation are the workspace's highest-risk security surface. [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) made Postgres RLS the authority for tenant isolation, [ADR-0009](0009-safe-system-scope-rls.md) narrowed `system` scope behind `system_reader` and an unforgeable `SystemReadCapability`, and [ADR-0011](0011-org-root-rls-hardening.md) removed the tenant-root RLS exception. The safety properties depend on several pieces staying aligned: Postgres roles, policy predicates, transaction-local GUCs, organization/system entry points, and typed capability usage.

Today that surface is effectively written and self-reviewed by the same lane. `backend-engineer` owns database/RLS implementation work, and the `rls-patterns` skill is allow-listed only to `backend-engineer`. That violates the workspace's `writer != reviewer` review-gate principle on the surface where a missed predicate, wrong role, or forged system-scope path can become a cross-tenant breach. The Architect remains the general design and correctness reviewer, but RLS policy and authorization review need a narrower, security-focused lens.

## Decision

**We will add a new `Security Reviewer` subagent as `packages/nix/core/ai/agents/08-security-reviewer/` to independently review DB-touching changes for RLS policy correctness, tenant/system scoping, role/GUC contracts, and `SystemReadCapability` usage.** The agent is a pure review gate: it returns a verdict and concrete findings inline, touches nothing, and relies on the orchestrator to route durable finding write-ups to the Scribe.

The implementer will mirror the existing agent-module shape used by `packages/nix/core/ai/agents/03-architect/default.nix` — card metadata, sibling `PROMPT.md`, and `instructions = lib.mkDefault (builtins.readFile ./PROMPT.md)` — and set this posture exactly:

```nix
posture = {
  edit = "deny";
  bash = "deny";
};
```

Capability access remains separate from the agent module: add `security-reviewer` to the `agents` allow-list in `packages/nix/core/ai/skills/rls-patterns/default.nix` so it may load the `rls-patterns` skill. The boundary is explicit: `backend-engineer` implements RLS and database code, `architect` reviews general design/ADR/spec correctness, and `security-reviewer` is the specialized security/authz reviewer for RLS-sensitive changes.

## Consequences

- **Positive**:
  - RLS changes now have an independent reviewer with the same `rls-patterns` vocabulary as the implementer but a different lane and mandate.
  - The highest-risk tenant-isolation surface gets a least-privilege review posture: no edits, no shell, no accidental mutation of code, docs, or local databases.
  - The Architect stays focused on broad design trade-offs while authorization details get a dedicated checklist-driven review.
  - Finding write-ups remain centralized through the Scribe instead of letting a review gate become a second documentation writer.
- **Negative**:
  - Routing adds ceremony: DB-touching or RLS-adjacent changes need an extra specialized review hop.
  - With `bash = "deny"`, the Security Reviewer cannot run isolation tests or database probes; it must call out required verification and rely on the implementer/orchestrator for raw test output.
  - With `edit = "deny"`, it cannot directly log `docs/findings/` records; urgent findings require a follow-up delegation to the Scribe.
- **Neutral**:
  - The AI roster gains `08-security-reviewer` after the existing `00`-`07` agents.
  - The `rls-patterns` skill allow-list expands beyond `backend-engineer`; the skill body itself remains in `tools/ai/skills/rls-patterns/SKILL.md`.
  - This decision changes the review lane, not the RLS architecture from ADR-0008/0009/0011.

## Alternatives considered

- **Keep `backend-engineer` as both RLS implementer and reviewer.** Rejected because it preserves self-review on the workspace's highest-risk security surface and weakens the `writer != reviewer` gate exactly where it matters most.
- **Use the Architect for all RLS review.** Rejected because the Architect should remain the general design/correctness gate; RLS policy, GUC, role, and capability checks are specialized enough to warrant their own security/authz lens.
- **Give the Security Reviewer `edit = "allow"` so it can write `docs/findings/`.** Rejected because a clean review gate should be unforgeable and non-mutating. Durable write-ups are still valuable, but the orchestrator can delegate them to the Scribe after the review verdict.
- **Give the Security Reviewer `bash = "allow"` for database probes.** Rejected because executing verification shifts the lane from independent review into investigation/implementation. The reviewer should require evidence; the implementer or orchestrator supplies raw test output.

## References

- [ADR-0007: Manage the developer environment with Nix + devenv](0007-nix-devenv-developer-environment.md) — Nix-owned generated AI artifacts and project skill materialization.
- [ADR-0008: RLS tenant isolation with organization and system scopes](0008-tenant-scoped-unit-of-work-rls.md) — RLS as tenant-isolation authority and the scope/GUC contract.
- [ADR-0009: Safe `system`-scope RLS](0009-safe-system-scope-rls.md) — `system_reader`, org allow-lists, and `SystemReadCapability`.
- [ADR-0011: Org-root RLS hardening](0011-org-root-rls-hardening.md) — tenant-root self-keyed RLS.
- [`packages/nix/core/ai/agents/03-architect/default.nix`](../../packages/nix/core/ai/agents/03-architect/default.nix) — agent module shape to mirror.
- [`packages/nix/core/ai/agents/04-backend-engineer/default.nix`](../../packages/nix/core/ai/agents/04-backend-engineer/default.nix) — current implementation lane for database/RLS work.
- [`packages/nix/core/ai/skills/rls-patterns/default.nix`](../../packages/nix/core/ai/skills/rls-patterns/default.nix) — skill allow-list that will include `security-reviewer`.
- [`rls-patterns` skill](../../tools/ai/skills/rls-patterns/SKILL.md) — RLS policy, GUC, and verification checklist.
