# docs/

## OVERVIEW
Four documentation tracks, each with distinct lifecycle. `adrs/` and `conventions/` populated; `specs/` and `glossary/` scaffold.

## STRUCTURE
```
docs/
├── adrs/          # decisions (append-only, numbered)
├── specs/         # feature/system designs (scaffold)
├── conventions/   # workspace-wide rules
│   └── go/        # Go-specific conventions + templates
└── glossary/      # canonical terms (scaffold)
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

## CONVENTIONS

### ADRs
Filename: `NNNN-kebab-case-title.md`. Title is short, decisive, and reads as a result ("use-go-workspaces", not "should-we-use-go-workspaces"). One decision per ADR. Required sections in order: Context, Decision, Consequences, Alternatives considered, References. Status transitions: `Proposed` → `Accepted` → `Superseded by ADR-NNNN` or `Deprecated`.

### Conventions
Filename: `<topic>/<rule>.md`, no numbering. Front matter fields: `Scope`, `Status`, `Decided by`, `Last reviewed`. One rule per file. Required sections: **Rule** (one-sentence imperative), **Rationale**, **Apply**, **Examples** (Good / Bad), **Enforcement**. Living document; edit in place and bump `Last reviewed` for clarifications. Material changes need a new ADR.

## ANTI-PATTERNS
- Editing the body of an accepted ADR; supersede it instead.
- Putting design discussion or specs inside an ADR.
- Skipping status transitions.
- Listing every imaginable option in Alternatives; include only those seriously weighed.
- Numbering convention filenames; numbering belongs to ADRs.
- Adding rationale inside the Rule section; keep the Rule to a single imperative sentence.
