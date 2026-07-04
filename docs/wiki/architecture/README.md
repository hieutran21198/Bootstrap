# Architecture wiki

System-wide architecture views live here as informal, living quick-reference pages (ADR-0020). They describe the current shape of the workspace, but they are not a formal docs track: no required template, status lifecycle, or numbering.

Recommended habits from the retired track still apply when useful: one view per file, fenced `mermaid` diagrams, an honest exists-today-vs-planned annotation, and links to the ADRs/specs/conventions that explain the underlying decisions.

## Views

| View | Question it answers |
| ---- | ------------------- |
| [system-overview.md](system-overview.md) | What are the components, their responsibilities and boundaries, and the external dependencies? |
| [request-flow.md](request-flow.md) | How does a request traverse delivery → app → infra → database, and where is the tenant scope bound? |
| [deployment-topology.md](deployment-topology.md) | How is the system deployed and wired locally (Postgres, ZITADEL, the reverse proxy)? |

## See also

- [ADR-0020](../../adrs/0020-move-architecture-views-into-wiki.md) — moved architecture views into the wiki.
- [ADR-0010](../../adrs/0010-architecture-as-lifecycle-track.md) — superseded rationale for keeping system-wide views out of specs.
- [Wiki policy](../README.md) — informal notes have no template/status lifecycle.
