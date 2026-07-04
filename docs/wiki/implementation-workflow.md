# Implementation Workflow

> Informal quick-reference (outside the 7 formal `docs/` tracks). This is the
> operating model for how humans and AI agents run the SDLC pipeline. State
> lifecycle + evidence-at-close:
> [`evidence-based-delivery.md`](../conventions/delivery/evidence-based-delivery.md)
> ([ADR-0017](../adrs/0017-evidence-based-delivery.md)). Full RACI:
> [`agile-roles.md`](agile-roles.md).

## Pipeline

Every non-trivial change walks seven stages. The sequence is fixed; what varies
is how much ceremony each stage earns. Three human authority gates sit inline —
nothing crosses them without human approval.

```mermaid
flowchart LR
    IDEA((Idea))

    subgraph project["Project SoT — docs/"]
        PRD["PRD<br/>prds/"]
        SPEC["Spec + ADR<br/>specs/ + adrs/"]
        LEARN["Finding / Debt / Wiki<br/>findings/ + debt/ + wiki/"]
    end

    subgraph operation["Operation SoT — Linear"]
        TASKS["Epic + Tasks<br/>(AC, owner, docs/ ref)"]
        CLOSE["Evidence + Close"]
    end

    subgraph repo["Code Repo"]
        IMPL["Code + PR"]
        PREP["Prepare Release<br/>(version, changelog, staged config)"]
        SHIP["Tag + Deploy"]
    end

    IDEA -->|"Orchestrator routes<br/>Researcher discovers<br/>Scribe drafts"| PRD
    PRD --> G1{"Human:<br/>Accept PRD?"}
    G1 -->|"Architect designs"| SPEC
    G1 -->|"Scribe files"| TASKS
    SPEC --> TASKS
    TASKS -->|"Engineers build"| IMPL
    IMPL -->|"Architect reviews"| G2{"Human:<br/>DoD sign-off?"}
    G2 -->|"Release-Eng prepares"| PREP
    PREP --> G3{"Human:<br/>Release go/no-go?"}
    G3 -->|"Release-Eng executes"| SHIP
    SHIP -->|"Scribe attaches evidence"| CLOSE
    CLOSE -->|"Scribe records"| LEARN
    LEARN -.->|feedback| IDEA

    classDef gate fill:#fff4b3,stroke:#b38b00,stroke-width:1px,color:#3a2e00;
    class G1,G2,G3 gate;
```

### Feature lifecycle

The sequence diagram walks one feature end-to-end, showing which actor writes
what, where, at each stage.

```mermaid
sequenceDiagram
    participant H as Human (PO)
    participant ORC as Orchestrator
    participant RES as Researcher / Explorer
    participant SCR as Scribe
    participant ARC as Architect
    participant ENG as Engineers
    participant REL as Release-Eng
    participant DOCS as docs/
    participant LIN as Linear
    participant REPO as Code Repo

    Note over H,REPO: Stage 1 — Idea
    H->>ORC: goal or need
    ORC->>RES: discover context
    RES-->>ORC: sourced findings

    Note over H,REPO: Stage 2 — PRD
    ORC->>SCR: draft PRD
    SCR->>DOCS: write PRD (prds/)
    DOCS-->>H: PRD ready for review
    H->>DOCS: accept PRD
    Note right of H: GATE — PRD acceptance

    Note over H,REPO: Stage 3 — Epic / Task / Spec
    ORC->>ARC: design brief
    ARC->>DOCS: write Spec + ADR (specs/, adrs/)
    ORC->>SCR: file work items
    SCR->>LIN: create epic + tasks (AC, owner, docs/ ref)
    LIN-->>ENG: assigned tasks

    Note over H,REPO: Stage 4 — Implementation
    ORC->>ENG: delegation brief
    ENG->>REPO: implement + open PR

    Note over H,REPO: Stage 5 — Review
    ORC->>ARC: review PR (writer ≠ reviewer)
    ARC-->>REPO: technical verdict
    REPO-->>H: PR for acceptance
    H->>REPO: DoD sign-off
    Note right of H: GATE — product / DoD sign-off

    Note over H,REPO: Stage 6 — Release
    ORC->>REL: prepare release
    REL->>REPO: version bump, changelog, staged config
    REPO-->>H: release candidate for approval
    H->>REL: release go / no-go
    Note right of H: GATE — release go / no-go
    REL->>REPO: tag + deploy

    Note over H,REPO: Stage 7 — Learning
    SCR->>LIN: attach evidence (tests, PR link, docs/ pointer)
    SCR->>LIN: close tasks
    SCR->>DOCS: record finding / debt / wiki
    DOCS-->>ORC: feedback informs next cycle
```

## Sources of truth

The pipeline touches two authoritative stores:

- **Project SoT (`docs/`)** — the durable record of what and why: PRDs, specs,
  ADRs, conventions, glossary, findings, debt, wiki (incl.
  [`architecture/`](architecture/)).
- **Operation SoT (Linear)** — the live delivery state: who, when, sprint,
  status.

Neither blindly overwrites the other. The ownership rules and sync protocol are
in [`jira-linear-sync.md`](jira-linear-sync.md) (Rules 1-3).

## Operating rules

### Rule 4 — Every task must trace back

Every tracked item must trace back to its `docs/` source record and carry
evidence at close. A task with no `docs/` reference is not filed.

The chain depends on the work type:

- **Feature work:** `PRD -> Spec -> Epic -> Task -> Code/PR -> Release`
- **Debt / finding / chore work:** starts at the debt entry (`debt/`) or finding
  (`findings/`), not a PRD — the rest of the chain still applies.

The links travel in two directions via front-matter fields the track formats
define:

- **Forward** (`Tracks`, `Realized by`): a spec's `Tracks` field cites the PRD;
  a PRD's `Realized by` field lists the specs, ADRs, and Linear issues that
  realise it. These fill over time as downstream work materialises.
- **Back** (evidence at close): when a Linear task moves to Done, it carries raw
  verification output, the merged PR / commit link, and the `docs/` pointer per
  [`evidence-based-delivery.md`](../conventions/delivery/evidence-based-delivery.md).

### Rule 5 — Agents do not invent authority

Agents draft, inspect, implement, and propose. Three decisions stay with the
human:

1. **Product intent** — what we build and why (PRD acceptance).
2. **Priority and sprint scope** — what we build next.
3. **Release go/no-go** — what we ship.

An agent may recommend; a human decides. The full RACI lives in
[`agile-roles.md`](agile-roles.md).

> Rules 1-3 (Project owns product truth; Jira/Linear owns delivery truth; No
> blind two-way sync) live in [`jira-linear-sync.md`](jira-linear-sync.md).

## Actors by stage

| # | Stage | Artifact | Where | Actor(s) | Human gate |
|---|-------|----------|-------|----------|------------|
| 1 | **Idea** | Raw signal (need, debt encounter, finding) | — | Orchestrator routes; Researcher / Explorer discover | — |
| 2 | **PRD** | Requirements (EARS, solution-free) | [`prds/`](../prds/) | Scribe drafts; Researcher supplies domain input | **PRD acceptance** |
| 3 | **Epic / Task / Spec** | Feature design + work items | [`specs/`](../specs/) + [`adrs/`](../adrs/) + Linear | Architect designs; Scribe files items (AC, owner, docs/ ref) | — |
| 4 | **Implementation** | Code + PR | Code repo | Engineers (backend / frontend) | — |
| 5 | **Review** | Technical verdict + DoD | Code repo | Architect reviews (writer ≠ reviewer) | **Product / DoD sign-off** |
| 6 | **Release** | Prepare (version, changelog, staged config) then tag + deploy after gate | Code repo | Release-Eng prepares; Human authorizes; Release-Eng executes | **Release go/no-go** |
| 7 | **Learning** | Investigation + follow-up | [`findings/`](../findings/) + [`debt/`](../debt/) + [`wiki/`](./) | Scribe records; Architect promotes to ADR/spec when needed | — |

## References

- State lifecycle + evidence gate: [`../conventions/delivery/evidence-based-delivery.md`](../conventions/delivery/evidence-based-delivery.md) · [ADR-0017](../adrs/0017-evidence-based-delivery.md)
- Track formats + lifecycle: [`../AGENTS.md`](../AGENTS.md)
- RACI: [`agile-roles.md`](agile-roles.md)
- Agent capabilities + posture: [`agent-team.md`](agent-team.md)
- Two-sources-of-truth sync (Rules 1-3): [`jira-linear-sync.md`](jira-linear-sync.md)
- Architecture views: [`architecture/`](architecture/)
