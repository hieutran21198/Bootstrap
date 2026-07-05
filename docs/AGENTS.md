# docs/

## OVERVIEW
Workspace-wide (**global**) documentation — standards and records shared across services, the shared Go/Nix packages, and deployment. Seven formal tracks plus informal `wiki/`; each formal track has a distinct lifecycle and its own `TEMPLATE.md` (format) + `README.md` (authoring policy). Architecture views are informal wiki pages under `wiki/architecture/` (ADR-0020). Every formal track carries content except `glossary/` (still template-only).

**Two-tier model.** This tree is global. Service-only docs live under `services/<name>/docs/` (e.g. [../services/portal/docs/](../services/portal/docs/)), which mirrors the `prds / adrs / specs / findings / debt` tracks but defers all format + lifecycle authority to here. Rule of thumb: if another service would inherit it, it's global (here); if it dies with one service, it's service-local. `conventions/` and `glossary/` are global-only — never redefine a term or rule in a service tree; link to it.

## STRUCTURE
```
docs/
├── prds/          # product + domain intent (WHAT/WHY, solution-free — upstream of ADRs/specs)
├── adrs/          # decisions (append-only, numbered)
├── architecture/  # retired pointer stubs; views moved to wiki/architecture/ (ADR-0020)
├── specs/         # feature designs (living per spec)
├── conventions/   # workspace-wide rules (living, by topic)
│   ├── go/        # Go-specific conventions + templates
│   ├── git/       # branch / commit / PR workflow rules (incl. worktrees)
│   ├── api/       # REST API contract rules (contract-first OpenAPI, ADR-0018)
│   ├── auth/      # auth/OIDC integration contracts
│   ├── database/  # database role + RLS scope contracts
│   ├── agents/    # AI-agent hand-off protocol + .sdlc scratch workspace rules
│   └── delivery/  # evidence-based delivery rules for Linear (ADR-0017)
├── glossary/      # canonical terms (living, atomic per term)
├── findings/      # investigations & evidence (append-only, dated)
├── debt/          # technical debt register (living record + append-only ledger)
└── wiki/          # informal quick-reference notes outside the 7 formal tracks
    └── architecture/  # system-wide architecture views (informal, living)
```

## WHERE TO LOOK
Per-track format lives in `<track>/TEMPLATE.md`; authoring policy (and, for debt, escalation rules) in `<track>/README.md`.

| Need | Location |
|------|----------|
| Product/domain intent (WHAT/WHY) | `prds/` |
| Why we chose X over Y | `adrs/` |
| What the system is right now | `wiki/architecture/` |
| Workspace-wide rules | `conventions/` |
| Go package governance | [conventions/go/](conventions/go/) |
| Git workflow / worktree rules | [conventions/git/](conventions/git/) |
| REST API contract rules | [conventions/api/](conventions/api/) |
| Auth/OIDC integration | [conventions/auth/](conventions/auth/) |
| DB role & RLS scope contract | [conventions/database/](conventions/database/) |
| Agent communication / `.sdlc/` scratch workspace | [conventions/agents/](conventions/agents/) |
| Evidence-based delivery (Linear) | [conventions/delivery/](conventions/delivery/) |
| How a feature is designed | `specs/` |
| What a term means here | `glossary/` |
| What an investigation found | `findings/` |
| What debt we still owe | `debt/` |
| Informal notes (agent team, cheatsheets) | `wiki/` |
| Service-only docs (e.g. portal) | [../services/portal/docs/](../services/portal/docs/) |

## CONVENTIONS

### PRDs
Filename: `<capability>.md` or `<area>/<capability>.md`, no numbering, kebab-case. Front matter fields: `Status`, `Authors`, `Last reviewed`, `Realized by`. One capability per file; **requirements only** — no technology, design, or decision (those are `specs/` and `adrs/`). Required sections in order: Problem / Context, Users & personas, Requirements (EARS — `WHEN … THE SYSTEM SHALL …`), Non-goals, Domain intent, Alternatives considered, Open questions, Realized by, References. Status transitions: `Draft` → `Accepted` → `Delivered` → `Superseded by prds/<other>.md` or `Deprecated`. Living per PRD; bump `Last reviewed` on every material edit. **`Draft → Accepted` gate**: no open `[NEEDS CLARIFICATION]` marker, no leaked "how", every domain term defined in `glossary/` or nominated under Domain intent. Material intent change after `Delivered` supersedes with a new PRD. Downstream ADRs/specs set `Tracks: prds/<x>.md`; this PRD lists them under `Realized by` (the reverse link).

### ADRs
Filename: `NNNN-kebab-case-title.md`. Title is short, decisive, and reads as a result ("use-go-workspaces", not "should-we-use-go-workspaces"). One decision per ADR. Required sections in order: Context, Decision, Consequences, Alternatives considered, References. Status transitions: `Proposed` → `Accepted` → `Superseded by ADR-NNNN` or `Deprecated`.

### Architecture
System-wide architecture views live in `wiki/architecture/` as informal quick-reference pages (ADR-0020), not as a formal track. Filename: `<view>.md`, no numbering, kebab-case (`system-overview.md`, `request-flow.md`, `deployment-topology.md`). One view per file. No required front matter, template, or status lifecycle; edit in place as the system changes. Recommended habits, not enforced format: include a fenced `mermaid` diagram, annotate what exists today vs what is planned, and link to ADRs/specs/conventions instead of restating them. A new ADR is required only when the architecture changes by decision (new service, new external dependency, changed boundary). Distinct from `specs/` (one feature's design, has a finish line) and `adrs/` (the decision, append-only). The old `architecture/` directory contains only compatibility stubs.

### Conventions
Filename: `<topic>/<rule>.md`, no numbering. Front matter fields: `Scope`, `Status`, `Decided by`, `Last reviewed`. One rule per file. Required sections: **Rule** (one-sentence imperative), **Rationale**, **Apply**, **Examples** (Good / Bad), **Enforcement**. Living document; edit in place and bump `Last reviewed` for clarifications. Material changes need a new ADR.

### Specs
Filename: `<feature>.md` or `<area>/<feature>.md`, no numbering, kebab-case. Front matter fields: `Status`, `Authors`, `Last reviewed`, `Tracks`. One **feature** per file (a per-feature design with a finish line; system-wide views live in `wiki/architecture/`). Required sections in order: Problem, Goals, Non-goals, Background, Design, Alternatives considered, Open questions, Implementation plan, References. Status transitions: `Draft` → `Accepted` → `Implemented` → `Superseded by specs/<other>.md` or `Deprecated`. Living per spec; bump `Last reviewed` on every material edit. Material changes after `Implemented` need a new ADR.

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
- Putting a chosen technology or solution design in a PRD; the "how" lives in `specs/` and the decision in `adrs/`. A PRD is requirements only.
- Restating a PRD's requirements inside a spec or ADR instead of linking them via `Tracks` / `Realized by`.
- Defining a term canonically in a PRD; the glossary is the single source — a PRD only nominates candidates and links out.
- Promoting a PRD from `Draft` to `Accepted` while `[NEEDS CLARIFICATION]` markers remain.
- Editing a `Delivered` PRD in place for a material intent change; supersede with a new PRD instead.
- Putting a system-wide view (component map, request flow, topology) in `specs/`; those are living references and live in `wiki/architecture/` (ADR-0020). A spec is one feature's design with a finish line.
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
