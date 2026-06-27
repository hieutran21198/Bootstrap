# <Short title — what was investigated, not the symptom>

> **Status**: Open
> **Authors**: <people who ran the investigation — e.g. Minh Hieu Tran <hieu.tran21198@gmail.com>>
> **Investigated**: YYYY-MM-DD
> **Tracks**: <issue URL, incident ID, PR link, or "—" if standalone>

## Symptom

What was observed. The user-visible or operator-visible behaviour that triggered the investigation. State the symptom as the reporter saw it; do **not** lead with the root cause.

## Reproduction

The exact steps, commands, or inputs that surface the symptom. A future contributor reading this file must be able to reproduce — or, if the symptom was non-reproducible, the file must say so explicitly and explain how that was confirmed.

```text
<command, input, request, or scenario>
```

## Hypotheses considered

- **H1: <one-line hypothesis>.** <How it was tested. Disproved by <evidence>, or confirmed (see Root cause).>
- **H2: <one-line hypothesis>.** <How it was tested. Disproved by <evidence>.>

Only hypotheses actually considered. Leave the dead ends in — the next investigator saves hours not retreading them.

## Investigation

What was actually run, read, traced, or measured. Cite the artifacts:

- Commands executed (with material output stored alongside if it earns its space).
- Logs, traces, profiles, screenshots — committed under `<filename>.assets/` next to this file.
- Code paths read, with `file:line` links.

## Root cause

The thing that caused the symptom, in one or two sentences. Imperative voice ("The `X` returned stale cache because …"). Distinguish proximate cause from contributing factors.

## Resolution

What was changed, link by link. Each item names the PR, commit, ADR, or spec that closes the loop. If the resolution is "no change required" (user error, environmental, accepted risk), state that explicitly.

- <PR / commit / ADR / spec link> — <what it did>

## References

- Tickets, findings this one supersedes or is superseded by, ADRs (portal or workspace) invalidated or motivated, external articles, prior art.
