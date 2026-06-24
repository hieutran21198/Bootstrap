# docs/

## OVERVIEW

Four documentation tracks, each with a distinct lifecycle. Only `adrs/` is populated.

## STRUCTURE

```
docs/
├── adrs/          # decisions (append-only, numbered)
├── specs/         # feature/system designs (scaffold)
├── conventions/   # workspace-wide rules (scaffold)
└── glossary/      # canonical terms (scaffold)
```

## WHERE TO LOOK

| Need                                         | Location                                                     |
| -------------------------------------------- | ------------------------------------------------------------ |
| Why we chose X over Y                        | [adrs/](adrs/)                                               |
| How a feature is designed                    | `specs/` (write a new `.md`; no template yet)                |
| Workspace-wide rules                         | `conventions/` (currently empty; root AGENTS.md is canonical)|
| Domain term definitions                      | `glossary/`                                                  |
| ADR format                                   | [adrs/TEMPLATE.md](adrs/TEMPLATE.md)                         |
| ADR policy                                   | [adrs/README.md](adrs/README.md)                             |

## CONVENTIONS

### ADRs (enforced)

- **Filename**: `NNNN-kebab-case-title.md` (4-digit zero-padded sequence).
- **Title style**: short, decisive, **result-phrased**. `use-go-workspaces` ✓ — `should-we-use-go-workspaces` ✗.
- **One decision per ADR**. Splitting into two ADRs > merging concerns.
- **Required sections** (in this order): Status header, Context, Decision (imperative voice), Consequences (Positive / Negative / Neutral), Alternatives considered, References.
- **Status lifecycle**: `Proposed` → `Accepted` → `Superseded by ADR-NNNN` | `Deprecated`.

## ANTI-PATTERNS

- **Do not edit an accepted ADR's body** to reverse the decision. Write a new ADR with a higher number, mark the old one `Superseded by ADR-NNNN`. ADRs are **append-only**.
- **Do not write design discussion** in ADRs — that belongs in `specs/`. ADRs record the outcome.
- **Do not skip status transitions** — every ADR must end in a terminal state if no longer active (`Superseded by ...` or `Deprecated`).
- **Do not list every possible option** in *Alternatives considered* — only the ones seriously weighed.
