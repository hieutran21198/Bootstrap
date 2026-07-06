# Research Report: PRD Skill and Template Improvement

> **Scope & independence.** This report was researched independently of any existing
> project PRD skill, template, or convention. Evidence is drawn only from external
> requirements-engineering standards, product-discovery literature, the EARS notation,
> and real public spec-driven-development artifacts (GitHub spec-kit, Amazon Kiro,
> OpenSpec, coco-skills, agentskills.io, and several real `requirements.md` / `SKILL.md`
> files). Sections 9 and 10 are **proposals** (drafts) — applying them to the real
> `SKILL.md` / `TEMPLATE.md` is a separate follow-up.

---

## 1. Executive summary

**The single most important finding:** across every modern source — the EARS notation
(2009, Rolls-Royce), the ISO/IEC/IEEE 29148 requirements standard, classic product
discovery (Cagan, Torres, Amazon Working Backwards), and the 2025–2026 spec-driven-
development tools (GitHub spec-kit, Amazon Kiro, OpenSpec) — the same discipline recurs:
**a requirements artifact captures WHAT users need and WHY, in solution-free, testable,
individually-identified statements, and defers HOW to a separate downstream document.**
spec-kit states it bluntly in its own spec template: *"Focus on WHAT users need and WHY.
Avoid HOW to implement (no tech stack, APIs, code structure). Written for business
stakeholders, not developers."* Kiro operationalizes the same split as three separate
files — `requirements.md` → `design.md` → `tasks.md` — never mixing them.

Seven findings shape our recommendations:

1. **A PRD is the "what/why" tier of a three-tier chain** (requirements → design/ADR →
   tasks/tests). It must never contain architecture, APIs, schemas, frameworks, or
   task breakdowns; those belong to the tiers below it.
2. **Requirements must be testable, observable, singular, and solution-free** (ISO 29148
   characteristics). EARS is the highest-leverage tool for this because its constrained
   syntax (`WHEN/WHILE/WHERE/IF-THEN … the system SHALL …`) forces a trigger + an
   observable response, which maps 1:1 to a test case.
3. **EARS belongs at the acceptance-criteria layer**, under user-value statements — not
   as the whole requirement. Kiro and coco-skills both nest EARS criteria under user
   stories. The PRD stays outcome-first; EARS makes each outcome verifiable.
4. **Clarification must be strictly budgeted.** spec-kit hard-caps automatic drafting at
   **max 3 `[NEEDS CLARIFICATION]` markers** and interactive clarification at **max 5
   questions**, each with a *recommended* default and A/B/C/Custom options. The rule for
   whether to ask: ask only when the answer materially changes **scope, a requirement, or
   a success metric** and no reasonable default exists.
5. **Stable requirement IDs are the linchpin of traceability.** `FR-001`, `SC-001`,
   `AC-1.1` let downstream ADRs, specs, backlog items, and tests link back
   unambiguously. This should be a *blocking* validator rule, not a nice-to-have.
6. **Validation should run as a checklist that behaves like "unit tests for English."**
   spec-kit's `checklist.md` command frames requirement-quality checks as questions
   about the requirements (not the implementation); a PRD cannot leave Draft until it
   passes a Content-Quality / Completeness / Readiness gate plus a solution-free scan.
7. **A good AI skill is mostly a good description + a phased process with hard gates.**
   The `description` frontmatter is the only text the router sees at startup, so it must
   carry trigger keywords and when-to-use. The body should be a numbered process with
   explicit stopping points, prohibitions phrased as hard rules, and a Done-When
   checklist.

The rest of the report turns these into: PRD principles (§2), a section-by-section
template design (§3, §10), a readiness/ambiguity model (§4), a reusable clarification bank
(§5), EARS writing guidance with good/bad/rewrite pairs (§6), a five-bucket requirement-
vs-design classifier (§7), a Draft-exit validation checklist (§8), a full proposed
`SKILL.md` (§9), three worked examples (§11), and sourced notes (§12).

---

## 2. Recommended PRD principles

Each principle is stated with **why it matters** and **how to enforce it in the AI skill**.

### P1 — Problem/outcome first, solution-free
- **Principle:** The PRD states the user need, the affected users, why it matters, and the
  measurable outcome — never the technology, architecture, API, schema, or code structure.
- **Why:** Solutions stated as requirements over-constrain design, hide the real need, and
  bind the product to a stack prematurely (ISO 29148 "appropriate" characteristic; spec-kit
  "no implementation details"; Cagan's product-vs-delivery split). "Solution-first thinking"
  is a named PM anti-pattern.
- **Enforce in skill:** A hard prohibition rule ("NEVER write tech/architecture/APIs/schemas
  in a PRD") + an automated leakage scan (§6.5) that flags named technologies and component
  nouns and either strips them or routes them to a downstream candidate list (§7).

### P2 — Every requirement is testable and observable
- **Principle:** Each requirement describes an externally observable behaviour or outcome
  that can be verified by inspection, demonstration, or test.
- **Why:** Untestable requirements ("fast", "user-friendly", "scalable") cannot be
  validated and produce divergent implementations (ISO 29148 "verifiable"; EARS testability;
  Kiro's "executable specification / property-based testing").
- **Enforce in skill:** Require EARS-shaped acceptance criteria on every functional
  requirement; run the "think like a tester" check — *every vague requirement must fail the
  "testable and unambiguous" checklist item* (spec-kit).

### P3 — One requirement per statement (singular)
- **Principle:** No compound requirements; split any statement joined by "and/or".
- **Why:** Compound requirements hide multiple behaviours, break traceability, and make
  test coverage ambiguous (ISO 29148 "singular"; EARS "one requirement per statement").
- **Enforce in skill:** A validator rule that flags conjunctions in a requirement body and
  a writing rule "one SHALL per outcome".

### P4 — Stable identifiers on everything traceable
- **Principle:** Every functional requirement, non-functional requirement, business rule,
  success criterion, acceptance criterion, user story, assumption, constraint, and open
  question gets a stable ID.
- **Why:** IDs are the join key for the entire downstream chain (ADRs, specs, backlog,
  tests, traceability matrix). Track A's strongest cross-source finding: *"the single
  highest-leverage thing a PRD can do is assign stable IDs."*
- **Enforce in skill:** The template pre-numbers sections; the validator blocks Draft-exit
  if any requirement lacks an ID or if any acceptance criterion does not reference a
  requirement ID.

### P5 — Measurable, technology-agnostic success criteria
- **Principle:** Success is stated as measurable outcomes (metric + threshold) framed from
  the user/business perspective, never as system internals.
- **Why:** Technology-agnostic outcomes survive design changes and give downstream tests a
  target (spec-kit Success-Criteria guidelines: *"Measurable, Technology-agnostic,
  User-focused, Verifiable"*; Amazon Working Backwards; North-Star framing).
- **Enforce in skill:** Success-criteria good/bad examples in the skill (§6); validator
  rejects success criteria that name a framework/DB/latency-of-an-internal-component.

### P6 — Explicit scope boundaries (in and out)
- **Principle:** State what is in scope and, especially, what is **out of scope**.
- **Why:** Silent omission of out-of-scope is the most common PRD failure; explicit
  boundaries prevent scope creep and set downstream expectations (spec-kit `Assumptions`;
  PM best practice *"always include out-of-scope"*).
- **Enforce in skill:** "Out of Scope" is a **mandatory** template section; the readiness
  model treats missing scope boundaries as a **blocker** (§4).

### P7 — Budgeted discovery; assume-and-mark rather than interrogate
- **Principle:** Ask only questions whose answers change scope, a requirement, or a metric;
  otherwise adopt a reasonable default and record it as an assumption. Cap questions.
- **Why:** Over-asking destroys the "turn an ambiguous prompt into a PRD" value; spec-kit
  caps markers at 3 and questions at 5, always offering a recommended default.
- **Enforce in skill:** The clarification policy (§4, §5) with the hard caps; every question
  must carry a recommended answer; unresolved-but-non-blocking items become
  `[NEEDS CLARIFICATION]` markers, not blocking questions.

### P8 — Traceable in both directions, versioned next to code
- **Principle:** Each requirement links backward to a source (need/persona/goal) and
  forward to downstream artifacts; the PRD lives in the repo and changes when intent changes.
- **Why:** Bidirectional traceability + "live traceability" prevents drift and enables
  impact analysis (Jama RTM guidance; ISO 29148 traceability).
- **Enforce in skill:** A "Traceability" block per requirement (source + downstream refs)
  and a rule that the PRD is the source of truth — when requirements change, downstream
  regenerates.

### P9 — Record decisions and assumptions as first-class, dated, owned
- **Principle:** Assumptions, constraints, and open questions are explicit sections with
  owners and (for questions) a "resolve-before / defer" flag.
- **Why:** Hidden assumptions are a top requirements defect; explicit ones are cheap to
  challenge (avo-hq "Outstanding Questions" with `Resolve Before Planning` vs
  `Deferred to Planning`).
- **Enforce in skill:** Mandatory Assumptions and Open Questions sections; each open
  question tagged blocking/non-blocking.

### P10 — Right-size the artifact
- **Principle:** Match PRD depth to change size (full PRD, one-page PRD, or brief).
- **Why:** A heavy template on a small change wastes effort and invites gold-plating
  (PM toolkit: Standard / One-Page / Feature-Brief variants).
- **Enforce in skill:** An output-mode selector (§9) that picks template depth from the
  classified scope.

---

## 3. Recommended PRD structure

For each section: **purpose**, **required/optional**, **what good content looks like**, and
**common mistakes**. (The assembled template is in §10.)

### 3.1 Header / Metadata
- **Purpose:** Identity + lifecycle: title, PRD ID/slug, status (Draft/Reviewed/Approved),
  owner, created/updated dates, links to source idea.
- **Required.**
- **Good:** `Status: Draft`, a stable PRD slug used as the ID prefix, an owner.
- **Mistakes:** No status field (can't gate); no stable ID prefix (breaks traceability).

### 3.2 Problem / Context ("Why")
- **Purpose:** The problem, its cause, why it matters now, and any background needed to
  judge necessity.
- **Required.**
- **Good:** A concrete problem statement with evidence (who hits it, how often, current
  workaround). OpenSpec makes a `## Why` block mandatory as the justification hook.
- **Mistakes:** Describing a solution instead of the problem; no "why now"; unfalsifiable
  claims.

### 3.3 Users / Personas & Stakeholders
- **Purpose:** Who has the need and who is affected (including non-user stakeholders).
- **Required.**
- **Good:** Named personas with the job-to-be-done; distinguish primary vs secondary.
- **Mistakes:** "All users"; conflating the buyer with the user; omitting affected internal
  roles.

### 3.4 Goals / Business Objectives & Non-Goals
- **Purpose:** The outcome the business wants; explicit non-goals.
- **Required.**
- **Good:** Objective tied to a measurable result (ties to §3.9). Non-goals stated plainly.
- **Mistakes:** Vanity objectives; missing non-goals; objectives that are actually features.

### 3.5 User Scenarios / Stories (prioritized, independently testable)
- **Purpose:** The user journeys, prioritized (P1/P2/P3), each independently testable.
- **Required.**
- **Good:** `As a [role], I want [capability] so that [benefit]` + `Why this priority` +
  `Independent Test` + Given/When/Then acceptance scenarios (spec-kit spec-template).
  Each story is a standalone MVP slice.
- **Mistakes:** Stories with no "so that"; non-independent stories; acceptance scenarios
  that describe UI mechanics instead of outcomes.

### 3.6 Functional Requirements (IDed, EARS acceptance criteria)
- **Purpose:** The system behaviours required, each with a stable ID and testable criteria.
- **Required.**
- **Good:** `FR-001: The system SHALL …` (or a user-value statement whose acceptance
  criteria are EARS). Each FR "MUST be testable" (spec-kit); each links to the user
  story/goal it serves.
- **Mistakes:** Implementation baked in (§7); compound requirements; "should/may" instead
  of "shall/must"; no acceptance criteria.

### 3.7 Non-Functional / Quality Requirements
- **Purpose:** Quality attributes (performance, availability, security posture, privacy,
  accessibility, compliance) — stated as measurable targets, technology-agnostic.
- **Required (when relevant; the categories to consider are mandatory to review).**
- **Good:** `NFR-001: 95% of searches return results in under 1 second at 10,000 concurrent
  users.` A posture, not a mechanism ("must protect PII" not "use AES-256").
- **Mistakes:** "Must be scalable/secure/fast" with no number; NFRs that name a technology;
  EARS-forcing a purely architectural constraint (EARS is a poor fit there — state it as a
  measurable constraint instead).

### 3.8 Business Rules & Domain Language / Glossary
- **Purpose:** Invariant rules ("an order over $X requires approval") + a glossary of
  capitalized domain/system terms.
- **Required (glossary strongly recommended for AI parseability).**
- **Good:** `BR-001` rules; a glossary defining every capitalized `<system name>` used in
  EARS so an agent doesn't invent synonyms (Kiro convention).
- **Mistakes:** Rules mixed into functional requirements; undefined capitalized terms.

### 3.9 Success Criteria / Metrics
- **Purpose:** How we know it worked — measurable, technology-agnostic outcomes.
- **Required.**
- **Good:** `SC-001: Reduce support tickets about X by 50% within one quarter.` Mix
  quantitative + qualitative (task-completion, satisfaction).
- **Mistakes:** Implementation metrics ("cache hit rate > 80%"); unmeasurable goals; no
  baseline/target.

### 3.10 Scope: In / Out
- **Purpose:** Boundaries.
- **Required (Out-of-Scope is mandatory).**
- **Good:** Bulleted in-scope; explicit out-of-scope with a one-line reason or "deferred to
  vNext".
- **Mistakes:** Only listing in-scope; leaving scope implicit.

### 3.11 Constraints & Dependencies
- **Purpose:** Binding external facts that shape the solution space (existing platform,
  regulatory, timeline, budget) and dependencies on other systems/teams.
- **Required (when any exist).**
- **Good:** `CON-001: Must operate within the existing identity provider.` These are
  *inputs*, not requirements (§7 bucket 1).
- **Mistakes:** Treating a constraint as a requirement; treating a *preferred* technology as
  a constraint.

### 3.12 Assumptions
- **Purpose:** Reasonable defaults adopted where the input was silent.
- **Required.**
- **Good:** `ASM-001: Mobile support is out of scope for v1.` Each assumption is
  falsifiable and owned.
- **Mistakes:** Silent assumptions; assumptions that are really unresolved blockers.

### 3.13 Open Questions / `[NEEDS CLARIFICATION]`
- **Purpose:** Known unknowns, each flagged blocking vs non-blocking.
- **Required.**
- **Good:** `Q-001 [blocking][scope]: …`; `[NEEDS CLARIFICATION: …]` inline where a
  requirement is provisional (avo-hq resolve-before vs defer).
- **Mistakes:** Burying unknowns as silent TBDs; leaving blocking questions unmarked.

### 3.14 Risks
- **Purpose:** Product/market/adoption/compliance risks and mitigations.
- **Optional (recommended).**
- **Good:** Risk + likelihood/impact + mitigation or "accept".
- **Mistakes:** Only technical risks; risks with no mitigation.

### 3.15 Downstream Handoff (ADR / spec / backlog candidates)
- **Purpose:** A parking lot for technical hints the user gave that must NOT live in the
  PRD — recorded as candidates for the design/ADR/spec tier (§7).
- **Required (when the input contained technical detail).**
- **Good:** `ADR-candidate: real-time delivery mechanism (source: user said "websockets")`.
- **Mistakes:** Letting these leak back into requirements; discarding them silently.

### 3.16 Review & Acceptance Checklist (embedded)
- **Purpose:** The self-check the author/agent completes before requesting Draft-exit.
- **Required.**
- **Good:** The §8 checklist embedded and ticked.
- **Mistakes:** Ticking without evidence; treating the first draft as final.

---

## 4. PRD readiness model

The agent must decide: *do I have enough to draft a PRD, and where must I ask vs assume?*

### 4.1 The three information tiers

**A. Minimum required (BLOCKERS — cannot draft a useful PRD without a defensible answer):**
1. **Problem/need** — what is wrong or missing, and for whom.
2. **Primary user/persona** — who has the need.
3. **Primary desired outcome** — what "better" looks like (at least directionally
   measurable).
4. **Scope anchor** — the one or two core capabilities in scope, and the obvious
   out-of-scope line.

If any blocker is truly unknowable from the input *and* has no reasonable default, the agent
asks a targeted question (within budget). If a blocker has a reasonable default, the agent
may proceed with an explicit assumption instead of asking.

**B. Important but non-blocking (proceed with default + assumption/marker):**
- Secondary personas; exact success-metric thresholds; non-functional targets; business
  rules; integration dependencies; edge-case handling; terminology.
- Handle via reasonable defaults (spec-kit list: data retention, performance expectations,
  error-handling UX, auth method, integration patterns) recorded in Assumptions, or
  `[NEEDS CLARIFICATION]` markers where the default is genuinely uncertain.

**C. Explicitly out of scope for the PRD (never blockers):**
- Technology/architecture/API/schema/framework choices. Missing tech detail is **not** a
  reason to ask a clarification during PRD authoring — it's expected. Record the user's
  technical hints in the Downstream Handoff (§3.15).

### 4.2 Ambiguity scoring model (lightweight, deterministic)

Score six dimensions; each is **Known (0) / Partial (1) / Unknown (2)**:

| Dim | Dimension | Blocker? |
|-----|-----------|----------|
| D1 | Problem / need | Yes |
| D2 | Primary user / persona | Yes |
| D3 | Primary outcome / success direction | Yes |
| D4 | Scope (in + obvious out) | Yes |
| D5 | Core functional behaviours | No (assume) |
| D6 | Constraints / NFR posture | No (assume) |

Decision rule:
- **Any blocker (D1–D4) = Unknown (2) with no reasonable default → ASK** (targeted, budgeted).
- **Blocker = Partial, or default exists → PROCEED with an explicit assumption**, and
  optionally add one `[NEEDS CLARIFICATION]` if the partial answer materially forks the PRD.
- **Non-blockers (D5–D6) Unknown/Partial → PROCEED with reasonable defaults**; mark only the
  highest-impact fork as a `[NEEDS CLARIFICATION]`.
- **Total score ≥ ~8 and ≥2 blockers Unknown → the prompt is too raw**: ask the 2–3 highest-
  impact questions first, don't attempt a full PRD yet (see Example 1, §11).

### 4.3 When to ask vs when to proceed (the hard rules)
- **Ask only if** the answer would change **scope, a requirement, or a success metric**, AND
  no reasonable default exists.
- **Hard caps (adopted from spec-kit):** interactive clarification ≤ **5 questions**;
  automatic drafting ≤ **3 `[NEEDS CLARIFICATION]` markers**. If more arise, keep the top N
  by priority **scope > security/privacy/compliance > user experience > technical details**
  and default the rest.
- **Every question carries a recommended default** and, where possible, 2–5 mutually
  exclusive options (spec-kit "Suggested Answers" A/B/C/Custom table). Constrain free answers
  ("answer in ≤5 words").
- **Batch questions:** present all together, then wait — don't interrogate serially unless
  answers are dependent.
- **Otherwise proceed** with defaults recorded in Assumptions; never silently guess.

---

## 5. Clarification question bank

Reusable questions grouped by category. The agent selects only those that (a) target a
blocker or a high-impact fork and (b) lack a reasonable default — respecting the ≤5 cap.
Each should be offered with a recommended default.

**Problem / context**
- What problem are we solving, and what happens today without it?
- Why does this matter now (trigger, cost of inaction)?
- Is this a new capability, a fix, or an enhancement to something that exists?

**Users / personas**
- Who is the primary user? Who else is affected (secondary users, internal roles)?
- What is the user trying to accomplish (job-to-be-done)?
- Roughly how many users / how often?

**Business goals**
- What business outcome should this drive?
- What is the non-goal — what are we explicitly *not* trying to achieve here?

**Success metrics**
- How will we know it worked? What metric moves, from what baseline to what target, by when?
- What qualitative signal counts (task completion, satisfaction)?

**Scope**
- What is the smallest version that delivers value (P1)?
- What is explicitly out of scope for this release?
- Are there use cases we should exclude?

**Requirements**
- What must the system let the user do (core behaviours)?
- What are the important edge cases / error situations to handle?
- What is the expected behaviour when [X] fails or is unavailable?

**Non-functional requirements**
- Are there performance/latency/throughput expectations? (default: standard app expectations)
- Availability / uptime expectations?
- Security/privacy/compliance obligations (PII, regulated data)? (highest-priority to ask)
- Accessibility or localization needs?

**Business rules**
- Are there rules/policies the system must enforce (limits, approvals, eligibility)?
- Are there states/lifecycles an entity must follow?

**Constraints**
- Are there existing platforms/systems this must work within? (record as constraint, not
  requirement)
- Timeline, budget, or team constraints that bound scope?

**Risks**
- What is the biggest risk to adoption or value?
- Any compliance/legal/reputational risk?

**Domain language**
- How do you refer to [key noun]? Are there canonical terms we must use?
- Any terms that mean something specific in your domain?

**Technical details accidentally included by the user** (do NOT ask to expand these — instead
confirm intent and route them, §7):
- "You mentioned [technology]. Is that a hard constraint that already exists, or a suggestion
  for how to build it?" → constraint vs downstream candidate.
- "When you say '[technology]', is the underlying need '[extracted outcome]'?" → confirm the
  hidden product requirement, then park the technology in Downstream Handoff.

---

## 6. Requirement writing guidance

### 6.1 EARS patterns (the notation to default to)
The clauses always appear in the same order:
`While <precondition(s)>, when <trigger>, the <system> shall <response>.`

| Pattern | Keyword(s) | Shape | Use for |
|---------|-----------|-------|---------|
| Ubiquitous | (none) | `The <system> SHALL <response>.` | Always-true properties |
| State-driven | `WHILE` | `WHILE <state>, the <system> SHALL <response>.` | Behaviour during a state |
| Event-driven | `WHEN` | `WHEN <trigger>, the <system> SHALL <response>.` | Response to an event |
| Optional feature | `WHERE` | `WHERE <feature included>, the <system> SHALL <response>.` | Variant/flagged behaviour |
| Unwanted behaviour | `IF/THEN` | `IF <trigger>, THEN the <system> SHALL <response>.` | Faults, errors, abuse |
| Complex | combined | `WHILE …, WHEN …, the <system> SHALL …` | Richer conditions |
| Negative | `SHALL NOT` | `The <system> SHALL NOT <prohibited behaviour>.` | Prohibitions |

Ruleset: zero-or-many preconditions; zero-or-one trigger; exactly one system name;
one-or-many responses. Optional `SO THAT <rationale>` clause captures the "why" and aids
necessity checks (coco-skills convention).

**In a PRD, EARS lives at the acceptance-criteria layer**: a user-value requirement +
EARS acceptance criteria that make it testable.

### 6.2 Examples of good requirements
- `WHEN a user submits the checkout form, the system SHALL confirm the order within 3
  seconds. SO THAT users get timely feedback.` (event-driven, measurable, observable)
- `WHILE a user session is active, the system SHALL keep the session valid without
  re-authentication.` (state-driven; note: no mechanism named)
- `IF a payment authorization fails, THEN the system SHALL preserve the cart and show a
  retry option.` (unwanted behaviour; observable)
- `The system SHALL NOT retain payment card verification codes after a transaction
  completes.` (negative; privacy posture, no technology)
- `SC-002: 95% of searches return results in under 1 second at 10,000 concurrent users.`
  (measurable, technology-agnostic success criterion)

### 6.3 Examples of bad requirements
- `The system should be fast and user-friendly.` (vague, unverifiable, "should")
- `Users can register, log in, reset passwords, and edit their profile.` (compound — four
  requirements in one)
- `The system will store sessions in Redis with a 15-minute TTL.` (implementation leakage:
  technology + mechanism)
- `The API must return 200 in under 200ms.` (internal metric masquerading as a requirement;
  also technology-flavoured — restate as a user-facing outcome)
- `Data shall be validated.` (passive; by whom, against what, when?)

### 6.4 How to rewrite bad requirements
| Bad | Rewrite (solution-free, testable) |
|-----|-----------------------------------|
| "should be fast" | `WHEN a user opens the dashboard, the system SHALL display current data within 2 seconds.` |
| "register, log in, reset, edit" | Split into `FR-001 … FR-004`, one behaviour each, each with EARS criteria. |
| "store sessions in Redis, 15-min TTL" | `WHILE a session is active, the system SHALL keep it valid for at least 15 minutes of inactivity.` + park "Redis" in Downstream Handoff as a design detail. |
| "API returns 200 <200ms" | `SC-00x: Users see results within 1 second for 95% of requests.` |
| "Data shall be validated" | `WHEN a user submits [form], the system SHALL reject inputs that fail [stated rule] and SHALL show which field failed.` |

### 6.5 How to detect implementation leakage (agent self-check)
Run a scan on every requirement/success-criterion body and flag:
- **Named technologies:** databases (Postgres, MySQL, Redis, Mongo), brokers (Kafka, SQS),
  frameworks/langs (React, Vue, Django, Express, Go), protocols/formats (REST, GraphQL,
  gRPC, JSON schema), infra (Docker, Kubernetes, S3, Lambda), auth mechanisms (JWT, OAuth as
  a *mechanism*).
- **Component/layer nouns:** endpoint, table, column, index, cache, queue, microservice,
  service boundary, schema, migration.
- **Mechanism verbs:** "store in / implement with / use / call / cache / index / deploy to".
- **Internal metrics:** response time of an internal component, cache-hit rate, TPS of a DB.

On a hit: (1) restate the requirement as the observable *outcome* the technology was meant
to achieve, (2) move the technology to Downstream Handoff (§3.15) with a one-line rationale,
(3) if it's an existing platform fact, move it to Constraints. (Heuristic keyword lists are
aids, not proof — the agent still judges intent.)

### 6.6 When NOT to use EARS
EARS is for observable, conditional *system behaviour*. It is a poor fit for: business
vision/objectives, market positioning, non-functional/architectural constraints that aren't
conditional behaviour, and requirements with >3 preconditions (better as a decision table or
state diagram). For those, use plain measurable statements (NFRs) or tables — don't force
`SHALL`.

---

## 7. Requirement vs design boundary

When the user's input contains a technical artifact, classify it into exactly one bucket and
route it. (This five-bucket classifier is a synthesis; each bucket maps to a documented
practice in spec-kit / Kiro / OpenSpec / avo-hq.)

| # | Bucket | Test | Where it goes | PRD action |
|---|--------|------|---------------|------------|
| 1 | **Existing product/platform constraint** | Already true in production; binding | `Constraints` (§3.11) | Record as input, not a requirement |
| 2 | **Suggested implementation** | A soft "maybe use X" for HOW | Downstream Handoff → design/plan | Drop the tech; restate the value as a requirement |
| 3 | **Downstream ADR candidate** | A load-bearing, single, significant decision | Downstream Handoff → ADR candidate | Note the decision + which requirements depend on it |
| 4 | **Downstream spec detail** | A small technical setting/value | Downstream Handoff → spec/contracts | Never in the PRD |
| 5 | **Hidden product requirement** | The tech is a proxy for a real user need | `Functional Requirements` | Extract the outcome as an EARS requirement; park the tech |

**Worked classification of common inputs:**

| User said | Bucket | PRD outcome |
|-----------|--------|-------------|
| "We're already on [identity provider]" | 1 constraint | `CON-001: Must operate within the existing identity provider.` |
| "Maybe use websockets" | 5 hidden requirement (+2) | `FR: WHEN a new order is created, the system SHALL reflect it on all open dashboards within 2 seconds.` Park "websockets" as design candidate. |
| "Use event sourcing for orders" | 3 ADR candidate | Handoff: "ADR-candidate: order write model. Affects FR-order-history." |
| "JWT expiry = 15 minutes" | 4 spec detail | Handoff: "session validity ≈ 15 min (spec)"; PRD states the *behaviour* (WHILE session active …). |
| "Must handle 10k concurrent users" | (not tech) NFR | `NFR-001: The system SHALL serve 10,000 concurrent users within stated latency.` |
| "Add a REST endpoint /orders" | 2 suggested impl | Drop endpoint; requirement is the capability ("users SHALL be able to place an order"). |
| "Cache the results" | 2 suggested impl | Restate as the outcome (freshness/latency) as an NFR; park caching. |
| "Store files in S3" | 4 spec detail (+1 if existing) | Handoff or Constraint; PRD says "the system SHALL retain uploaded files and make them retrievable". |

**Decision heuristics:** already-true-in-prod → constraint; noun-for-a-future-technology →
ADR candidate + extract the intent; number/setting → spec detail (or constraint if binding);
capability-in-their-head → requirement (EARS); scale/quality target → success criterion / NFR.

---

## 8. PRD validation checklist (Draft-exit gate)

A PRD may not move past **Draft** until every item passes. Modeled on spec-kit's
Content-Quality / Requirement-Completeness / Feature-Readiness gate, extended with explicit
traceability and open-question rules. Frame each as a question about the *requirements*
("unit tests for English"), not the implementation.

**Clarity & completeness**
- [ ] All mandatory sections present and filled (Problem, Users, Goals/Non-Goals, Scenarios,
  Functional Requirements, Success Criteria, Scope in/out, Assumptions, Open Questions).
- [ ] Written for business stakeholders; no jargon that only engineers understand.
- [ ] Each requirement is singular (no compound "and/or" behaviours).

**Testability**
- [ ] Every functional requirement has at least one EARS-shaped, testable acceptance
  criterion.
- [ ] No vague/unverifiable terms ("fast", "user-friendly", "scalable", "robust") without a
  measurable predicate.
- [ ] Every success criterion is measurable (metric + threshold) and verifiable.

**Solution-free wording**
- [ ] No implementation details (languages, frameworks, APIs, schemas, infra, mechanisms) in
  requirements or success criteria — leakage scan (§6.5) clean.
- [ ] Success criteria are technology-agnostic and user/business-framed.
- [ ] Any technical input from the user has been routed to Constraints or Downstream Handoff
  (§7), not embedded as a requirement.

**Scope boundaries**
- [ ] In-scope items listed; **out-of-scope explicitly stated**.
- [ ] Each requirement is inside the stated scope (no scope creep).

**Traceability**
- [ ] Every FR/NFR/BR/SC/AC/US/ASM/CON/Q has a stable ID.
- [ ] Every acceptance criterion references the requirement ID it validates.
- [ ] Every requirement links back to a user story/goal (source) — bidirectional trace ready.

**Open questions & assumptions**
- [ ] ≤ 3 `[NEEDS CLARIFICATION]` markers remain (or documented why more).
- [ ] Every open question is tagged blocking/non-blocking; **no blocking question is
  unresolved** at Draft-exit.
- [ ] All reasonable-default decisions are recorded as explicit Assumptions.

**Readiness for downstream ADR/spec/backlog/test generation**
- [ ] Requirements are numbered lists (not narrative paragraphs) an agent can iterate over.
- [ ] Domain/system terms are defined in the Glossary.
- [ ] Downstream Handoff lists ADR/spec candidates extracted from technical hints.
- [ ] A reviewer could derive tests directly from the acceptance criteria without asking
  "what did you mean?"

**Severity model for findings (for an automated validator):** CRITICAL = missing mandatory
section, requirement with zero acceptance criteria, unresolved blocking question, or
implementation leakage in a requirement → **blocks Draft-exit**. HIGH = untestable criterion,
vague NFR, conflicting requirements, missing ID. MEDIUM = terminology drift, missing edge
case. LOW = wording. (Adapted from spec-kit `analyze` severities.)

---

## 9. Recommended PRD skill (proposed `SKILL.md`)

> Proposed content/outline for `prd-authoring/SKILL.md`. Draft — not applied to the real file.

```markdown
---
name: prd-authoring
description: >-
  Turn a rough or ambiguous product prompt into a solution-free, testable,
  traceable Product Requirements Document. Use when the user describes a product
  need, feature idea, problem to solve, or asks for a PRD / requirements / "what
  should we build" — BEFORE any design, ADR, spec, or implementation. Asks only
  the few clarification questions that change scope, a requirement, or a metric;
  otherwise proceeds with recorded assumptions. Produces requirements only —
  never architecture, APIs, schemas, frameworks, or code.
---

# PRD Authoring

## Purpose
Convert an ambiguous user prompt into a high-quality PRD that is the requirements
source of truth: what users need, why, who is affected, required outcomes, scope,
success metrics, and testable requirements. The PRD must be usable downstream to
generate ADRs, specs, backlog items, and tests.

## When to use
- The user states a need, problem, feature idea, or asks for a PRD/requirements.
- Intent is "what/why we should build", before design decisions are made.

## When NOT to use
- The user wants a technical design, architecture, or ADR (route to design/architect).
- The user wants an implementation plan, task breakdown, or code (downstream).
- A PRD already exists and only needs a small edit (edit directly; skip discovery).
- Pure fact/lookup or debugging.

## Input expectations
- Any free-form description of a need. It may be vague, may mix in solutions, or may
  be a one-liner. That is expected — do not demand a complete brief.

## Output modes
- **full** — complete PRD (multi-capability or 6+ week effort).
- **one-page** — condensed PRD (small, well-understood feature).
- **brief** — problem + hypothesis + success metric (pre-PRD exploration).
- **questions-only** — when the prompt is too raw to draft (≥2 blockers unknown): return
  the 2–3 highest-impact questions and stop.
Select the mode from the classified scope; default to one-page unless scope is large.

## Readiness check (run first)
Score six dimensions Known/Partial/Unknown: D1 problem, D2 primary user, D3 primary
outcome, D4 scope (D1–D4 are BLOCKERS), D5 core behaviours, D6 constraints/NFR (non-blocking).
- If ≥2 blockers Unknown with no reasonable default → output **questions-only**.
- If a blocker is Partial or has a reasonable default → proceed with an explicit assumption.
- Non-blockers Unknown → proceed with reasonable defaults; mark only high-impact forks
  with `[NEEDS CLARIFICATION]`.

## Clarification policy
- Ask ONLY if the answer changes scope, a requirement, or a success metric, AND no
  reasonable default exists.
- Hard caps: ≤ 5 questions interactively; ≤ 3 `[NEEDS CLARIFICATION]` markers in a draft.
- Priority when trimming: scope > security/privacy/compliance > UX > technical details.
- Every question includes a recommended default and, where possible, 2–5 options
  (A/B/C/Custom) with implications. Batch questions; then wait.
- Reasonable defaults you must NOT ask about: data retention, standard performance
  expectations, error-handling UX, standard auth approach, common integration patterns —
  record them as Assumptions instead.
- Never ask the user to choose a technology; missing tech detail is expected in a PRD.

## PRD writing process
1. Classify intent; confirm this is requirements work (else route).
2. Extract actors, actions, data, constraints, and any technical hints from the prompt.
3. Run the readiness check. If questions-only, ask and stop.
4. Draft the PRD using the template: Problem, Users, Goals/Non-Goals, Scenarios (P1/P2/P3,
   independently testable), Functional Requirements (IDed, EARS acceptance criteria),
   NFRs, Business Rules + Glossary, Success Criteria, Scope in/out, Constraints,
   Assumptions, Open Questions, Risks, Downstream Handoff.
5. For every technical hint the user gave, classify with the five-bucket rule and route it
   to Constraints or Downstream Handoff — never into a requirement.
6. Write requirements in EARS at the acceptance-criteria layer; assign stable IDs.
7. Run the leakage scan; restate any leaked requirement as an outcome.
8. Complete the embedded Review & Acceptance checklist; resolve CRITICALs.
9. Report: PRD path, status, checklist results, open questions, and the Downstream Handoff
   list. Recommend the next phase (design/ADR) — do not perform it.

## Requirement writing rules
- Use SHALL / MUST (never should/may) for binding requirements.
- One requirement per statement; active voice; named subject.
- Prefer EARS patterns; add `SO THAT <rationale>`.
- Quantify (units + threshold); no vague adjectives.
- Success criteria: measurable + technology-agnostic + user-framed.
- Every requirement gets an ID; every acceptance criterion references a requirement ID.

## Anti-patterns (hard NO)
- Architecture, APIs, DB schemas, frameworks, service boundaries, deployment, or code in the
  PRD.
- Treating a technology preference as a product requirement.
- Compound/vague/untestable requirements.
- Silent assumptions or silent TBDs.
- Interrogating the user (exceeding the question budget) or asking about tech choices.
- Producing design/tasks in the same artifact (keep the tiers separate).

## Examples
- Ambiguous prompt → questions-only (see report §11 Example 1).
- Partial prompt → PRD skeleton with assumptions + `[NEEDS CLARIFICATION]` (Example 2).
- Prompt with tech mixed in → requirements extracted, tech routed downstream (Example 3).

## Completion criteria (Done When)
- PRD written using the template; all mandatory sections filled.
- Draft-exit validation checklist passes (no CRITICAL findings).
- Every requirement has an ID and ≥1 testable EARS acceptance criterion.
- No implementation detail leaked; technical hints routed to Constraints/Handoff.
- ≤3 `[NEEDS CLARIFICATION]`, no unresolved blocking question.
- Completion reported with path, checklist summary, open questions, and next-phase
  recommendation.
```

---

## 10. Recommended PRD template (proposed `TEMPLATE.md`)

> Solution-free, AI-agent-friendly. Placeholders in `[ ]`; IDs pre-scaffolded. Draft.

```markdown
# PRD: [Feature / Capability Name]

- **PRD ID / slug:** [prd-slug]           <!-- ID prefix for all requirement IDs -->
- **Status:** Draft                        <!-- Draft | Reviewed | Approved -->
- **Owner:** [name]
- **Created / Updated:** [YYYY-MM-DD] / [YYYY-MM-DD]
- **Source:** [link to idea/brief]
- **Output mode:** [full | one-page | brief]

## 1. Problem / Context (Why)
[The problem, who hits it, how often, current workaround, and why now. No solution.]

## 2. Users / Personas & Stakeholders
- **Primary user:** [persona] — job-to-be-done: [...]
- **Secondary / affected:** [...]

## 3. Goals & Non-Goals
- **Business objective:** [outcome tied to a measurable result]
- **Non-goals:** [what this explicitly does not try to achieve]

## 4. User Scenarios (prioritized, independently testable)
### US-1 — [title] (Priority: P1)
As a [role], I want [capability] so that [benefit].
- **Why this priority:** [...]
- **Independent test:** [how this slice is tested/demoed alone]
- **Acceptance scenarios:**
  1. GIVEN [state] WHEN [action] THEN [observable outcome]   (→ FR-001)
### US-2 — [title] (Priority: P2) …

## 5. Functional Requirements
- **FR-001:** WHEN [trigger], the system SHALL [observable response]. SO THAT [rationale]. (→ US-1)
  - AC-001.1: [testable criterion]
- **FR-002:** WHILE [state], the system SHALL [response]. (→ US-1)
- **FR-003:** IF [error/trigger], THEN the system SHALL [response]. (→ US-2)
<!-- one behaviour per FR; EARS; stable IDs; link to the story/goal -->

## 6. Non-Functional / Quality Requirements
- **NFR-001 [performance]:** [measurable target, technology-agnostic]
- **NFR-002 [security/privacy]:** [posture, e.g., "SHALL NOT retain [sensitive data] after [event]"]
- **NFR-003 [availability/accessibility/compliance]:** [...]

## 7. Business Rules & Glossary
- **BR-001:** [invariant rule]
- **Glossary:** **[Term]** = [definition]  <!-- define every capitalized system/domain term -->

## 8. Success Criteria (measurable, technology-agnostic)
- **SC-001:** [metric, baseline → target, by when]
- **SC-002:** [qualitative: task completion / satisfaction]

## 9. Scope
- **In scope:** [...]
- **Out of scope:** [... — mandatory; give a reason or "deferred to vNext"]

## 10. Constraints & Dependencies
- **CON-001:** [binding existing platform/regulatory/timeline fact — an input, not a requirement]
- **Dependencies:** [other systems/teams]

## 11. Assumptions
- **ASM-001:** [reasonable default adopted where input was silent]

## 12. Open Questions
- **Q-001 [blocking|non-blocking][scope|security|ux|…]:** [question]  <!-- no blocking Q at Approved -->
- Inline: `[NEEDS CLARIFICATION: specific question]` (≤3 total)

## 13. Risks
- **RISK-001:** [risk] — likelihood/impact — mitigation.

## 14. Downstream Handoff (NOT requirements)
- **ADR-candidate:** [significant decision surfaced from a technical hint] (affects FR-00x)
- **Spec/design detail:** [technical setting the user mentioned]
<!-- everything the user said about HOW lives here, out of the requirements -->

## 15. Review & Acceptance Checklist
[Embed the §8 Draft-exit checklist; tick each before requesting Draft-exit.]
```

---

## 11. Examples

### Example 1 — very ambiguous prompt

**Raw prompt:** *"We need some kind of dashboard for our customers."*

**Readiness assessment (ambiguity scoring):**
- D1 problem = Unknown (2) — what pain does a dashboard solve? unknown.
- D2 primary user = Partial (1) — "customers", but which segment/role?
- D3 primary outcome = Unknown (2) — what should improve?
- D4 scope = Unknown (2) — what does the dashboard show/do?
- D5 behaviours = Unknown (2); D6 constraints = Unknown (2).
- Blockers Unknown: D1, D3, D4 (≥2) and no reasonable defaults → **questions-only mode.**

**Clarification questions (batched, ≤5, each with a recommended default):**
1. *What decision or task should this dashboard help customers accomplish?* (Recommended:
   "monitor the status of their active [orders/accounts]") — **targets D1/D3.**
2. *Which customers — a specific role/segment, or all account holders?* (Recommended: "all
   account holders") — **targets D2.**
3. *What is the one metric that would tell us it worked?* (e.g., reduced support tickets,
   higher self-serve rate) — **targets D3/success.**
4. *What's in scope for v1 vs explicitly out?* (Recommended: "view-only status for v1; no
   editing") — **targets D4/scope.**

**Why the PRD should not be written yet:** three of four blockers are Unknown with no
defensible default; drafting now would fabricate the problem, users, and scope, producing a
plausible-but-wrong source of truth. The correct move is to resolve the blockers first, then
draft.

### Example 2 — partially clear prompt

**Raw prompt:** *"Let customers reset their own password without contacting support, so we
cut support load. Should work on web."*

**Readiness:** D1 known (self-service password reset; cut support load), D2 partial
(customers, web), D3 known (reduce support contacts), D4 partial (self-serve reset; web).
Blockers satisfied or defaultable → **proceed with assumptions + a few `[NEEDS CLARIFICATION]`.**

**Assumptions adopted (recorded, not asked):**
- ASM-001: Standard email-based self-service reset flow (reasonable default; no tech chosen).
- ASM-002: Mobile app out of scope for v1 (input said "web").
- ASM-003: Standard error-handling UX (friendly messages, safe fallbacks).

**PRD draft skeleton (abridged):**
```markdown
# PRD: Self-Service Password Reset
Status: Draft · Owner: [ ] · Output mode: one-page
## 1. Problem  Customers who forget passwords must contact support, adding load and delay.
## 2. Users   Primary: account holders on web. Affected: support team.
## 3. Goals   Reduce password-related support contacts. Non-goal: broader account recovery.
## 4. Scenarios
US-1 (P1) As an account holder, I want to reset my own password so that I regain access without support.
  - AC-1.1: GIVEN a registered account WHEN the user requests a reset THEN the system SHALL start a self-service reset. (→ FR-001)
## 5. Functional Requirements
FR-001: WHEN a user requests a password reset for a registered account, the system SHALL initiate a verified reset. SO THAT only the account owner can reset.
FR-002: IF the reset identifier is invalid or expired, THEN the system SHALL reject it and allow a fresh request.
FR-003: WHEN a reset completes, the system SHALL notify the account owner. [NEEDS CLARIFICATION: notify via which channel(s)?]
## 6. NFR
NFR-001 [security]: The system SHALL NOT reveal whether an account exists during reset. [NEEDS CLARIFICATION: enumeration-safe messaging required?]
## 8. Success Criteria
SC-001: Reduce password-related support contacts by [target %] within one quarter. [NEEDS CLARIFICATION: baseline + target].
## 9. Scope  In: web self-service reset. Out: mobile app (ASM-002); full account recovery.
## 12. Open Questions  Q-001 [non-blocking][metric]: baseline support volume?
```
(≤3 `[NEEDS CLARIFICATION]`; no blocking question; no technology named.)

### Example 3 — prompt with technical details mixed in

**Raw prompt:** *"Build a real-time orders dashboard using websockets and a Postgres table,
JWT auth with 15-min expiry, must handle 10k users. Add a REST endpoint /orders."*

**Extracted requirements (solution-free):**
- FR-001: WHEN a new order is created, the system SHALL reflect it on all open dashboards
  within 2 seconds. SO THAT staff act on orders promptly. (hidden requirement behind
  "websockets")
- FR-002: WHILE viewing the dashboard, the system SHALL show each order's current status.
- FR-003: WHEN a user's session has been inactive beyond the allowed period, the system
  SHALL require re-authentication. (behaviour behind "JWT 15-min")
- NFR-001 [performance]: The system SHALL support 10,000 concurrent users within stated
  latency. (this was a real NFR, not tech)

**Technical details moved downstream (Downstream Handoff / Constraints):**
| User detail | Bucket (§7) | Routed to |
|-------------|-------------|-----------|
| websockets | 2 suggested impl / 5 hidden req | Handoff (real-time delivery mechanism); requirement is FR-001 |
| Postgres table | 4 spec detail | Handoff (persistence — design/spec) |
| JWT, 15-min expiry | 4 spec detail | Handoff (session mechanism); behaviour captured as FR-003 |
| REST endpoint /orders | 2 suggested impl | Handoff (API design); requirement is "users SHALL place/view orders" |
| 10k users | NFR (not tech) | NFR-001 (stays in PRD) |

**PRD-safe wording (what the PRD says):** "The orders dashboard SHALL present new and updated
orders to staff in near-real-time (within 2 seconds), show current status, require
re-authentication after inactivity, and support 10,000 concurrent users." All named
technologies are recorded in the Downstream Handoff as ADR/spec candidates — none appear in a
requirement.

---

## 12. Source notes

| Source | Link | Key idea extracted | Relevance to our PRD skill | Confidence |
|--------|------|--------------------|----------------------------|-----------|
| EARS — Alistair Mavin (official) | alistairmavin.com/ears | 5 patterns + complex; ruleset (0..n preconditions, 0..1 trigger, 1 system, 1..n responses); reduces ambiguity, improves testability | Core requirement-writing notation (§6); acceptance-criteria layer | High |
| EARS — Wikipedia (RE'09 provenance; SDD use) | en.wikipedia.org/wiki/Easy_Approach_to_Requirements_Syntax | Industry adoption (NASA/Airbus/Bosch); Kiro requirements→design→tasks; comparison vs user story/Gherkin/Rupp | Boundary & AI-SDLC framing (§7, §1) | High |
| GitHub spec-kit — README | github.com/github/spec-kit | constitution→specify→clarify→plan→tasks→analyze→checklist→implement; "focus on what/why, not tech"; "checklist = unit tests for English"; clarify-before-plan gate | Skill process (§9), validation (§8), boundary (§7) | High |
| spec-kit — spec-template.md | raw.githubusercontent.com/github/spec-kit/main/templates/spec-template.md | Prioritized independently-testable user stories; FR-### "must be testable"; Key Entities "without implementation"; SC-### measurable+tech-agnostic; Assumptions | Template design (§3, §10) | High |
| spec-kit — commands/specify.md | raw.githubusercontent.com/github/spec-kit/main/templates/commands/specify.md | Max 3 `[NEEDS CLARIFICATION]`; priority scope>security>UX>tech; reasonable-defaults list; 16-item quality checklist; "think like a tester"; SC good/bad examples; A/B/C/Custom question table | Readiness (§4), clarification (§5), validation (§8) | High |
| coco-skills — EARS_NOTATION.md (Snowflake-Labs) | raw.githubusercontent.com/Snowflake-Labs/coco-skills/main/skills/spec-driven/references/EARS_NOTATION.md | WHEN/SHALL/SO THAT; 5 types + SHALL NOT; REQ-### template w/ acceptance criteria; DO/DON'T list | Requirement rules & examples (§6) | High (source) / Medium (representativeness) |
| coco-skills — spec-driven SKILL.md | raw.githubusercontent.com/Snowflake-Labs/coco-skills/main/skills/spec-driven/SKILL.md | Phased workflow with MANDATORY stopping points; explicit refusal to batch phases | Skill process & gates (§9) | High |
| Amazon Kiro — spec docs & blog | kiro.dev/docs/specs, kiro.dev/blog/property-based-testing | 3-file requirements/design/tasks split; EARS acceptance criteria; requirements as testable "properties"; analyze-requirements ambiguity pass | Tier separation (§1,§7), testability (§6), validation (§8) | High |
| OpenSpec (Fission-AI) | github.com/Fission-AI/OpenSpec | Change-based: proposal `## Why` + capability spec deltas + tasks; brownfield | Problem-justification & structure (§3) | Medium-High |
| product-manager-toolkit (spellbook) | raw.githubusercontent.com/majiayu000/spellbook/main/skills/product-manager-toolkit/SKILL.md | RICE/MoSCoW; opportunity-solution tree; hypothesis template; "problem before solution"; "always include out-of-scope"; PRD variants; pitfalls (solution-first, feature factory, metric theater) | Non-SDD PM lineage; principles (§2), discovery (§5), output modes (§9) | High (source) / Medium (representativeness) |
| ISO/IEC/IEEE 29148:2018 | (standard; summarized via Jama guide + domain knowledge) | Requirement characteristics: necessary, appropriate, unambiguous, complete, singular, feasible, verifiable, correct, conforming; set-level consistency | Quality bar behind §2, §8 | Medium (standard not opened directly; mapping via spec-kit is verbatim) |
| Jama — Requirements Mgmt & Traceability guide | jamasoftware.com/requirements-management-guide/ | RTM; bidirectional traceability; live vs after-the-fact; verification/validation; "using AI to write requirements: what works" | Traceability (§2 P8, §8) | High |
| INVEST (Bill Wake) | (agile literature) | Independent, Negotiable, Valuable, Estimable, Small, Testable | Story/backlog-slice quality bridge (§9) | High (framework) / Medium (attribution) |
| Michael Nygard — Documenting Architecture Decisions | cognitect/thoughtworks ADR writeups | ADR = one significant decision + context + consequences; append-only; downstream of requirements | Requirement-vs-ADR boundary (§7 bucket 3) | High |
| agentskills.io — Agent Skills spec + Kiro skills docs | agentskills.io/specification, kiro.dev/docs/skills | name/description rules; progressive disclosure; description is the router key; scripts for deterministic steps | Skill authoring (§9) | High |
| avo-hq requirements brainstorm (real doc) | raw.githubusercontent.com/avo-hq/avo/main/docs/brainstorms/2026-06-08-on-demand-frame-loading-requirements.md | Separates Requirements (R1..) from Key Decisions/Alternatives/Outstanding Questions; Resolve-Before-Planning vs Deferred tags | Open-questions taxonomy (§3.13, §4) | Medium |
| Rune-kit requirements fixture (real doc) | raw.githubusercontent.com/Rune-kit/rune/master/evals/converge/clean-pass/fixture/.rune/features/feedback-board/requirements.md | `AC-1.1 GIVEN..WHEN..THEN (→ FR-1, FR-2)` — acceptance criteria linked to requirement IDs | Traceability pattern (§2 P4, §10) | Medium |

**Residual gaps / caveats:**
- ISO/IEC/IEEE 29148 was not opened verbatim in-session; the characteristic list is
  well-established and the spec-kit checklist items that instantiate it are verbatim. A
  direct standard fetch would strengthen a formal citation.
- coco-skills, spellbook, avo-hq, and Rune-kit are real but not universal standards — cited
  as strong *examples* of patterns, not as normative authorities. The normative weight sits
  with EARS, ISO 29148, spec-kit, Kiro, and the discovery literature.
```
