---
name: prd-authoring
description: Turn a rough or ambiguous product prompt into a solution-free, testable PRD that follows this repo's PRD template (docs/prds/TEMPLATE.md). Use when the user describes a product need, feature idea, problem to solve, or asks for a PRD / requirements / "what should we build" — BEFORE any design, ADR, spec, or implementation. Asks only the few clarification questions that change scope, a requirement, or a metric; otherwise proceeds with recorded assumptions. Never writes architecture, APIs, schemas, frameworks, or code.
user-invocable: false
allowed-tools: Read, Grep, Glob, Bash
---

# PRD Authoring

Convert an ambiguous user prompt into a high-quality Product Requirements Document.
The PRD is the upstream source for ADRs, specs, and the backlog — it captures *what*
users need and *why*, never *how*. The authoritative PRD format and lifecycle are:

- **Template**: [`docs/prds/TEMPLATE.md`](../../../docs/prds/TEMPLATE.md)
- **Policy**: [`docs/prds/README.md`](../../../docs/prds/README.md)
- **Track conventions**: [`docs/AGENTS.md`](../../../docs/AGENTS.md) (PRDs section)

This skill ensures every PRD passes the `Draft → Accepted` gate: no open
`[NEEDS CLARIFICATION]` markers; no leaked implementation in requirements, success
criteria, or Downstream Handoff; success criteria are measurable and technology-agnostic;
scope has explicit in/out boundaries; assumptions and constraints are explicit and
not design choices; Downstream Handoff names only neutral decision candidates tied to
requirement IDs — never chosen technologies; and every domain term is either defined
in [`glossary/`](../../../docs/glossary/) or nominated under **Domain intent**.

## When to use

- The user states a need, problem, feature idea, or asks for a PRD / requirements.
- Intent is "what/why we should build", before any design decisions are made.
- The prompt is vague, mixed with solutions, or a one-liner — that is expected.

## When NOT to use

- The user wants a technical design, architecture, or ADR (route to the architect / design agents).
- The user wants an implementation plan, task breakdown, or code (downstream — route to the backend agent).
- A PRD already exists and needs only a small edit (edit in place; skip discovery).
- The user asks a pure fact/lookup question or is debugging.

## Input expectations

Any free-form description of a need. The prompt may be vague, may embed technology
references, or may be a single sentence. That is the normal input — do not demand
a complete brief. Mixed-in technical details (languages, databases, APIs) are
expected and must be translated into requirements, constraints, or neutral
Downstream Handoff candidates — never embedded as chosen technologies (see
[Leakage scan](#leakage-scan) below).

## Output modes

Pick the mode from the classified scope; default to **one-page** unless scope
is clearly large.

| Mode | When | What it produces |
|------|------|-----------------|
| **questions-only** | ≥2 blockers unknown, no reasonable defaults | The 2–3 highest-impact clarification questions; stop — do not draft |
| **brief** | Pre-PRD exploration or a tiny change | Problem + hypothesis + success metric + scope boundary |
| **one-page** | Small to medium feature (default) | Full PRD against `TEMPLATE.md`; all mandatory sections, compact |
| **full** | Multi-capability or 6+ week effort | Full PRD; every section filled in detail |

## Readiness check (run first)

Score six dimensions before drafting. Each is **Known (0) / Partial (1) / Unknown (2)**:

| # | Dimension | Blockers? |
|---|-----------|-----------|
| D1 | Problem / need | **Yes** |
| D2 | Primary user / persona | **Yes** |
| D3 | Primary outcome / success direction | **Yes** |
| D4 | Scope (in + obvious out) | **Yes** |
| D5 | Core functional behaviours | No — proceed with defaults |
| D6 | Constraints / non-functional posture | No — proceed with defaults |

Decision rules:

- **Any blocker (D1–D4) = Unknown (2) with no defensible default → ASK** (targeted, budgeted).
  If ≥2 blockers are Unknown with no defaults, output **questions-only** mode.
- **Blocker = Partial, or a default exists → PROCEED** with an explicit assumption recorded.
  Optionally add one `[NEEDS CLARIFICATION]` if the partial answer materially forks the PRD.
- **Non-blockers (D5–D6) Unknown/Partial → PROCEED** with reasonable defaults; mark only
  the highest-impact fork as a `[NEEDS CLARIFICATION]`.

## Clarification policy

### The hard caps

- ≤ **5 interactive questions** per round (batch them all, then wait — never interrogate serially).
- ≤ **3 `[NEEDS CLARIFICATION]` markers** in any draft PRD.

### When to ask

Ask **only if** the answer would change **scope, a requirement, or a success metric**,
AND no reasonable default exists. Priority when trimming: **scope > security/privacy/compliance >
user experience > technical details**.

### Every question must carry

1. A **recommended default** (what you will use if they don't answer).
2. Where possible, 2–5 mutually-exclusive options (A/B/C/Custom) with implications.
3. Constrained free-text answers ("answer in ≤5 words").

### Do NOT ask about

- Technology choices (missing tech detail is expected in a PRD — translate user
  hints into neutral Downstream Handoff topics instead).
- Data retention, standard performance expectations, standard error-handling UX,
  standard auth approach, common integration patterns — record them as assumptions instead.
- Anything that is not a scope/requirement/metric fork.

## PRD writing process

1. **Classify intent.** Confirm this is requirements work. If the prompt is actually asking
   for a design, ADR, or task breakdown, route it instead.

2. **Extract actors, actions, data, constraints, and technical hints** from the prompt.
   Every technology the user mentions gets classified (see [Leakage scan](#leakage-scan)).
   The technical hint itself must never appear in a requirement — only the outcome it serves.

3. **Run the readiness check** (§Readiness check). If questions-only, present the 2–3
   highest-impact questions and stop. Do not draft until blockers are resolved.

4. **Draft the PRD** against [`docs/prds/TEMPLATE.md`](../../../docs/prds/TEMPLATE.md),
   filling every section in order:

   - **1. Problem / Context** — The user need, who hits it, why now. Concrete evidence
     where possible; no solution language. One or two paragraphs. State the directional
     outcome here; put measurable targets in §3 Success criteria.
   - **2. Users & personas** — Distinguish primary from secondary. Job-to-be-done per
     persona.
   - **3. Success criteria / metrics** — Stable `SC1`, `SC2`, … IDs. Each criterion is a
     measurable, technology-agnostic user/business outcome. Avoid internal component
     metrics, tool names, or implementation mechanisms. Use `[NEEDS CLARIFICATION:
     <metric/threshold question>; recommended default: <default>]` for unknown targets.
   - **4. Requirements** — One testable, solution-free, EARS-shaped statement per bullet.
     Number them (`R1`, `R2`, …). Include quality/performance requirements when they can
     be expressed as observable outcomes. Mark only material unknowns inline:
     `[NEEDS CLARIFICATION: <question>; recommended default: <default>]` (≤3 total).
   - **5. Non-goals** — What is explicitly not being chased. Be specific; say "deferred
     to vNext" or link to the owning PRD where known.
   - **6. Scope (In / Out)** — Explicit **In scope** and mandatory **Out of scope** lists.
     Link scope items to requirement IDs where helpful (e.g. "(serves R1, R3)"). Out of
     scope prevents scope creep and tells downstream what *not* to design.
   - **7. Assumptions & Constraints** — `A1`, `A2`, … for reasonable defaults the input
     was silent on; `C1`, `C2`, … for binding non-solution facts (existing platform,
     regulatory, timeline). Neither chooses a design or technology. Tie each to the
     affected `R#` / `SC#`.
   - **8. Domain intent** — Candidate terms the capability introduces. Working definition,
     then nominated for formal definition in [`glossary/`](../../../docs/glossary/).
   - **9. Alternatives considered** — Requirement-level why-nots (not technical options,
     which live in ADRs). Only include framings seriously weighed.
   - **10. Open questions** — `[NEEDS CLARIFICATION: …; recommended default: …]` markers
     replicated here with owners and blocking/non-blocking tags. No blocking question may
     be unresolved at `Draft → Accepted`.
   - **11. Downstream Handoff** — A real, solution-free PRD section. Lists ADR candidates
     and spec candidates the PRD creates — never chosen technologies. Each item follows
     the shape: `<topic> — ADR candidate | spec candidate; serves <R# / SC#>; downstream
     question: <what must be decided later>`. Technical hints from the user's input are
     translated into neutral topics here, tied to the requirement or success-criterion
     IDs they serve. If no downstream decisions are known yet, write `— None.`
   - **12. Realized by** — Leave as `— (pending)`. Filled later as downstream ADRs/specs
     link back via `Tracks`.
   - **13. References** — Source prompt, context-setting ADRs, prior PRDs, external prior
     art.

5. **Run the leakage scan** (§Leakage scan) on every requirement and success criterion.
   If a leak is found, restate the requirement as the observable *outcome* and translate
   the technology into a neutral ADR/spec candidate for the PRD's **Downstream Handoff**
   section (§11), tied to the `R#`/`SC#` ID it serves. If it's a binding existing-platform
   fact, record it as a constraint (`C1`, …) under §7 Assumptions & Constraints.

6. **Classify technical hints from the user's input** using the five-bucket rule (§7 of
   the research report). Every hint becomes either a requirement (extract the outcome),
   a constraint (record in §7), or a neutral Downstream Handoff candidate (§11) — never
   a chosen technology embedded in the PRD.

7. **Complete the validation checklist** (§Validation checklist). Resolve every CRITICAL
   finding. Remaining `[NEEDS CLARIFICATION]` markers must be ≤3 and non-blocking.

8. **Report**: PRD path on disk, status (`Draft`), checklist results (pass/fail per
   category), open questions with owners, and the recommended next phase (design/ADR).
   **Never perform the next phase** — hand off by writing the PRD at the correct path:
   `docs/prds/<capability>.md` (kebab-case, no numbering).

## Requirement writing rules

### Must

- Use **SHALL** for binding requirements (NEVER "should", "may", or "must" — `SHALL` is
  unambiguous).
- **One behaviour per statement.** Split anything joined by "and"/"or".
- **Active voice** with a named subject ("the system", "the user").
- **Prefer EARS patterns**: `WHEN <trigger> THE SYSTEM SHALL <observable outcome>` or
  `WHILE <state> THE SYSTEM SHALL <response>` or `IF <condition> THEN THE SYSTEM SHALL <response>`.
  Append `SO THAT <rationale>` to capture the "why" where it helps.
- **Quantify.** Numbers + units + threshold. No vague adjectives ("fast", "scalable",
  "user-friendly", "robust").
- **Stable IDs:** `R1`, `R2`, … for requirements; optionally `AC-<R>.<n>` for finer-grained
  sub-criteria under a requirement when one needs decomposition.
- **Testable.** Every requirement must describe an externally observable behaviour or
  outcome verifiable by inspection, demonstration, or test.

### EARS patterns reference

| Pattern | Shape | Example |
|---------|-------|---------|
| Ubiquitous | `The system SHALL <response>.` | `The system SHALL NOT retain payment card verification codes after a transaction completes.` |
| Event-driven | `WHEN <trigger>, the system SHALL <response>.` | `WHEN a user submits the checkout form, the system SHALL confirm the order within 3 seconds.` |
| State-driven | `WHILE <state>, the system SHALL <response>.` | `WHILE a user session is inactive beyond the allowed period, the system SHALL require re-authentication.` |
| Unwanted behaviour | `IF <condition>, THEN the system SHALL <response>.` | `IF a payment authorization fails, THEN the system SHALL preserve the cart and show a retry option.` |

### When NOT to force EARS

EARS fits observable, conditional *system behaviour*. For business vision, market
positioning, or quality constraints that are not conditional behaviour, use plain
measurable statements. Don't force `SHALL` onto a strategic objective.

### Good vs bad requirements

| Bad | Why it fails | Rewrite |
|-----|-------------|---------|
| `should be fast` | Vague, unverifiable, "should" | `WHEN a user opens the dashboard, the system SHALL display current data within 2 seconds.` |
| `register, log in, reset, edit` | 4 requirements in one bullet | Split into `R1` … `R4`, one behaviour each |
| `store sessions in Redis, 15-min TTL` | Names a technology + mechanism | `WHILE a session is active, the system SHALL keep it valid for at least 15 minutes of inactivity.` |
| `API returns 200 <200ms` | Internal metric, technology-flavoured | `SC1: 95% of requests SHALL return results within 1 second under peak load.` |
| `data shall be validated` | Passive — by whom, against what? | `WHEN a user submits the form, the system SHALL reject inputs that fail the stated rule and SHALL display which field failed.` |

## Leakage scan

After drafting the Requirements section, scan every bullet for implementation leakage.
Flag — and rewrite — anything that names:

- **Named technologies:** databases (Postgres, MySQL, Redis, Mongo), brokers (Kafka, SQS),
  frameworks/langs (React, Vue, Django, Express, Go), protocols/formats (REST, GraphQL,
  gRPC), infra (Docker, Kubernetes, S3, Lambda), auth mechanisms (JWT, OAuth as mechanism).
- **Component nouns:** endpoint, table, column, index, cache, queue, microservice,
  service boundary, schema, migration.
- **Mechanism verbs:** "store in", "implement with", "use", "call", "cache", "index",
  "deploy to".
- **Internal metrics:** cache-hit rate, TPS of a DB, response time of an internal component.

On a hit: (1) restate as the observable *outcome* the technology was meant to achieve,
(2) translate the technology into a neutral ADR or spec candidate and place it in the
PRD's **Downstream Handoff** section (§11), tied to the requirement or success-criterion
ID it serves, (3) if it's a binding existing-platform fact, record it as a constraint
(`C1`, …) under **Assumptions & Constraints** (§7).

## Validation checklist (Draft-exit gate)

Before reporting the PRD as complete, verify every item. A PRD may not leave `Draft` until
all pass. Frame each as a question about the *requirements* — never the implementation.

### Clarity & completeness

- [ ] All 13 mandatory sections from `TEMPLATE.md` are present and filled.
- [ ] Written for business stakeholders; no jargon only engineers understand.
- [ ] Each requirement is singular (no compound "and/or" behaviours).

### Success criteria

- [ ] Every success criterion has a stable `SC1`, `SC2`, … ID.
- [ ] Each is measurable (metric + threshold where relevant) and technology-agnostic.
- [ ] No internal implementation metrics (cache-hit rate, component latency, TPS of a DB).

### Testability

- [ ] Every requirement has at least one testable acceptance criterion.
- [ ] No vague/unverifiable terms ("fast", "scalable", "user-friendly", "robust") without
  a measurable predicate.
- [ ] Every measurable outcome has a number + unit + threshold.

### Solution-free wording

- [ ] No implementation details (languages, frameworks, APIs, schemas, infra, mechanisms)
  in any requirement or success criterion — leakage scan clean.
- [ ] Any technical input from the user has been translated into solution-free requirements,
  success criteria, or neutral Downstream Handoff topics — never embedded as-is.

### Scope boundaries

- [ ] **In scope** and **Out of scope** are both explicitly listed; Out of scope is mandatory.
- [ ] Each requirement fits inside the stated scope — no scope creep.

### Assumptions & constraints

- [ ] Assumptions (`A1`, …) record reasonable defaults where the input was silent.
- [ ] Constraints (`C1`, …) record binding facts that shape the solution space.
- [ ] Neither assumptions nor constraints choose a design, technology, or framework.

### Downstream Handoff

- [ ] Every item is a solution-free ADR candidate or spec candidate tied to `R#` / `SC#` IDs.
- [ ] No chosen technology, API shape, schema, provider, protocol, or task plan appears.
- [ ] Items use the shape: `<topic> — ADR candidate | spec candidate; serves R#/SC#; downstream question: <what must be decided later>`.

### Open questions

- [ ] ≤ 3 `[NEEDS CLARIFICATION]` markers.
- [ ] No unresolved blocking question — every open question is tagged blocking or non-blocking
  with an owner and a recommended default.
- [ ] All reasonable-default decisions are recorded in Assumptions, not left silent.

### Readiness for downstream

- [ ] Requirements are numbered lists an agent can iterate over.
- [ ] Domain terms are nominated under **Domain intent** for formal glossary definition.
- [ ] A reviewer could derive tests directly from the requirements without asking
  "what did you mean?"

### Severity for findings

- **CRITICAL** = missing mandatory section, requirement with zero acceptance criteria,
  unresolved blocking question, implementation leakage in a requirement/success criterion,
  Downstream Handoff naming a chosen technology → **blocks Draft-exit.**
- **HIGH** = untestable criterion, vague quality requirement, conflicting requirements,
  missing ID, success criterion framed as internal metric.
- **MEDIUM** = terminology drift, missing edge case, Downstream Handoff item missing
  requirement-ID link.
- **LOW** = wording nits.

## Anti-patterns (hard NO)

- Architecture, APIs, DB schemas, frameworks, service boundaries, deployment, or code
  in the PRD — these belong in [`specs/`](../../../docs/specs/) and [`adrs/`](../../../docs/adrs/).
- Treating a technology preference as a product requirement.
- Compound requirements (multiple behaviours joined by "and"/"or").
- Vague adjectives ("fast", "scalable", "secure") without a number.
- "Should" / "may" instead of `SHALL` for binding requirements.
- Exceeding the question budget (≤5 questions, ≤3 `[NEEDS CLARIFICATION]`).
- Asking about technology choices — missing tech detail is normal in a PRD.
- Silent assumptions or silent TBDs (record them explicitly).
- Naming a chosen technology, API, or implementation plan in Downstream Handoff
  — record neutral topics tied to requirement IDs only.
- Producing design or tasks in the same artifact (keep the three tiers separate:
  requirements → design/ADR → tasks).
- Defining a term canonically in the PRD — that is the glossary's job. Nominate candidates
  in Domain intent; define formally in [`glossary/`](../../../docs/glossary/).
- Hard-coding template section names or rules that might drift from
  [`docs/prds/TEMPLATE.md`](../../../docs/prds/TEMPLATE.md) — always re-read the
  authoritative template when authoring.

## Examples

### Questions-only mode

**Prompt:** "We need some kind of dashboard for our customers."

Readiness: D1 (problem) Unknown, D3 (outcome) Unknown, D4 (scope) Unknown — ≥2 blockers
with no defensible defaults. Output **questions-only**:

1. *What decision or task should this dashboard help customers accomplish?*
   (Recommended: "Monitor the status of their active orders/accounts")
2. *Which customers — a specific role, or all account holders?*
   (Recommended: "All account holders")
3. *What is the signalling metric — what number should move?*
   (Recommended: "Reduce support tickets related to account status inquiries")

### One-page mode (partial prompt)

**Prompt:** "Let customers reset their own password without contacting support, so we
cut support load. Should work on web."

Readiness: D1 known (self-service reset; cut support), D2 partial (customers on web),
D3 known (reduce support contacts), D4 partial (web only). Proceed with defaults.

Assumptions adopted (not asked): standard email-based flow; mobile app out of scope
for v1; standard error-handling UX. Draft a one-page PRD against `TEMPLATE.md` with
≤3 `[NEEDS CLARIFICATION]` markers (e.g. notification channel, baseline support volume).

### Technical hints mixed in

**Prompt:** "Build a real-time orders dashboard using websockets and a Postgres table,
JWT with 15-min expiry, handle 10k users. Add a REST endpoint /orders."

Extract requirements (solution-free):

- `R1: WHEN a new order is created, the system SHALL reflect it on all open dashboards
  within 2 seconds. SO THAT staff act on orders promptly.`
- `R2: WHILE viewing the dashboard, the system SHALL show each order's current status.`
- `R3: WHEN a user's session has been inactive beyond the allowed period, the system
  SHALL require re-authentication.`

"10k users" is a legitimate quality requirement — express as a success criterion:
`SC1: The system SHALL serve 10,000 concurrent users within stated latencies.`

Downstream Handoff (solution-free, tied to requirement IDs):

- **Real-time delivery mechanism** — ADR candidate; serves R1; downstream question:
  what mechanism delivers new-order events to open dashboards within 2 seconds?
- **Order persistence** — Spec candidate; serves R1, R2; downstream question:
  what data store and schema support the order lifecycle?
- **Session validity mechanism** — Spec candidate; serves R3; downstream question:
  how does the system enforce session inactivity limits?
- **Order API design** — Spec candidate; serves R1, R2; downstream question:
  what contract surfaces order creation and status queries?

Every technical hint was translated into a solution-free topic. No technology
(websockets, Postgres, JWT, REST) appears as a chosen solution — each is the
downstream author's decision, not the PRD's.

## Completion criteria (Done When)

- PRD written to disk at `docs/prds/<capability>.md` following `TEMPLATE.md`.
- All 13 mandatory sections filled; status is `Draft`.
- Every requirement (`R1`, `R2`, …) has a stable ID and is testable and observable.
- Success criteria use stable `SC1`, `SC2`, … IDs and are measurable + technology-agnostic.
- Scope has explicit In scope and Out of scope lists.
- Assumptions (`A1`, …) and constraints (`C1`, …) are explicit and not design choices.
- Downstream Handoff lists only ADR/spec candidates tied to `R#` / `SC#` IDs — no chosen technologies.
- Leakage scan clean — no implementation detail in any requirement or success criterion.
- ≤3 `[NEEDS CLARIFICATION]` markers; no unresolved blocking question.
- Validation checklist passes with no CRITICAL findings.
- Completion report includes: path, status, checklist summary, open questions with
  owners, and recommended next phase (design/ADR).
