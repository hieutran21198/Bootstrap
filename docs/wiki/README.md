# docs/wiki

Informal, fast-moving quick-reference notes — cheatsheets and at-a-glance tables
that sit outside the seven formal `docs/` tracks (`prds`, `adrs`, `specs`,
`conventions`, `glossary`, `findings`, `debt`). System-wide architecture views
also live here, under [`architecture/`](architecture/), as informal pages per
[ADR-0020](../adrs/0020-move-architecture-views-into-wiki.md).

Unlike the formal tracks, `wiki/` has **no template, status lifecycle, or
numbering**. It is a convenience surface, not a system of record. When a note
here hardens into a decision, rule, or design, promote it to the appropriate
track and link back.

## Contents

### Pages

- [`agent-team.md`](agent-team.md) — when to use which AI agent (orchestrator +
  subagents), mirroring the agent cards in
  [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/).
- [`agile-roles.md`](agile-roles.md) — AI agent roles mapped to product-engineering
  lanes (Backend, Frontend, Architect, Product, Reviewer, Scribe).
- [`implementation-workflow.md`](implementation-workflow.md) — operating model for
  how humans and AI agents run the SDLC pipeline, from idea through learning.
- [`jira-linear-sync.md`](jira-linear-sync.md) — operating model for how Project
  docs and the Jira/Linear tracker stay in sync as two sources of truth.

### Subfolders

- [`architecture/`](architecture/) — system-wide architecture views
  (system overview, request flow, deployment topology). Informal, living pages
  per [ADR-0020](../adrs/0020-move-architecture-views-into-wiki.md), superseding
  the retired `docs/architecture/` track.
