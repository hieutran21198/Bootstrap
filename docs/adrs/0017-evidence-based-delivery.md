# 0017. Evidence-based delivery

- **Status**: Accepted
- **Date**: 2026-07-04
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace already treats the on-disk `docs/` tree as the durable source of
intent and delivery history: PRDs describe what and why, specs describe feature
designs, ADRs record decisions, findings preserve investigation evidence, and
the debt register tracks known follow-up. Linear is useful for day-to-day work
tracking, but without a written evidence rule it can drift from `docs/`: an item
can be closed because someone says it is done while the verification output, PR
link, or docs back-link is missing.

The current AI-agent setup also needs a clear lane boundary. The Scribe agent
owns the delivery record, backlog, roadmap, debt register, and status reporting;
it does not coordinate agents or make design decisions. Linear access therefore
belongs with Scribe as a tracker-sync capability, not with every agent by
default.

The constraints that shape this decision:

- `docs/conventions/` requires every new standing rule to be justified by an ADR.
- The existing Linear MCP module uses OAuth through `mcp-remote`, so no new
  secretspec contract is required.
- The AI renderer already inverts each MCP capability's `agents` allow-list into
  per-agent OpenCode permissions, so Linear can be granted to Scribe while every
  other agent remains denied by default.
- Evidence must be auditable later by reading raw outputs and links, not by
  trusting a green badge screenshot or an agent assertion.

## Decision

We will adopt evidence-based delivery for tracked workspace work: Linear is the
mirror tracker for the durable `docs/` record, every tracked work item carries
acceptance criteria and an owner, and a work item may close only with linked
evidence: raw verification output, a PR or commit reference, and pointers back
to the relevant `docs/` record.

We will record the living rule in
[docs/conventions/delivery/evidence-based-delivery.md](../conventions/delivery/evidence-based-delivery.md).
The Scribe agent will be the only agent allow-listed for the Linear MCP by
default; it files Linear items from `docs/` records, keeps Linear and `docs/`
in sync, attaches or links evidence at close time, and writes status reports
that reconcile tracker state against the durable docs record.

## Consequences

- **Positive**:
  - "Done" becomes auditable: each closed work item can be traced to verification
    output, a merged PR or commit, and the `docs/` record it realizes.
  - Linear remains useful for day-to-day status without replacing `docs/` as the
    durable source of intent, decisions, debt, and investigation history.
  - Scribe gets a narrow, explicit tracker-sync capability through Linear while
    other agents remain denied by default.
  - Status reports can cite evidence instead of summarizing unverified claims.
- **Negative**:
  - Closing work now requires more bookkeeping: owners must preserve raw command
    output and links instead of relying on a verbal or agent-written assertion.
  - Linear and `docs/` reconciliation creates ongoing Scribe work whenever either
    side is stale or incomplete.
  - The evidence gate is behavioral and review-enforced, not mechanically
    validated by a Linear workflow rule or repository validator. The Scribe is
    instructed to refuse Done transitions without evidence, and reviewers/status
    reports audit compliance, but no automated validator can yet prove every
    Linear state transition is compliant.
- **Neutral**:
  - The conventions taxonomy gains a `delivery/` topic with one living rule.
  - Jira remains disabled and GitHub MCP wiring stays unchanged; this decision
    only covers Linear as the delivery tracker for Scribe.
  - Linear OAuth still happens through `mcp-remote` on first MCP use.

## Alternatives considered

- **Keep status only in `docs/`, with no tracker mirror.** Rejected because
  `docs/` is durable but not an ergonomic day-to-day queue for filing,
  assignment, triage, and progress reporting.
- **Use Linear as the source of truth and let `docs/` lag.** Rejected because it
  would invert the workspace documentation model: PRDs, specs, ADRs, findings,
  and debt entries must remain the durable record future contributors can read
  without tracker access.
- **Allow every agent to use the Linear MCP.** Rejected because tracker mutation
  is a delivery-record responsibility. Broad access would blur agent lanes and
  allow implementers/reviewers to update status without Scribe reconciliation.
- **Require a mechanical validator before adopting the convention.** Rejected for
  now because Linear state transitions happen outside the repository and the
  immediate value comes from a clear convention plus Scribe behavior. A future
  validator or Linear workflow policy can strengthen enforcement without
  changing the rule.

## References

- [Evidence-based delivery convention](../conventions/delivery/evidence-based-delivery.md)
- [Delivery conventions index](../conventions/delivery/README.md)
- [Conventions lifecycle](../conventions/README.md) — every new standing rule is justified by an ADR.
- [`packages/nix/core/ai/mcps/linear/default.nix`](../../packages/nix/core/ai/mcps/linear/default.nix) — Linear MCP capability and Scribe allow-list.
- [`packages/nix/core/ai/agents/06-scribe/PROMPT.md`](../../packages/nix/core/ai/agents/06-scribe/PROMPT.md) — Scribe delivery-record instructions.
- Approved plan: "Wire Scribe to Linear for evidence-based delivery" (2026-07-03).
