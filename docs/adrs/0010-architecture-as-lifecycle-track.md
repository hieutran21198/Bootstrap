# 0010. Architecture is its own top-level docs track

- **Status**: Superseded by ADR-0020
- **Date**: 2026-06-29
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace docs taxonomy is **lifecycle-based, not topic-based**: six top-level tracks under `docs/` (`adrs/`, `conventions/`, `specs/`, `glossary/`, `findings/`, `debt/`), each defined by a distinct lifecycle and carrying its own `README.md` + `TEMPLATE.md`. The system-architecture documentation (component map, request flow, deployment topology) was first placed under `docs/specs/architecture/` because the spec track names "feature/**system** designs" as in scope.

That placement has a real lifecycle mismatch. A spec is a *single feature's design* that moves `Draft → Accepted → Implemented` and is, in principle, "done." The architecture view is the opposite: a **standing, perpetually-living reference** for what the running system *is right now* — never "done," edited every time a component ships, and the first thing a new contributor or AI agent should read to orient. Carrying a `Status: Implemented` on a document that is never finished is a loose fit, and burying the system map two levels deep inside the spec track makes the single most important orientation surface hard to find.

The goal: give the architecture view a home whose lifecycle actually matches it, and make "where is the current architecture?" answerable in one hop — for humans and for AI agents reading the tree.

## Decision

**We will promote architecture to a seventh top-level docs track at `docs/architecture/`, with a "living reference" lifecycle distinct from specs.** It is a first-class track like the other six: its own `README.md` (index + lifecycle), its own `TEMPLATE.md`, registration in `docs/AGENTS.md`, the root `README.md`, and root `AGENTS.md`.

The track holds the cross-service, big-picture views of the running system (currently: `system-overview.md`, `request-flow.md`, `deployment-topology.md`). Each view:

- Is a **living reference** — edited in place as the system changes; `Last reviewed` bumped each time. There is no `Draft → Implemented` arc; a view carries an explicit "exists today vs planned" annotation instead of a single misleading status.
- **Stitches, never restates** — links the deciding ADRs via a `Tracks` field and links the relevant specs/conventions, rather than duplicating them.
- Authors diagrams as fenced `mermaid` blocks (per the diagram convention already wired into the docs site).

Boundary with the neighbours: `adrs/` = *why* (a decision, append-only); `specs/` = *how this one feature is built* (a per-feature design with a finish line); `architecture/` = *what the system is right now* (a living, system-wide reference). A document that describes one feature's design stays a spec; a document that describes the system's shape is an architecture view.

This refines the taxonomy described in [ADR-0007](0007-nix-devenv-developer-environment.md)'s docs model and changes the spec track's scope: `specs/` is now "feature designs," not "feature/system designs."

## Consequences

- **Positive**:
  - The current architecture is discoverable in one hop (`docs/architecture/`) — the orientation surface humans and AI agents reach for is top-level, not buried under `specs/`.
  - The lifecycle finally matches the artifact: a living reference, not a spec with a phantom "Implemented" status.
  - Clear track boundaries reduce mis-filing: system-shape docs have an obvious home distinct from per-feature specs and from decisions.
- **Negative**:
  - The taxonomy grows from six tracks to seven — more surface to keep registered across `docs/AGENTS.md`, both root docs, and the docs site. Every "six tracks" mention must become "seven."
  - One more `README.md` + `TEMPLATE.md` to maintain.
- **Neutral**:
  - The four existing files move from `docs/specs/architecture/` to `docs/architecture/`; their inbound/outbound relative links shift by one directory level. Git history is preserved via `git mv`.
  - `specs/` returns to "no specs yet" until a genuine per-feature spec is written; the portal's service-local `database-schema.md` spec is unaffected.

## Alternatives considered

- **Keep architecture under `docs/specs/architecture/`.** Rejected: the lifecycle mismatch (a never-"done" living reference wearing a spec's `Draft → Implemented` status) and the discoverability cost (buried two levels deep) are exactly what prompted this change.
- **Put the architecture overview in an ADR.** Rejected: ADRs are append-only decisions; a system map is edited continuously as components ship. The decisions *behind* the architecture stay in ADRs; the views link to them.
- **Make it a `conventions/` topic.** Rejected: conventions are *rules to follow* (imperative, enforced); an architecture view is a *description of what exists*, not a rule.
- **Leave it a topic folder, not a track (e.g. `docs/architecture/` with no README/TEMPLATE/registration).** Rejected: a half-registered folder is invisible to the governance files and the docs site's track model; first-class status is what makes it discoverable and maintainable.

## References

- [ADR-0007](0007-nix-devenv-developer-environment.md) — the Nix/devenv + docs model this taxonomy lives within.
- [ADR-0003](0003-service-architecture.md) · [ADR-0006](0006-zitadel-identity-auth.md) · [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) · [ADR-0009](0009-safe-system-scope-rls.md) — the decisions the architecture views stitch together.
- [docs/architecture/README.md](../architecture/README.md) — the new track's index + lifecycle.
- [docs/AGENTS.md](../AGENTS.md) — global docs taxonomy (updated: six → seven tracks).
- [docs/specs/README.md](../specs/README.md) — spec track (scope narrowed to feature designs).
