# Findings

Findings are the **written record of an investigation** — debugging post-mortems, performance analyses, library evaluations, security verifications, reproducibility checks. They answer _what we found when we looked_, with enough evidence that the next contributor hitting the same symptom can skip the discovery work.

| Track                           | Question it answers              | Lifecycle             |
| ------------------------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/)               | _Why did we choose this?_        | Append-only, dated    |
| [conventions/](../conventions/) | _What is the rule, right now?_   | Living, edit-in-place |
| [specs/](../specs/)             | _How is this built?_             | Living per spec       |
| [glossary/](../glossary/)       | _What does this term mean here?_ | Living, edit-in-place |
| findings/                       | _What did we find?_              | Append-only, dated    |

A finding is the **single source of truth for what happened during an investigation** — never re-edited once `Resolved`, only superseded by a newer finding. ADRs cite findings; commit messages cite findings; the next bug report's first place to look is `docs/findings/`.

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one finding**: front matter (`Status`, `Authors`, `Investigated`, `Tracks`), then the sections — **Symptom / Reproduction / Hypotheses considered / Investigation / Root cause / Resolution / References**.

The shape borrows from the [Google SRE blameless-postmortem tradition](https://sre.google/sre-book/postmortem-culture/) (Symptom → Investigation → Root cause → Resolution), generalised so it fits non-incident work: a library evaluation has no "symptom" in the operator sense, but `Symptom` becomes _the question we set out to answer_, and the rest of the structure carries.

## Layout

One investigation per file. Group by area when more than a handful exist.

```
docs/findings/
├── README.md                                # this file — Index
├── TEMPLATE.md                              # skeleton for one finding
├── 2026-06-25-portal-token-leak.md          # one investigation, standalone
└── <area>/                                  # optional grouping by service or domain
    └── YYYY-MM-DD-<title>.md
```

If a finding produces heavy evidence (profiles, traces, raw logs, screenshots) that earns its space in the repo, commit the artifacts under a sibling directory:

```
docs/findings/
├── 2026-06-25-portal-token-leak.md
└── 2026-06-25-portal-token-leak.assets/     # raw evidence
    ├── trace.json
    └── pprof.svg
```

## Naming

```
docs/findings/YYYY-MM-DD-<title>.md             # top-level finding
docs/findings/<area>/YYYY-MM-DD-<title>.md      # grouped under an area
```

- **Date prefix** — `YYYY-MM-DD` of the day the investigation began, not the day the symptom first appeared. Findings are reached by _when we investigated_, not by sequence.
- **Title in kebab-case**, describing _what was investigated_ — `portal-token-leak`, not `bug-12345-investigation`. Read the filename, know the topic.
- **No numbering** — the date sorts. Numbering belongs to ADRs.
- **One investigation per file** — atomic, linkable, standalone. Multiple symptoms with one root cause is one finding; one symptom branching into multiple causes is still one finding.

## Lifecycle

Findings are **append-only**. `Status` transitions:

- `Open` — investigation in progress, report being written as evidence is gathered.
- `Resolved` — root cause confirmed, resolution shipped (or explicitly accepted as "no action").
- `Superseded by findings/YYYY-MM-DD-<title>.md` — a later investigation overturned this one's conclusion.

Once a finding is `Resolved`, the body is **never re-edited** except for typos. If new evidence contradicts the root cause, write a new finding that supersedes this one — the original stays as the historical record of what was believed at the time.

A finding **may produce** an ADR, a spec, or a new convention. The finding's _Resolution_ / _References_ points forward at those artifacts; the artifact's _References_ points back at the finding that motivated it.

## Writing a new finding

```bash
DATE=$(date +%Y-%m-%d)
AREA=portal                                                                       # optional, omit for top-level findings
TITLE=token-leak                                                                  # kebab-case

mkdir -p "docs/findings/${AREA}"                                                  # skip if the area exists, or omit entirely
cp docs/findings/TEMPLATE.md "docs/findings/${AREA}/${DATE}-${TITLE}.md"
$EDITOR "docs/findings/${AREA}/${DATE}-${TITLE}.md"
```

Heavy evidence (profiles, traces, raw logs) goes under `${DATE}-${TITLE}.assets/` next to the finding. Add a row to the Index below.

## Index

| Date       | Finding                                                                          | Status   | Tracks   |
| ---------- | -------------------------------------------------------------------------------- | -------- | -------- |
| 2026-06-26 | [claude-code-agent-configuration](2026-06-26-claude-code-agent-configuration.md) | Resolved | —        |
| 2026-07-03 | [govulncheck-go-stdlib-vulns](2026-07-03-govulncheck-go-stdlib-vulns.md)         | Resolved | ADR-0015 |
| 2026-07-05 | [selective-staging-destroyed-uncommitted-changes](2026-07-05-selective-staging-destroyed-uncommitted-changes.md) | Resolved | PR #22   |
