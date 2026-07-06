# Workspace glossary

The glossary fixes the **canonical meaning** of recurring terms — domain jargon, internal naming, and words that overlap with general usage (`module`, `service`, `package`, `workspace`). When two contributors disagree on what a word means in this repo, the glossary is the tiebreaker.

| Track                            | Question it answers              | Lifecycle             |
| -------------------------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/)                | *Why did we choose this rule?*   | Append-only, dated    |
| [conventions/](../conventions/)  | *What is the rule, right now?*   | Living, edit-in-place |
| [specs/](../specs/)              | *How is this built?*             | Living per spec       |
| glossary/                        | *What does this term mean here?* | Living, edit-in-place |

A term in the glossary is **always preferred** in ADRs, specs, conventions, code comments, and commit messages. Informal synonyms are flagged in the entry's *Synonyms / Avoid* section.

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one term**: front matter (`Status`, `Last reviewed`), then the four required sections — **Definition / Context / Examples / Synonyms · Avoid**, plus *See also*.

The shape borrows from the *ubiquitous language* glossaries of Domain-Driven Design (Evans, 2003) — one term, one canonical definition, cross-linked into the code and decision records that use it.

## Layout

One term per file, kebab-case, navigable via the Index below.

```text
docs/glossary/
├── README.md           # this file — Index
├── TEMPLATE.md         # skeleton for one term
└── <term>.md           # one term, standalone
```

## Naming

```text
docs/glossary/<term>.md
```

- **Kebab-case**, singular form unless the term is naturally plural (e.g. `consequences` if always discussed as a set).
- **No numbering** — terms are living, not append-only. Numbering belongs to ADRs.
- **One term per file** — atomic, linkable, standalone.

## Lifecycle

Glossary entries are **living documents**.

- **Clarification or new wording** — edit in place. Bump `Last reviewed`. No new file needed.
- **Term renamed** — write a new entry under the new filename, set the old entry's `Status: Deprecated`, point its body at the new entry. Do **not** delete the old file; old links must keep resolving.
- **Term retired** — set `Status: Deprecated` and explain what replaced it. Remove the row from the Index.

A term needs a new ADR only when its **definition has structural consequences** the workspace must accept — for example, defining `module` as "a directory with its own `go.mod`" excludes other valid Go uses of the word. Most terms are pure clarification and need no ADR.

## Writing a new entry

```bash
TERM=workspace                            # the term, kebab-case
cp docs/glossary/TEMPLATE.md "docs/glossary/${TERM}.md"
$EDITOR "docs/glossary/${TERM}.md"
```

Then add a row to the Index below.

## Index

_No entries yet._

| Term | Definition (one line) | Status |
| ---- | --------------------- | ------ |
