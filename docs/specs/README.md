# Specifications

Specs describe **how** something is built — the design contract for a feature, a service, or a cross-cutting change. Compare to [`adrs/`](../adrs/), which records the **decision** to build it, and [`conventions/`](../conventions/), which captures the rules that apply once it ships.

| Track                            | Question it answers              | Lifecycle             |
| -------------------------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/)                | *Why did we choose this?*        | Append-only, dated    |
| [conventions/](../conventions/)  | *What is the rule, right now?*   | Living, edit-in-place |
| specs/                           | *How is this built?*             | Living per spec       |
| [glossary/](../glossary/)        | *What does this term mean here?* | Living, edit-in-place |

A spec is the **single source of truth for an in-flight or shipped design**. ADRs cite specs; commit messages and PRs cite specs; code comments cite specs. When two readers disagree on the design, the spec is the tiebreaker.

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one spec**: front matter (`Status`, `Authors`, `Last reviewed`, `Tracks`), then the sections — **Problem / Goals / Non-goals / Background / Design / Alternatives considered / Open questions / Implementation plan / References**.

The shape blends two canonical formats:

- **Section order** (Problem → Goals → Design → Alternatives → Open questions) follows the [Google design-doc convention](https://www.industrialempathy.com/posts/design-docs-at-google/).
- **`Alternatives considered`** and the link back to a deciding ADR mirror the ADR template already in use ([`adrs/TEMPLATE.md`](../adrs/TEMPLATE.md)), so a contributor moving between the two tracks reads the same vocabulary.

## Layout

One feature or subsystem per file. Group by area when more than a handful exist.

```
docs/specs/
├── README.md                  # this file — Index
├── TEMPLATE.md                # skeleton for one spec
└── <area>/                    # optional grouping by service or domain
    └── <feature>.md           # one spec, standalone
```

## Naming

```
docs/specs/<feature>.md             # top-level spec
docs/specs/<area>/<feature>.md      # grouped under an area
```

- **Kebab-case**, descriptive: `auth-token-rotation.md`, `portal-cqrs-bus.md`. Read the filename, know the spec.
- **No numbering** — specs are living per feature, not append-only. Numbering belongs to ADRs.
- **One spec per file** — atomic, linkable, standalone.

## Lifecycle

Specs are **living per spec**. `Status` transitions:

- `Draft` — under discussion, not yet building.
- `Accepted` — design agreed, implementation in flight.
- `Implemented` — design has shipped and matches reality.
- `Superseded by specs/<other>.md` — a newer spec replaces this one.
- `Deprecated` — the feature was removed; the spec is retained as history.

Move forward through statuses; bump `Last reviewed` on every material edit. Material design changes after `Implemented` need a new ADR plus either a new spec or an in-place revision that keeps `Status: Implemented` and records the change in `Open questions` → *Resolved*.

A spec stays in the repo even after the feature is removed (`Status: Deprecated`); old links must keep resolving.

## Writing a new spec

```bash
AREA=portal                                                            # optional, omit for top-level specs
FEATURE=cqrs-bus                                                       # kebab-case

mkdir -p "docs/specs/${AREA}"                                          # skip if the area already exists, or omit entirely
cp docs/specs/TEMPLATE.md "docs/specs/${AREA}/${FEATURE}.md"
$EDITOR "docs/specs/${AREA}/${FEATURE}.md"
```

Then cross-link: the spec's `Tracks` field points at the ADR (or ticket) that authorised the work; the ADR's *References* points back at the spec. Add the spec to the Index below.

## Index

| Spec | Status | Tracks |
| ---- | ------ | ------ |
| [architecture/](architecture/README.md) — system architecture (area) | — | — |
| [architecture/system-overview.md](architecture/system-overview.md) | Accepted | ADR-0003, ADR-0006, ADR-0008 |
| [architecture/request-flow.md](architecture/request-flow.md) | Accepted | ADR-0003, ADR-0008, ADR-0009 |
| [architecture/deployment-topology.md](architecture/deployment-topology.md) | Accepted | ADR-0006 |
