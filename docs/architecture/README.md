# System architecture

The **living reference for what the running system is right now** — what components exist, where their boundaries are, how a request flows through them, and how they are deployed. This is the cross-service view that no single service's docs can own, and the first thing to read to orient in the system.

| Track                            | Question it answers              | Lifecycle             |
| -------------------------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/)                | *Why did we choose this?*        | Append-only, dated    |
| [conventions/](../conventions/)  | *What is the rule, right now?*   | Living, edit-in-place |
| [specs/](../specs/)              | *How is this one feature built?* | Living per spec       |
| architecture/                    | *What is the system right now?*  | Living reference      |

Architecture views **stitch** the decisions and designs together — they link the deciding ADRs (via each view's `Tracks` field) and the relevant specs/conventions, and never restate them. For the *internal* shape of one service, see that service's docs (e.g. [`services/portal/docs/`](../../services/portal/docs/README.md)) and the per-service pattern in [`conventions/go/service-architecture.md`](../conventions/go/service-architecture.md).

## Views

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one view**: front matter (`Status`, `Authors`, `Last reviewed`, `Tracks`), then **Purpose / Diagram / Components / Boundaries / Open questions / References**, with an "exists today vs planned" annotation.

| View                                             | Question it answers                                                                                 | Status           |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------- | ---------------- |
| [system-overview.md](system-overview.md)         | What are the components, their responsibilities and boundaries, and the external dependencies?      | Accepted         |
| [request-flow.md](request-flow.md)               | How does a request traverse delivery → app → infra → database, and where is the tenant scope bound? | Accepted         |
| [deployment-topology.md](deployment-topology.md) | How is the system deployed and wired locally (Postgres, ZITADEL, the reverse proxy)?                | Accepted         |


## Layout

One view per file, kebab-case, navigable via the Views index above. Group by area only when a single system grows more views than fit one flat list.

```
docs/architecture/
├── README.md                  # this file — index + lifecycle
├── TEMPLATE.md                # skeleton for one view
└── <view>.md                  # one system view, standalone
```

## Naming

```
docs/architecture/<view>.md
```

- **Kebab-case**, descriptive: `system-overview.md`, `request-flow.md`, `deployment-topology.md`. Read the filename, know the view.
- **No numbering** — views are living references, not append-only. Numbering belongs to ADRs.
- **One view per file** — atomic, linkable, standalone.

## Lifecycle

Architecture views are a **living reference** — there is no `Draft → Implemented` arc; a view tracks reality and is never "done".

- **The system changed (component added/removed/rewired)** — edit the affected view in place, bump `Last reviewed`, and update the Mermaid diagram beside the prose so they never drift.
- **Exists vs planned** — a view carries an explicit "exists today vs planned" annotation instead of a single misleading status, because the system is mid-build.
- **A view is retired** — set `Status: Deprecated`, explain what replaced it, and leave the file so old links resolve. Remove its row from the Views index.

A new ADR is required only when the architecture changes by a **decision** (a new service, a new external dependency, a changed boundary) — record the decision in [`adrs/`](../adrs/), then reflect it here. Routine "the diagram now matches the code" edits need no ADR.

## Diagram convention

Diagrams are authored as fenced ` ```mermaid ` code blocks — plain text, diffable, no toolchain. GitHub renders them natively; the workspace docs site renders them via `@docusaurus/theme-mermaid` (`markdown.mermaid: true` in `apps/workspace-docs/docusaurus.config.ts`). Prefer Mermaid over committed image binaries so diagrams stay reviewable in PRs and never drift from the prose beside them.

## Writing a new view

```bash
VIEW=data-flow                              # the view, kebab-case
cp docs/architecture/TEMPLATE.md "docs/architecture/${VIEW}.md"
$EDITOR "docs/architecture/${VIEW}.md"
```

Then add a row to the Views index above, and point the view's `Tracks` field at the ADR(s) it realises.

## See also

- [ADR index](../adrs/README.md) — the decisions these views realise (esp. [ADR-0010](../adrs/0010-architecture-as-lifecycle-track.md), which made architecture its own track).
- [Specs index](../specs/README.md) — per-feature designs (the neighbouring track).
- [Root README](../../README.md) · [Root AGENTS.md](../../AGENTS.md) — workspace layout and folder map.
