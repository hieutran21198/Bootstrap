# <Capability title>

> **Status**: Draft
> **Authors**: <people writing the PRD — e.g. Minh Hieu Tran <hieu.tran21198@gmail.com>>
> **Last reviewed**: YYYY-MM-DD
> **Realized by**: <ADRs / specs / glossary entries this PRD spawned, filled in over time, or "— (pending)">

> **PRD rule — requirements only.** Capture **what** users need and **why**. Do **not** name a technology, API, schema, or design — the "how" belongs in [`specs/`](../specs/) and the decision in [`adrs/`](../adrs/). If you catch yourself designing, stop and push it downstream.

## Problem / Context

The user- or operator-visible gap this capability closes, and why now. State it in problem-space — the outcome people need, not the mechanism. One or two paragraphs; assume the reader knows the workspace but not this corner of it.

## Users & personas

- **<persona>** — who they are and what they are trying to accomplish.
- **<persona>** — ...

## Requirements

Written in [EARS](https://alistairmavin.com/ears/): testable, one line, solution-free. One requirement per bullet, numbered for reference (`R1`, `R2`, …). Mark any unknown inline with `[NEEDS CLARIFICATION: <question>]`.

- **R1** — WHEN `<trigger / condition>` THE SYSTEM SHALL `<observable outcome>`.
- **R2** — THE SYSTEM SHALL `<ubiquitous outcome that always holds>`.
- **R3** — WHILE `<state>` WHEN `<trigger>` THE SYSTEM SHALL `<outcome>`.
- **R4** — IF `<unwanted condition>` THEN THE SYSTEM SHALL `<fail-closed / fallback outcome>`.

## Non-goals

- <Outcome we are explicitly **not** chasing here.>
- <Anything a reasonable reader would expect but that belongs to another PRD, a spec, or an ADR — say so and link.>

## Domain intent / ubiquitous language

Candidate terms this capability introduces. Define them canonically in [`glossary/`](../glossary/) once they stabilize, then link — do **not** define them here.

- **<term>** — working meaning (→ `glossary/<term>.md` once defined).

## Alternatives considered

Requirement-level why-nots — framings of the *requirement* we rejected (not technical options; those live in the ADR).

- **<alternative framing>** — not chosen because <reason>.

## Open questions

- `[NEEDS CLARIFICATION: <question>]` — <owner>.
- **All `[NEEDS CLARIFICATION]` markers must be resolved before `Status` moves past `Draft`** (see [README § Lifecycle](README.md#lifecycle)).

## Realized by

Filled in as downstream docs are authored — the reverse of their `Tracks` field. Keep in sync.

- **Decisions**: <ADR-NNNN, or "— (pending)">
- **Designs**: <specs/<feature>.md, or "— (pending)">
- **Terms**: <glossary/<term>.md, or "— (pending)">

## References

- Deciding/contextual ADRs, prior PRDs, tickets, external prior art. Link the context the requirements presume; never restate it.
