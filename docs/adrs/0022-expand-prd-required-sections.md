# 0022. Expand PRD required sections

- **Status**: Accepted
- **Date**: 2026-07-06
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

The PRD track is the workspace's upstream source of product and domain intent. It deliberately captures **what** users need and **why**, while decisions and designs flow downstream to `adrs/` and `specs/`. That boundary is already enforced by `docs/AGENTS.md`, `docs/prds/README.md`, and `docs/prds/TEMPLATE.md`.

The resolved PRD-authoring research finding identified four useful concerns that were present only indirectly or as template guidance: measurable success criteria, explicit in/out scope, assumptions and constraints, and a downstream handoff for topics that must be decided later. Leaving these concerns implicit makes PRDs harder to accept safely: readers cannot consistently tell what measurable outcome proves success, what is intentionally excluded, which defaults were assumed, or which downstream decisions still need an ADR/spec.

Promoting these concerns to required sections is a material convention change, so it needs an ADR. The decision is constrained by two existing track rules:

- PRDs remain solution-free; they must not name chosen technologies, APIs, schemas, frameworks, deployment shapes, or task plans.
- Existing accepted PRDs are living records, but retrofitting historical accepted PRDs solely for format churn would create noise without changing product intent.

## Decision

We will promote four concerns to first-class PRD sections: **Success criteria / metrics**, **Scope (In / Out)**, **Assumptions & Constraints**, and **Downstream Handoff**.

The required PRD sections, in order, are now:

1. Problem / Context
2. Users & personas
3. Success criteria / metrics
4. Requirements
5. Non-goals
6. Scope (In / Out)
7. Assumptions & Constraints
8. Domain intent / ubiquitous language
9. Alternatives considered
10. Open questions
11. Downstream Handoff
12. Realized by
13. References

The `Draft → Accepted` gate expands accordingly: success criteria must be measurable and technology-agnostic; scope must include explicit in-scope and out-of-scope boundaries; assumptions and constraints must be explicit and must not smuggle in design choices; and Downstream Handoff must contain only downstream decision candidates/design topics tied to the requirement or success-criterion IDs they serve.

**Migration policy:** the new required section set applies to PRDs authored or materially edited after this ADR. The existing accepted PRDs, `docs/prds/identity-and-access.md` and `docs/prds/backoffice-and-portal.md`, are grandfathered. They may be backfilled opportunistically during a future material edit or dedicated cleanup, but this ADR does not require immediate retrofit and does not reopen their acceptance.

**Downstream Handoff rule:** this section is a solution-free handoff, not a technical parking lot. It records the **decision candidates** or **design topics** that downstream ADR/spec authors must resolve and the PRD requirement IDs they serve, for example: “Real-time delivery mechanism — ADR candidate, serves R1.” It must not record a chosen technology, API shape, storage schema, framework, provider, protocol, or implementation task. If stakeholder input includes a technical hint, the PRD author must translate it into the neutral downstream decision topic and keep the selected solution out of the PRD.

## Consequences

- **Positive**:
  - PRDs become easier to accept and review because measurable outcomes, scope boundaries, defaults, and downstream decision topics are visible in predictable locations.
  - Downstream ADR/spec authors get a cleaner handoff: each candidate decision is tied to the requirements or success criteria it serves without restating or prematurely deciding the design.
  - The PRD template better matches the research-backed quality gate while preserving the existing EARS requirement style, stable `R1`-style IDs, and `[NEEDS CLARIFICATION]` discipline.
- **Negative**:
  - New PRDs require more authoring effort, especially for small changes that previously relied on a compact success signal or implicit scope.
  - Reviewers must enforce that Downstream Handoff stays neutral; otherwise it could become a backdoor for solution leakage.
  - Historical accepted PRDs will temporarily have a different shape from newly authored PRDs until opportunistically backfilled.
- **Neutral**:
  - `docs/AGENTS.md`, `docs/prds/README.md`, and `docs/prds/TEMPLATE.md` change in place as living convention/template documents.
  - Existing accepted PRDs keep their current status and content under the grandfathering policy.
  - Downstream ADRs/specs still set `Tracks: prds/<x>.md`; PRDs still list realized downstream artifacts under `Realized by`.

## Alternatives considered

- **Keep the current PRD structure and only strengthen prose guidance.** Rejected because the finding identified these concerns as acceptance-critical; leaving them embedded in other sections makes them easy to omit.
- **Add the four sections and immediately retrofit all accepted PRDs.** Rejected because the two existing accepted PRDs predate this rule and are already accepted on their product intent. Forced retrofit would create low-signal churn and risk accidental material edits.
- **Add Downstream Handoff as an unconstrained technical-hints parking lot.** Rejected because that would violate the PRD track's solution-free boundary and invite premature decisions into the requirements tier.
- **Move downstream decision candidates out of PRDs entirely.** Rejected because technical hints and design questions still need traceable routing. A neutral handoff section lets PRDs preserve useful context while deferring all choices to ADR/spec authors.
- **Adopt a larger full PRD structure with mandatory user stories, risks, non-functional sections, and traceability matrices.** Rejected as too heavy for this workspace's current track contract. The chosen sections address the approved structural gap without replacing the existing template style.

## References

- [PRD authoring and PRD template best practices finding](../findings/2026-07-06-prd-authoring-and-prd-template-best-practices.md)
- [Full PRD research report evidence](../findings/2026-07-06-prd-authoring-and-prd-template-best-practices.assets/research-report.md)
- [PRD track README](../prds/README.md)
- [PRD template](../prds/TEMPLATE.md)
- [docs/AGENTS.md](../AGENTS.md) — global docs taxonomy and track conventions updated by this decision.
