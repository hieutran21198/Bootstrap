# Docs taxonomy cross-links and gates are unenforced — no validator

> **Status**: Open
> **Priority**: Low
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-01
> **Last reviewed**: 2026-07-01

## What

The docs taxonomy's cross-links (`Tracks:` / `Realized by:`), status gates (an open `[NEEDS CLARIFICATION]` blocking a PRD from `Accepted`), and per-track status vocabularies are enforced only by human review — there is no automated validator.

## Why it exists

A `docs-guard` validator was designed (a stub `README` under `tools/validators/docs-guard/`) but deliberately **not** built, to keep focus on completing the PRDs. The stub was deleted rather than carried as dead scaffolding, and its intent is recorded here instead. Building it now is premature for a small doc set — the substrate to write it exists (`tools/validators/git-guard/` is the pattern), it is simply not worth the tooling until the doc web is large enough that manual review becomes unreliable.

## Impact

- **Correctness**: dangling backlinks, and PRDs promoted to `Accepted` while still carrying unresolved `[NEEDS CLARIFICATION]` markers, can slip through unnoticed.
- **Maintainability**: keeping the PRD ↔ ADR ↔ spec ↔ glossary backlink graph consistent is fully manual and degrades as the number of cross-linked docs grows.
- **Developer experience**: contributors (human or agent) get no fast feedback; a mistake surfaces only when a careful reader or a downstream consumer trips over it.

## Resolution

When the doc web grows enough that manual review is unreliable, build `docs-guard` as a Go `package main` under `tools/validators/docs-guard/` (mirroring `git-guard`) and wire it into pre-commit. Intended checks:

1. every `Tracks:` / `Realized by:` target resolves to an existing file (no dangling references);
2. a PRD at `Status: Accepted` (or later) contains no `[NEEDS CLARIFICATION:` markers;
3. backlink symmetry — if an ADR/spec `Tracks:` a PRD, that PRD's `Realized by` lists it back (warn);
4. `Status` values are drawn from the allowed per-track set;
5. no-solution heuristic for PRDs — fenced code / known tech tokens flagged for review (warn).

The original stub is recoverable from git history.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter     | Symptom                                                                                                                            | Evidence |
| ---------- | -------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 2026-07-01 | Low      | orchestrator | Deleting ADR-0013 left 6 dangling `Tracks:` / `Realized by:` references across 3 files; all had to be found and reverted by hand, with nothing to flag them. | —        |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- `docs/prds/README.md` — the `[NEEDS CLARIFICATION]` and status gates a validator would enforce.
- `docs/AGENTS.md` — the per-track status vocabularies and backlink conventions.
- `tools/validators/git-guard/` — the `package main` validator pattern `docs-guard` would follow.
- The deleted `tools/validators/docs-guard/README.md` stub — recoverable via git history.
