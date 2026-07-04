# Agile Roles — Practitioner → Responsibility → Owner (RACI)

> Informal quick-reference (outside the seven formal `docs/` tracks). How agile
> practitioner roles map onto this workspace's agent roster **plus the human**.
> This is the *role/responsibility* view; [`agent-team.md`](agent-team.md) is the
> *capability/posture* view (tool wiring). The machine source of truth is the
> agent modules in [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/).

**Key principle: agents execute and advise; the human holds product and release
accountability.** An AI never decides product intent, grants final product
acceptance, or authorizes a release. Every responsibility below has exactly one
`A` (accountable) — and where the outcome is product or shipping, that `A` is the
human.

## RACI legend

- **R** — does the work.
- **A** — accountable / owns the outcome (exactly one per responsibility).
- **C** — consulted (input sought before the work).
- **I** — informed (told after).

## Core responsibilities

| # | Responsibility | Agile role | Primary owner (R) | Supporting (C) | Accountable (A) |
|---|----------------|-----------|-------------------|----------------|-----------------|
| 1 | Requirements & acceptance criteria | Product Owner | **Human (PO)** | `scribe` (captures/tracks as work items w/ criteria), `researcher` (domain input) | **Human** |
| 2 | Architecture decisions & ADRs | Architect / Tech Lead | **`architect`** | `researcher` (options), `explorer` (repo impact) | **`architect`** |
| 3a | Final approval — *technical* review gate | Architect / Tech Lead | **`architect`** (writer ≠ reviewer) | `orchestrator` (assembles raw proof, does not approve) | **`architect`** |
| 3b | Final approval — *product / Definition-of-Done* | Product Owner | **Human (PO)** | `architect` (technical verdict), `scribe` (DoD tracking) | **Human** |
| 4 | Coordination & blocker escalation | Scrum Master / Delivery Lead | **`orchestrator`** (plans, routes Delegation Briefs, keeps the index, enforces writer ≠ reviewer) | Human (escalation target) | **`orchestrator`** (flow) |
| 5 | CI/CD & release coordination | Release Manager / Engineer | **`release-engineer`** (CI/CD mechanics, git-hook/branch-protection wiring, versioning/tagging/changelog, `deploy/` config) | `backend-engineer` (build/tooling) | **Human** (release go/no-go) |

Track homes: #1 → [`../prds/`](../prds/) (EARS); #2 → [`../adrs/`](../adrs/),
[`../specs/`](../specs/), [`architecture/`](architecture/). On #5 the agent
**executes** release mechanics but does **not** authorize the release.

## Delivery / doer roles (the rest of the team)

- **Development (build / refactor)** → Dev Team → `backend-engineer` (Go:
  `packages/go`, `services/portal`, `tools`) + `frontend-engineer` (`apps/` UI).
- **Discovery** → `explorer` (where/how in *this* repo) + `researcher`
  (external / library / domain, read-only).
- **Delivery record / tracking** → `scribe` (PRDs → work items, roadmap, debt
  register, status).

## What stays with the human

These are never delegated to an AI — because an AI must not decide product intent
or authorize shipping:

- **Product intent + acceptance criteria** (#1).
- **Final product / Definition-of-Done sign-off** (#3b).
- **Release go/no-go** (#5).

## Open questions

- None — this records the settled model. Capability, posture, and tool-wiring
  details are not decided here; they live in [`agent-team.md`](agent-team.md) and
  the Nix agent modules.

## References

- Capability / posture view: [`agent-team.md`](agent-team.md)
- Machine source of truth (identity / posture / prompt): [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/)
- Delegation protocol rationale (why writer ≠ reviewer, why delegate): [`../debt/agent-orchestration-no-delegation.md`](../debt/agent-orchestration-no-delegation.md)
