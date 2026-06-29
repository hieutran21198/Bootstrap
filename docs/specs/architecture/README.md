# System architecture

The holistic, big-picture view of the **running system** — what components exist, where their boundaries are, how a request flows through them, and how they are deployed. This is the cross-service view that no single service's docs can own.

Read this when you need to understand the system as a whole. For the *internal* shape of one service, see that service's docs (e.g. [`services/portal/docs/`](../../../services/portal/docs/README.md)) and the per-service pattern in [`conventions/go/service-architecture.md`](../../conventions/go/service-architecture.md). For *why* a piece is shaped the way it is, follow the linked ADRs — these views stitch the decisions together, they do not restate them.

## Views

| View | Question it answers | Status |
| ---- | ------------------- | ------ |
| [system-overview.md](system-overview.md) | What are the components, their responsibilities and boundaries, and the external dependencies? | Accepted |
| [request-flow.md](request-flow.md) | How does a request traverse delivery → app → infra → database, and where is the tenant scope bound? | Accepted |
| [deployment-topology.md](deployment-topology.md) | How is the system deployed and wired locally (Postgres, ZITADEL, the reverse proxy)? | Accepted |

## Scope

- **System-wide, not service-local.** Anything that spans services, shared packages, `deploy/`, and external systems belongs here. Anything that dies with one service belongs in that service's docs.
- **Design, not decision.** These are living specs (the *how*); the deciding ADRs (the *why*) are linked via each view's `Tracks` field. When the system changes, edit the view and bump `Last reviewed`.
- **Stitches, never duplicates.** A view links to ADR-0003 (service pattern), ADR-0006 (ZITADEL), ADR-0008/0009 (tenant isolation), and the portal schema spec rather than copying them.

## Diagram convention

Diagrams are authored as fenced ` ```mermaid ` code blocks — plain text, diffable, no toolchain. GitHub renders them natively; the workspace docs site renders them via `@docusaurus/theme-mermaid` (`markdown.mermaid: true` in `apps/workspace-docs/docusaurus.config.ts`). Prefer Mermaid over committed image binaries so diagrams stay reviewable in PRs and never drift from the prose beside them.

## See also

- [Specs index](../README.md) — the track this area lives in.
- [ADR index](../../adrs/README.md) — the decisions these views realise.
- [Root README](../../../README.md) · [Root AGENTS.md](../../../AGENTS.md) — workspace layout and folder map.
