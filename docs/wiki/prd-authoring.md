# PRD Authoring

> Informal quick-reference (outside the 7 formal `docs/` tracks). The formal
> PRD format and lifecycle live in [`../prds/`](../prds/) and
> [`../AGENTS.md`](../AGENTS.md). Use this page to align stakeholders and agents
> before drafting a formal PRD.

## Principles

### 1. PRDs capture what and why, not how

A PRD states the problem, affected users, desired outcomes, scope boundaries,
and requirements. It does not choose architecture, APIs, schemas, frameworks,
storage products, service boundaries, deployment shape, or task breakdowns.
Those belong downstream:

- [`../prds/`](../prds/) — product and domain intent: what must be true, and why.
- [`../adrs/`](../adrs/) — decisions and trade-offs: why we chose an approach.
- [`../specs/`](../specs/) — feature design: how one accepted PRD will be built.
- Linear/backlog — delivery work: who does what, when, with evidence at close.

### 2. Requirements must be testable and observable

Every formal requirement should describe behaviour or outcomes someone can
verify by inspection, demonstration, or test. The formal PRD template uses EARS
(`WHEN` / `WHILE` / `WHERE` / `IF ... THEN` / `SHALL NOT`) because those patterns
make triggers, states, and responses explicit.

### 3. One requirement per statement

Compound requirements hide multiple behaviours and break traceability. In the
formal PRD, split "and/or" statements until each requirement can be accepted or
rejected independently.

### 4. Stable IDs create traceability

Requirement IDs are the join keys across PRDs, ADRs, specs, tasks, tests, and
release evidence. A downstream artifact should be able to cite the exact
requirement it realizes without restating it.

### 5. Success is measurable and technology-agnostic

Success should be framed as a user or business outcome: fewer support requests,
higher task completion, reduced manual handoff, faster user-visible feedback,
or similar. Avoid internal implementation metrics unless they are restated as
observable value.

### 6. Scope boundaries prevent accidental design

Say what is in scope and what is out of scope. A clear non-goal is often the
best way to stop a PRD from drifting into a spec.

### 7. Clarify only what changes the PRD

Ask questions only when the answer changes scope, a requirement, or the success
signal and no reasonable default exists. Otherwise proceed with an explicit
assumption. Formal PRD drafts should carry at most three
`[NEEDS CLARIFICATION]` markers, each with a recommended default.

### 8. Technical hints are useful input, not PRD requirements

Stakeholders may mention tools or designs. Keep the underlying need, but route
the technical hint to the downstream ADR/spec conversation unless it is an
already-binding external constraint.

## Stakeholder PRD intake template

This is a plain-language form for a product owner, operator, or other
non-technical stakeholder. It is the **input** to PRD authoring. It is not the
formal PRD template, and it does not require EARS or solution-free wording from
the stakeholder; the PRD-authoring skill transforms this intake into
`docs/prds/<capability>.md`.

Copy the form below and answer in everyday language. Short answers are fine.

```markdown
# PRD Intake: <idea or capability name>

## 1. What problem are we solving?

Describe what is wrong, missing, slow, confusing, risky, or expensive today.

## 2. Who is affected?

- Primary users:
- Other people or teams affected:
- Who decides whether this is successful?

## 3. Why does it matter now?

What changed, what is the cost of doing nothing, or what opportunity are we
trying to capture?

## 4. What does success look like?

How would you know this worked? Include any numbers, dates, or qualitative
signals you already have.

- Current baseline, if known:
- Target outcome, if known:
- Deadline or review date, if any:

## 5. Must-haves

List the behaviours, outcomes, or user abilities that must be true for the
first useful version.

-
-
-

## 6. Nice-to-haves

List useful additions that can be deferred if needed.

-
-

## 7. Out of scope

What should this explicitly not include? What would be tempting but too much
for this version?

-
-

## 8. Constraints and dependencies

Mention deadlines, policy constraints, existing systems, legal/privacy needs,
teams we depend on, or other facts the solution must respect.

-
-

## 9. Existing ideas or technical suggestions

If you already have solution ideas, tools, designs, screenshots, links, or
technical preferences, list them here. They are welcome as context; the PRD
author will separate the underlying need from downstream design choices.

-
-

## 10. Open questions and risks

What are you unsure about? What could make this fail or reduce its value?

-
-

## 11. Source links

Add tickets, customer notes, incident reports, research, screenshots, chats, or
other context.

-
-
```

## How agents use the intake

1. Extract problem, users, outcomes, scope, constraints, assumptions, and
   technical hints.
2. Ask only the few clarification questions whose answers would change scope, a
   requirement, or the success signal.
3. Convert must-haves into stable, testable requirements in
   [`../prds/TEMPLATE.md`](../prds/TEMPLATE.md).
4. Move design hints to downstream ADR/spec candidates instead of embedding them
   as PRD requirements.
5. Leave the formal PRD in `Draft` until the human product-intent gate accepts
   it.

## References

- Formal PRD template: [`../prds/TEMPLATE.md`](../prds/TEMPLATE.md)
- PRD lifecycle and index: [`../prds/README.md`](../prds/README.md)
- Track conventions: [`../AGENTS.md`](../AGENTS.md)
- SDLC workflow: [`implementation-workflow.md`](implementation-workflow.md)
- Evidence finding: [`../findings/2026-07-06-prd-authoring-and-prd-template-best-practices.md`](../findings/2026-07-06-prd-authoring-and-prd-template-best-practices.md)
