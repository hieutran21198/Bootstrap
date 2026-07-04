# 0020. Move architecture views into the wiki

- **Status**: Accepted
- **Date**: 2026-07-04
- **Deciders**: workspace owner
- **Supersedes**: ADR-0010
- **Superseded by**: -

## Context

[ADR-0010](0010-architecture-as-lifecycle-track.md) created `docs/architecture/` because the system-wide architecture views had a real lifecycle mismatch with `docs/specs/`: a component map, request flow, or deployment topology is a living orientation surface, not a feature design that reaches `Implemented`. That ADR also optimized for discoverability by making architecture a top-level formal track with a README, template, front-matter lifecycle, and registration in the docs taxonomy.

The workspace owner's source-of-truth model has since become sharper: decisions belong in ADRs, per-feature designs belong in specs, standing rules belong in conventions, and durable project knowledge that is meant for quick orientation belongs in the informal wiki. The current architecture views are durable project knowledge. They stitch together decisions and current shape, but they are not themselves decisions, rules, or feature designs.

Keeping a formal architecture track now adds governance weight that does not buy enough value: a template, front-matter lifecycle fields, and track-specific policy make the pages look more formal than the owner wants them to be. The useful habits from the track still stand — one view per file, Mermaid diagrams, and honest exists-today-vs-planned annotation — but they should be recommendations for wiki pages, not an enforced document lifecycle.

## Decision

We will retire the formal `docs/architecture/` track and move the system-wide architecture views to `docs/wiki/architecture/` as living, informal quick-reference pages.

The current views move as-is in substance:

- `system-overview.md`
- `request-flow.md`
- `deployment-topology.md`

`docs/wiki/architecture/` has no formal template, status lifecycle, or required front matter. Architecture pages should continue to use the proven habits from ADR-0010 where they help readers: keep one view per file, prefer fenced `mermaid` diagrams, annotate what exists today versus what is planned, and link to ADRs/specs/conventions instead of restating them.

`docs/architecture/` remains only as compatibility stubs so old links keep resolving. Its template is retained with a retired-by-ADR-0020 notice and must not be used for new views.

## Consequences

- **Positive**:
  - The docs taxonomy matches the owner's source-of-truth model: ADRs hold decisions, specs hold feature designs, and wiki pages hold durable project knowledge used for quick orientation.
  - Architecture views lose unnecessary lifecycle ceremony while keeping the practical habits that make them readable and reviewable.
  - The wiki becomes the single informal surface for at-a-glance system knowledge, including architecture.
- **Negative**:
  - Architecture pages no longer have track-level enforcement for front matter, required sections, or `Last reviewed` updates; reviewers must rely on page quality rather than a formal lifecycle.
  - Generated or cached workspace guidance that still mentions `docs/architecture/` must be regenerated or updated to point at `docs/wiki/architecture/`.
- **Neutral**:
  - ADR-0010 is superseded, but its rationale still explains why these pages do not belong in specs.
  - Existing `docs/architecture/` links keep resolving through stubs instead of deletions.
  - Relative links in the moved pages shift one level deeper under `docs/wiki/architecture/`.

## Alternatives considered

- **Keep `docs/architecture/` as a formal top-level track.** Rejected because the formal template and lifecycle now conflict with the owner's simpler source-of-truth model for architecture as wiki knowledge.
- **Move the views back under `docs/specs/`.** Rejected for the same reason ADR-0010 rejected it: system-wide views are living references, while specs describe one feature's design with a finish line.
- **Record the current architecture in ADRs.** Rejected because ADRs are append-only decisions. The decisions behind the architecture stay in ADRs; the current shape changes in place.
- **Keep `docs/architecture/` as an informal non-track folder.** Rejected because an untracked top-level `architecture/` folder would preserve the old discoverability path while blurring whether it is still a formal track. Putting the pages under `wiki/` makes their informal lifecycle explicit.

## References

- [ADR-0010](0010-architecture-as-lifecycle-track.md) — the superseded decision that made architecture a formal track.
- [Architecture wiki index](../wiki/architecture/README.md) — the new home for system-wide architecture views.
- [Wiki policy](../wiki/README.md) — informal notes have no template, status lifecycle, or numbering.
- [docs/AGENTS.md](../AGENTS.md) — global docs taxonomy updated by this decision.
