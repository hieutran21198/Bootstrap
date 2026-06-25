# Workspace conventions

Conventions are the **standing rules** the workspace currently follows — how a package is shaped, how a file is named, what a commit message looks like. They are the day-to-day reference. Compare to [`adrs/`](../adrs/), which records the **decisions** that produced the rules.

| Track             | Question it answers              | Lifecycle             |
| ----------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/) | *Why did we choose this rule?*   | Append-only, dated    |
| conventions/      | *What is the rule, right now?*   | Living, edit-in-place |

A convention without a decision is hearsay; a decision without a convention is a forgotten meeting. Use both.

## Layout

Conventions are organised **per topic, one rule per file**. Each topic is a directory with its own `README.md` (the topic index) and one `<rule>.md` per rule.

```
docs/conventions/
├── README.md                       # this file — workspace-level index of topics
├── TEMPLATE.md                     # skeleton for a single rule
└── go/                             # topic: Go conventions
    ├── README.md                   # Go-topic index of rules
    └── single-responsibility.md    # one rule, standalone
```

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one rule**: front matter (`Scope`, `Status`, `Decided by`, `Last reviewed`), then the five required sections — **Rule / Rationale / Apply / Examples (✓ Good / ✗ Bad) / Enforcement**, plus *See also*.

## Naming

```
docs/conventions/<topic>/<rule>.md      # one rule
docs/conventions/<topic>/README.md      # topic-level index (mirrors docs/adrs/README.md)
```

- **Topic directories**, kebab-case: `go/`, `nix/`, `commit-messages/`, `markdown/`. One topic per language or cross-cutting concern.
- **Rule files**, kebab-case: `single-responsibility.md`, `error-wrapping.md`, `context-first.md`. One rule per file — atomic, linkable, standalone.
- **No numbering on filenames** — conventions are living, not append-only. Numbering belongs to ADRs.
- **Each topic has its own `README.md`** — overview front matter + an Index table of the rules in that topic, mirroring [docs/adrs/README.md](../adrs/README.md).

## Lifecycle

Conventions are **living documents**. They reflect the current state of the workspace.

- **Clarification or new wording** — edit the rule file in place. Bump `Last reviewed`. No new file needed.
- **Adding a new rule to an existing topic** — write a new `<rule>.md` in the topic directory, add it to the topic's `README.md` Index, and write a new ADR documenting the decision.
- **Material change** (rule reversed, scope narrowed/broadened) — write a new ADR. Set `Status: Accepted` on the new ADR. Update the rule file's `Decided by` and `Last reviewed` to match.
- **Retiring a rule** — set `Status: Deprecated` in the rule's front matter, reference the ADR that retired it, and remove the row from the topic's README Index. Do **not** delete the file; future contributors need to know the rule existed.
- **Adding a new topic** — create `docs/conventions/<topic>/`, write `<topic>/README.md` (the topic index), write the first rule under it, write the ADR that established the convention. Add a row to the workspace-level Index below.

## Writing a new convention

```bash
TOPIC=go                  # or nix, commit-messages, ...
RULE=error-wrapping       # the rule name, kebab-case

# 1. Topic directory + topic README (skip if the topic already exists).
mkdir -p "docs/conventions/${TOPIC}"
$EDITOR "docs/conventions/${TOPIC}/README.md"     # copy an existing topic README for shape

# 2. The rule file.
cp docs/conventions/TEMPLATE.md "docs/conventions/${TOPIC}/${RULE}.md"
$EDITOR "docs/conventions/${TOPIC}/${RULE}.md"

# 3. The ADR that justifies it.
NEXT=$(printf "%04d" $(( $(ls docs/adrs | grep -E '^[0-9]{4}' | wc -l) + 1 )))
cp docs/adrs/TEMPLATE.md "docs/adrs/${NEXT}-<title>.md"
$EDITOR "docs/adrs/${NEXT}-<title>.md"
```

Then cross-link: the rule's `Decided by` points at the ADR; the ADR's *References* points at the rule. Add the rule to the topic README's Index table and the ADR to [docs/adrs/README.md](../adrs/README.md) Index.

## Index

| Topic        | Coverage                                                                                            | Docs |
| ------------ | --------------------------------------------------------------------------------------------------- | ---- |
| [go/](go/)   | Templates + decision tree for Go packages across `packages/`, `services/`, `tools/`, `apps/`        | 2    |
