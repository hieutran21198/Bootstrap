# <Capability title>

> **Status**: Draft
> **Authors**: <people writing the PRD — e.g. Minh Hieu Tran <hieu.tran21198@gmail.com>>
> **Last reviewed**: YYYY-MM-DD
> **Realized by**: <ADRs / specs / glossary entries this PRD spawned, filled in over time, or "— (pending)">

> **PRD rule — requirements only.** Capture **what** users need and **why**. Do **not** name a technology, API, schema, or design — the "how" belongs in [`specs/`](../specs/) and the decision in [`adrs/`](../adrs/). If you catch yourself designing, stop and push it downstream.
>
> **Draft → Accepted self-check.** Before changing `Status` out of `Draft`, confirm: every requirement has a stable ID; every requirement is singular, measurable where relevant, and testable by inspection/demo/test; success criteria are measurable and technology-agnostic; scope has explicit in/out boundaries; assumptions and constraints are explicit and not design decisions; no `[NEEDS CLARIFICATION]` markers remain; no implementation details leaked into requirements, success criteria, or Downstream Handoff; every domain term is defined in or nominated for [`glossary/`](../glossary/); downstream links are listed under **Realized by**.

## Problem / Context

The user- or operator-visible gap this capability closes, who is affected, why it matters now, and what observable outcome would improve. State it in problem-space — the outcome people need, not the mechanism. One or two paragraphs; assume the reader knows the workspace but not this corner of it. State the directional outcome here; put measurable targets in **Success criteria / metrics**.

## Users & personas

- **<persona>** — who they are and what they are trying to accomplish.
- **<persona>** — ...

## Success criteria / metrics

How we know the PRD succeeded. Use stable IDs (`SC1`, `SC2`, …). Each criterion is a measurable, technology-agnostic user/business outcome; avoid internal component metrics, tool names, or implementation mechanisms. If the exact target is not known, use `[NEEDS CLARIFICATION: <specific metric/threshold question>; recommended default: <default>]` and resolve it before `Status: Accepted`.

- **SC1** — <metric or observable outcome, baseline → target, by when; e.g. reduce manual reconciliation time from X to Y by DATE>.
- **SC2** — <qualitative or operational success signal that can still be verified; e.g. target persona can complete TASK without support in N of N observed trials>.

## Requirements

Write requirements as stable, individually traceable bullets (`R1`, `R2`, …). Each requirement is one observable, solution-free behaviour or outcome. Prefer [EARS](https://alistairmavin.com/ears/) for acceptance criteria: explicit trigger/state + `THE SYSTEM SHALL` + observable response. Use `SHALL NOT` for prohibitions.

Clarification discipline: mark only material unknowns inline as `[NEEDS CLARIFICATION: <specific question>; recommended default: <default>]`. Keep at most **3** markers in a draft; resolve all markers before `Status: Accepted`.

- **R1 [event-driven]** — WHEN `<trigger>`, THE SYSTEM SHALL `<observable response>`. SO THAT `<user/business rationale>`.
- **R2 [ubiquitous]** — THE SYSTEM SHALL `<always-true observable behaviour>`.
- **R3 [state-driven]** — WHILE `<state>`, THE SYSTEM SHALL `<observable response>`.
- **R4 [optional]** — WHERE `<optional capability is in scope>`, THE SYSTEM SHALL `<observable response>`.
- **R5 [unwanted behaviour]** — IF `<fault / error / abuse condition>`, THEN THE SYSTEM SHALL `<safe fallback / rejection / recovery outcome>`.
- **R6 [complex]** — WHILE `<state>`, WHEN `<trigger>`, THE SYSTEM SHALL `<observable response>`.
- **R7 [negative]** — THE SYSTEM SHALL NOT `<prohibited observable behaviour>`.

Requirement quality checks:

- One requirement per bullet; split compound `and/or` statements.
- Use measurable thresholds where they affect acceptance; avoid vague words such as "fast", "user-friendly", "robust", or "scalable" without a verifiable predicate.
- Keep wording technology-agnostic and user/business-framed.
- Do not force EARS where it does not fit; write non-functional constraints as measurable, solution-free statements.
- Implementation-leakage scan: if a requirement names a language, framework, API, endpoint, schema, table, queue, cache, deployment platform, storage product, protocol, or internal metric, restate the observable outcome here and route the neutral downstream topic to **Downstream Handoff**.

## Non-goals

- <Outcome we are explicitly **not** chasing here.>
- <Anything a reasonable reader would expect but that belongs to another PRD, a spec, or an ADR — say so and link.>
- <If stakeholder input included technical hints, note that they are intentionally not requirements and will be considered downstream as neutral decision/design topics.>

## Scope (In / Out)

Make the boundary explicit. **Out of scope is mandatory**: it prevents scope creep and tells downstream authors what not to design. Link each scope item to requirement IDs where helpful.

### In scope

- <Capability / outcome included in this PRD> (serves <R# / SC#>).
- <Boundary or user segment included>.

### Out of scope

- <Capability / outcome excluded from this PRD> — <reason or owning PRD/spec/ADR if known>.
- <Reasonable expectation explicitly deferred to later> — <why>.

## Assumptions & Constraints

Record defaults and binding facts so downstream authors do not guess. Assumptions are reasonable defaults adopted where the input was silent; constraints are business, regulatory, timeline, domain, or already-decided platform facts that shape the solution space. Neither is a place to choose new technology or design. If a constraint depends on an existing decision, link the ADR/spec rather than restating its design.

### Assumptions

- **A1** — <reasonable default adopted; owner/source; affects <R# / SC#>>.
- **A2** — <another assumption, or "None.">.

### Constraints

- **C1** — <binding non-solution fact; source; affects <R# / SC#>>.
- **C2** — <another constraint, or "None.">.

## Domain intent / ubiquitous language

Candidate terms this capability introduces. Define them canonically in [`glossary/`](../glossary/) once they stabilize, then link — do **not** define them here.

- **<term>** — working meaning (→ `glossary/<term>.md` once defined).

## Alternatives considered

Requirement-level why-nots — framings of the *requirement* we rejected (not technical options; those live in the ADR).

- **<alternative framing>** — not chosen because <reason>.
- **<smaller/larger scope boundary>** — not chosen because <reason>.

## Open questions

- `[NEEDS CLARIFICATION: <specific question>; recommended default: <default>]` — <owner> — <blocking | non-blocking>.
- Keep no more than **3** inline `[NEEDS CLARIFICATION]` markers in a draft. Ask only if the answer changes scope, a requirement, or a success criterion; otherwise record the reasonable default in the relevant section.
- **All `[NEEDS CLARIFICATION]` markers must be resolved before `Status` moves past `Draft`** (see [README § Lifecycle](README.md#lifecycle)).

## Downstream Handoff

List the downstream decision candidates and design topics this PRD creates. This section is **solution-free**: do not name a chosen technology, API shape, schema, framework, provider, protocol, deployment, or implementation task. Translate technical hints into neutral topics and tie each item to the requirement or success-criterion IDs it serves.

Use this shape: `<topic> — <ADR candidate | spec candidate>; serves <R# / SC#>; downstream question: <what must be decided later>`.

- **ADR candidate** — <decision topic, e.g. "real-time delivery mechanism">; serves <R# / SC#>; downstream question: <solution-free decision to make>.
- **Spec candidate** — <design/contract topic>; serves <R# / SC#>; downstream question: <solution-free design detail to resolve>.
- **None** — <use only if this PRD creates no known downstream decision/design topics yet>.

## Realized by

Filled in as downstream docs are authored — the reverse of their `Tracks` field. Keep in sync.

- **Decisions**: <ADR-NNNN, or "— (pending)">
- **Designs**: <specs/<feature>.md, or "— (pending)">
- **Terms**: <glossary/<term>.md, or "— (pending)">

## References

- Deciding/contextual ADRs, prior PRDs, tickets, external prior art. Link the context the requirements presume; never restate it.

Author review checklist before requesting `Accepted`:

- [ ] Requirements are complete enough for downstream ADR/spec authors to proceed without guessing product intent.
- [ ] Every requirement has a stable ID and is singular, testable, and observable.
- [ ] Requirements and success criteria are measurable where relevant and technology-agnostic.
- [ ] Success criteria use stable `SC#` IDs, have measurable user/business outcomes, and avoid internal implementation metrics.
- [ ] Scope has explicit **In scope** and **Out of scope** lists; every requirement fits inside the stated scope.
- [ ] Assumptions and constraints are explicit, falsifiable where relevant, and do not choose a design.
- [ ] Downstream Handoff lists only ADR/spec candidates or design topics tied to `R#` / `SC#` IDs — no chosen technologies or task plans.
- [ ] No architecture, API, schema, framework, storage, deployment, or task detail appears as a requirement.
- [ ] Open questions are explicit; no `[NEEDS CLARIFICATION]` markers remain for acceptance.
- [ ] Domain terms are linked to or nominated for the glossary, and downstream docs are linked under **Realized by**.
