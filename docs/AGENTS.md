# docs/

## OVERVIEW
Six documentation tracks, each with distinct lifecycle and its own `TEMPLATE.md` + `README.md`. `adrs/` and `conventions/` carry content; `specs/`, `glossary/`, `findings/`, and `debt/` are infrastructured but empty.

## STRUCTURE
```
docs/
├── adrs/          # decisions (append-only, numbered)
├── specs/         # feature/system designs (living per spec)
├── conventions/   # workspace-wide rules (living, by topic)
│   └── go/        # Go-specific conventions + templates
├── glossary/      # canonical terms (living, atomic per term)
├── findings/      # investigations & evidence (append-only, dated)
└── debt/          # technical debt register (living record + append-only ledger)
```

## WHERE TO LOOK
| Need | Location |
|------|----------|
| Why we chose X over Y | `adrs/` |
| ADR format | [adrs/TEMPLATE.md](adrs/TEMPLATE.md) |
| ADR authoring policy | [adrs/README.md](adrs/README.md) |
| Workspace-wide rules | `conventions/` |
| Convention format | [conventions/TEMPLATE.md](conventions/TEMPLATE.md) |
| Convention authoring policy | [conventions/README.md](conventions/README.md) |
| Go package governance | [conventions/go/](conventions/go/) |
| How a feature is designed | `specs/` |
| Spec format | [specs/TEMPLATE.md](specs/TEMPLATE.md) |
| Spec authoring policy | [specs/README.md](specs/README.md) |
| What a term means here | `glossary/` |
| Glossary entry format | [glossary/TEMPLATE.md](glossary/TEMPLATE.md) |
| Glossary authoring policy | [glossary/README.md](glossary/README.md) |
| What an investigation found | `findings/` |
| Finding format | [findings/TEMPLATE.md](findings/TEMPLATE.md) |
| Finding authoring policy | [findings/README.md](findings/README.md) |
| What debt we still owe | `debt/` |
| Debt entry format | [debt/TEMPLATE.md](debt/TEMPLATE.md) |
| Debt authoring policy & escalation rules | [debt/README.md](debt/README.md) |

## CONVENTIONS

### ADRs
Filename: `NNNN-kebab-case-title.md`. Title is short, decisive, and reads as a result ("use-go-workspaces", not "should-we-use-go-workspaces"). One decision per ADR. Required sections in order: Context, Decision, Consequences, Alternatives considered, References. Status transitions: `Proposed` → `Accepted` → `Superseded by ADR-NNNN` or `Deprecated`.

### Conventions
Filename: `<topic>/<rule>.md`, no numbering. Front matter fields: `Scope`, `Status`, `Decided by`, `Last reviewed`. One rule per file. Required sections: **Rule** (one-sentence imperative), **Rationale**, **Apply**, **Examples** (Good / Bad), **Enforcement**. Living document; edit in place and bump `Last reviewed` for clarifications. Material changes need a new ADR.

### Specs
Filename: `<feature>.md` or `<area>/<feature>.md`, no numbering, kebab-case. Front matter fields: `Status`, `Authors`, `Last reviewed`, `Tracks`. One feature per file. Required sections in order: Problem, Goals, Non-goals, Background, Design, Alternatives considered, Open questions, Implementation plan, References. Status transitions: `Draft` → `Accepted` → `Implemented` → `Superseded by specs/<other>.md` or `Deprecated`. Living per spec; bump `Last reviewed` on every material edit. Material changes after `Implemented` need a new ADR.

### Glossary
Filename: `<term>.md`, no numbering, kebab-case, singular form. Front matter fields: `Status`, `Last reviewed`. One term per file. Required sections: **Definition** (one sentence), **Context**, **Examples**, **Synonyms / Avoid**. Living document; edit in place and bump `Last reviewed` for clarifications. A new ADR is only required when the definition has structural consequences the workspace must accept.

### Findings
Filename: `YYYY-MM-DD-<title>.md` or `<area>/YYYY-MM-DD-<title>.md`, kebab-case title. Front matter fields: `Status`, `Authors`, `Investigated`, `Tracks`. One investigation per file. Required sections in order: Symptom, Reproduction, Hypotheses considered, Investigation, Root cause, Resolution, References. Status transitions: `Open` → `Resolved` → `Superseded by findings/YYYY-MM-DD-<title>.md`. Append-only; never re-edited after `Resolved` except for typos. Heavy evidence (logs, profiles, traces) lives in a sibling `<filename>.assets/` directory.

### Debt
Filename: `<topic>-<desc>.md` or `<area>/<topic>-<desc>.md`, kebab-case; no numbering, no dates. Front matter fields: `Status`, `Priority`, `Hits`, `Owner`, `Created`, `Last reviewed`. One debt item per file. Required sections in order: What (one sentence), Why it exists, Impact, Resolution, Encounters (append-only ledger table), References. Status transitions: `Open` → `Planned` → `Resolved`, or `Accepted` / `Won't fix`. Priority levels: `Low` / `Medium` / `High` / `Critical`, derived from encounters. Static sections are living; the **Encounters table is append-only** (corrections add a new row; never rewrite). Escalation rules in [debt/README.md](debt/README.md): any `Critical` encounter → `Planned` within 2 weeks; ≥3 `High` encounters in 90 days → `Planned` within 1 quarter; ≥5 `Medium` encounters in 90 days → `Priority: High`. `Open` debt at `Priority ≥ High` for >1 quarter is a review smell.

## ANTI-PATTERNS
- Editing the body of an accepted ADR; supersede it instead.
- Putting design discussion or specs inside an ADR; specs live in `specs/`.
- Putting decisions inside a spec; decisions live in `adrs/` and the spec's `Tracks` field points at them.
- Skipping status transitions on ADRs, specs, findings, or debt items.
- Listing every imaginable option in Alternatives; include only those seriously weighed.
- Numbering convention, spec, glossary, or debt filenames; numbering belongs to ADRs. Findings use date prefixes, not numbers.
- Adding rationale inside the Rule section of a convention; keep the Rule to a single imperative sentence.
- Defining a term in two places; the glossary is the single source. Other docs link to it.
- Deleting a deprecated spec, glossary entry, finding, or debt item; mark `Status: Deprecated` / `Superseded by …` / `Won't fix` and leave the file so old links keep resolving.
- Editing a `Resolved` finding; supersede with a new dated finding instead.
- Leading a finding's Symptom section with the root cause; symptoms are stated as the reporter saw them.
- Omitting disproved hypotheses from a finding; the next investigator needs the dead ends to skip them.
- Editing historic rows in a debt item's Encounters ledger; the ledger is append-only. Corrections add a new row, never rewrite an existing one.
- Preemptively logging "this might hurt later" as an Encounter; that's the `Impact` section, not evidence.
- Letting `Open` debt sit at `Priority ≥ High` for more than a quarter without `Planned` or `Accepted` resolution and an explanation in `Resolution`.
- Storing routine `TODO` / `FIXME` nits in `debt/`; those stay inline in code. Debt is for shape-of-the-system shortcomings that recur.
