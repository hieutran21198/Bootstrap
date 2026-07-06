# Product Requirement Documents

PRDs capture **product and domain intent** — the problem, the people, and the outcomes a capability must deliver — *before* any decision or design. They are deliberately **solution-free**: no technology, no architecture, no "how". A PRD is the upstream source the [`adrs/`](../adrs/), [`specs/`](../specs/), and [`glossary/`](../glossary/) tracks flow from.

| Track                           | Question it answers              | Lifecycle             |
| ------------------------------- | -------------------------------- | --------------------- |
| prds/                           | *What must be true, and why?*    | Living per PRD        |
| [adrs/](../adrs/)               | *Why did we choose this?*        | Append-only, dated    |
| [specs/](../specs/)             | *How is this built?*             | Living per spec       |
| [glossary/](../glossary/)       | *What does this term mean here?* | Living, edit-in-place |

A PRD is the **single source of truth for a capability's requirements**. When a new requirement appears, it is captured *here first*, then propagated downstream — edit the living spec, and write a new ADR when a *decision* changes. Downstream docs link **back** to the PRD via their `Tracks` field; the PRD lists them under `Realized by`. The PRD never restates a spec's design or an ADR's decision.

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one PRD**: front matter (`Status`, `Authors`, `Last reviewed`, `Realized by`), then the required sections in order:

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

The shape blends established "intent-first" practice:

- **What/why before how** mirrors Amazon [*Working Backwards* (PR-FAQ)](https://www.allthingsdistributed.com/2006/11/working-backwards.html) and Basecamp [Shape Up](https://basecamp.com/shapeup) pitches — requirements are written in problem-space, never solution-space.
- **Success criteria are measurable, technology-agnostic outcomes** — user/business-facing metrics with a baseline/target where relevant, never internal implementation metrics.
- **Requirements use stable IDs and [EARS](https://alistairmavin.com/ears/)** (Easy Approach to Requirements Syntax) where it fits — `WHEN <condition> THE SYSTEM SHALL <observable outcome>` — to stay testable, observable, singular, and technology-free.
- **Scope, assumptions, and constraints are explicit** — readers can see what is in, what is out, and which reasonable defaults or binding facts downstream authors may rely on.
- **`[NEEDS CLARIFICATION: …; recommended default: …]` markers** (from [GitHub spec-kit](https://github.com/github/spec-kit)) make unknowns explicit and gate the `Draft → Accepted` transition, so downstream authors never guess. Drafts should carry at most 3 markers; all must be resolved before acceptance.
- **Downstream Handoff names decision candidates, not decisions** — it routes ADR/spec topics and the requirement IDs they serve without choosing technologies.
- **The embedded review checklist** treats requirement quality like "unit tests for English": IDs present, wording measurable, scope bounded, no implementation leakage, and backlinks ready.

## Layout

One capability per file. Group by area when more than a handful exist.

```text
docs/prds/
├── README.md                  # this file — Index
├── TEMPLATE.md                # skeleton for one PRD
└── <area>/                    # optional grouping by domain
    └── <capability>.md        # one PRD, standalone
```

Two-tier: workspace-wide product intent lives here; product intent that dies with one service lives under `services/<name>/docs/prds/` and defers format + lifecycle authority to this README.

## Naming

```text
docs/prds/<capability>.md            # top-level PRD
docs/prds/<area>/<capability>.md     # grouped under an area
```

- **Kebab-case**, descriptive: `auth-and-identity.md`, `billing-and-seats.md`. Read the filename, know the capability.
- **No numbering** — PRDs are living per capability, not append-only. Numbering belongs to ADRs.
- **One capability per file** — atomic, linkable, standalone.

## Lifecycle

PRDs are **living per PRD**. `Status` transitions:

- `Draft` — intent under discussion; requirements still forming.
- `Accepted` — requirements agreed; downstream ADRs/specs may now be authored.
- `Delivered` — every requirement is realized by a shipped spec/ADR.
- `Superseded by prds/<other>.md` — a newer PRD replaces this one.
- `Deprecated` — the capability was dropped; the PRD is retained as history.

**`Draft → Accepted` gate** — a PRD may not move to `Accepted` while any of these hold:

1. an open `[NEEDS CLARIFICATION: …]` marker remains anywhere in the file;
2. it names a technology, API, schema, or design (that is the "how" — move it to a spec/ADR);
3. a success criterion is unmeasurable, technology-specific, or framed as an internal implementation metric;
4. scope lacks explicit **In scope** and **Out of scope** boundaries;
5. assumptions and constraints are missing, silent, or used to choose a design;
6. **Downstream Handoff** names a chosen technology/design instead of a neutral ADR/spec candidate tied to requirement or success-criterion IDs;
7. it uses a domain term that is neither defined in [`glossary/`](../glossary/) nor nominated under **Domain intent**.

Move forward through statuses; bump `Last reviewed` on every material edit. After `Delivered`, a **material** intent change is captured by **superseding** with a new PRD (leave the old one, set `Status: Superseded by …`); a clarification is an in-place edit + `Last reviewed` bump.

### Migration policy for ADR-0022

[ADR-0022](../adrs/0022-expand-prd-required-sections.md) expanded the required section set. The expanded template applies to PRDs authored or materially edited after ADR-0022. Existing accepted PRDs (`identity-and-access.md`, `backoffice-and-portal.md`) are grandfathered and may be backfilled opportunistically during future material edits or a dedicated cleanup; they are not reopened solely because their historical section shape differs.

## Writing a new PRD

```bash
AREA=                                                 # optional; omit for top-level PRDs
CAP=billing-and-seats                                 # kebab-case capability

DIR="docs/prds${AREA:+/$AREA}"
mkdir -p "$DIR"
cp docs/prds/TEMPLATE.md "$DIR/${CAP}.md"
$EDITOR "$DIR/${CAP}.md"
```

Then, as downstream docs are authored, keep the backlinks in sync: each ADR/spec sets `Tracks: prds/<capability>.md`, and this PRD lists them under `Realized by`. Add the PRD to the Index below.

## Index

| PRD | Status | Realized by |
| --- | ------ | ----------- |
| [backoffice-and-portal.md](backoffice-and-portal.md) | Accepted | ADR-0013 *(planned)*, portal & backoffice specs *(planned)* |
| [identity-and-access.md](identity-and-access.md) | Accepted | ADR-0013 *(planned)*, `services/portal/docs/specs/identity-provisioning.md` *(planned)* |
