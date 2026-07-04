# Debt

The debt register records **what the workspace still owes** — architecturally-significant shortcomings we have chosen to make visible. Routine `TODO` / `FIXME` nits stay inline in code; debt that recurs, cross-cuts modules, or earns first-class visibility lives here, with an **evidence ledger that drives prioritisation**.

| Track                           | Question it answers              | Lifecycle             |
| ------------------------------- | -------------------------------- | --------------------- |
| [adrs/](../adrs/)               | _Why did we choose this?_        | Append-only, dated    |
| [conventions/](../conventions/) | _What is the rule, right now?_   | Living, edit-in-place |
| [specs/](../specs/)             | _How is this built?_             | Living per spec       |
| [glossary/](../glossary/)       | _What does this term mean here?_ | Living, edit-in-place |
| [findings/](../findings/)       | _What did we find?_              | Append-only, dated    |
| debt/                           | _What do we still owe?_          | Living + ledger       |

A debt item has **two layers**:

1. **Static record** — _What_ / _Why it exists_ / _Impact_ / _Resolution_. Edited in place as understanding sharpens.
2. **Encounter ledger** — append-only table. Each row is evidence that the debt caused real pain on a real day.

The ledger drives **priority**; priority drives **escalation**; escalation drives **payment**.

## Template

[TEMPLATE.md](TEMPLATE.md) is the skeleton for **one debt item**: front matter (`Status`, `Priority`, `Hits`, `Owner`, `Created`, `Last reviewed`), the static sections (**What / Why it exists / Impact / Resolution**), the **Encounters** ledger, then **References**.

## Scope

**In:**

- Architectural shortcuts (_"portal handlers carry business logic — should move to domain layer"_).
- Module-shape debt (_"`X` and `Y` duplicate state-machine code"_).
- Tooling debt (_"Go pinned to 1.26.3; can't move because of `<dep>`"_).
- Test coverage gaps that bite repeatedly.
- Spec-vs-reality drift (_"spec is `Implemented` but auth flow differs"_).

**Out:**

- Routine cleanups (rename a variable, extract a helper) — those stay inline as `TODO` / `FIXME`.
- One-off bugs without a structural shortcoming — those are [findings](../findings/), not debt.
- Feature work — that's a [spec](../specs/) or a ticket.

Rule of thumb: **if the same shape of pain hits twice, it earns a debt entry.**

## Layout

One debt item per file. Group by area when more than a handful exist.

```
docs/debt/
├── README.md                                # this file — Index and escalation rules
├── TEMPLATE.md                              # skeleton for one debt item
├── portal-sync-http.md                      # one item, standalone
└── <area>/                                  # optional grouping by service or domain
    └── <topic>-<short-desc>.md
```

## Naming

```
docs/debt/<topic>-<short-desc>.md             # top-level
docs/debt/<area>/<topic>-<short-desc>.md      # grouped
```

- **Kebab-case**, shape-oriented: `portal-sync-http.md`, `gormx-no-tx-cleanup.md`. Read the filename, know the debt.
- **No numbering, no dates** in the filename — debt is current state, not history. `Status` and the ledger encode time.
- **One debt item per file** — atomic, linkable. Multiple symptoms with one structural cause is one item; one symptom with multiple structural causes is multiple items.

## Lifecycle

Debt items are **living for the static record**, **append-only for the ledger**.

### Status

| Status      | Meaning                                                                         |
| ----------- | ------------------------------------------------------------------------------- |
| `Open`      | Acknowledged, no plan to fix.                                                   |
| `Planned`   | Work scheduled. Must link to the spec / ADR / ticket committing to fix.         |
| `Resolved`  | Paid down. Must link to the PR / commit that did it. **Ledger freezes.**        |
| `Accepted`  | We will live with this permanently. Must link to the ADR that decided so.       |
| `Won't fix` | Retired without resolution. Must explain why (no longer applicable, obsoleted). |

Status moves forward; never `Resolved` → `Open`. If the debt recurs after `Resolved`, write a _new_ debt item that references the old one — the original stays as the historical record.

### Priority

Derived from the ledger; updated by the owner during review.

| Priority   | Meaning                                                                              |
| ---------- | ------------------------------------------------------------------------------------ |
| `Low`      | No active pain. Tracked for visibility only.                                         |
| `Medium`   | Occasional pain or modest cost.                                                      |
| `High`     | Recurring pain or significant cost.                                                  |
| `Critical` | Currently blocking work, causing incidents, or actively losing money / users / time. |

### Escalation rule

| Trigger                                                               | Action                                                                                |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Any single `Critical` encounter                                       | Priority → `Critical`. Status must move to `Planned` within **2 weeks**.              |
| ≥3 `High` encounters within 90 days                                   | Priority → `High`. Status must move to `Planned` within **1 quarter**.                |
| ≥5 `Medium` encounters within 90 days                                 | Priority → `High`.                                                                    |
| Any debt at `Priority ≥ High` sitting in `Open` longer than 1 quarter | Reviewed at the next planning round; explain in `Resolution`, or escalate the status. |

**`Open` debt at `Priority ≥ High` is a smell.** Either commit to fix (`Planned`) or accept it formally (`Accepted` + an ADR).

### Ledger discipline

- **Append only.** Never edit a historic Encounter row. Wrong data? Add a new row with severity `correction` and a one-line note.
- **One row per real hit.** Don't preemptively log "this might hurt later" — that's the `Impact` section, not the ledger.
- **If the hit warranted investigation**, write the finding first under [`../findings/`](../findings/), then link to it from the row's _Evidence_ column. The finding carries the depth; the row carries the count.

## Writing a new debt item

```bash
TOPIC=portal               # the area / module the debt lives in
DESC=sync-http             # the shortcoming, kebab-case

cp docs/debt/TEMPLATE.md "docs/debt/${TOPIC}-${DESC}.md"
$EDITOR "docs/debt/${TOPIC}-${DESC}.md"
```

Set `Created` to today, `Status: Open`, `Priority: Low` (or `Medium` if you can already cite concrete impact). Add a row to the Index below.

## Logging an encounter

When the debt bites you in real work:

1. Open the matching debt file.
2. Append a row to the `Encounters` table: date, severity (how bad _this hit_ was), your name, one-line symptom, evidence link (PR, finding, ticket, or `—`).
3. Bump `Hits` in the front matter.
4. If the encounter crosses a threshold in the escalation rule above, bump `Priority` and adjust `Status` accordingly. Bump `Last reviewed`.
5. If the encounter warranted a real investigation, write the finding under [`../findings/`](../findings/) first, then link to it from the row.

## Index

| File                                                                         | Status | Priority | Hits | Owner      |
| ---------------------------------------------------------------------------- | ------ | -------- | ---- | ---------- |
| [agent-orchestration-no-delegation.md](agent-orchestration-no-delegation.md) | Open   | Medium   | 1    | unassigned |
| [docs-traceability-no-validator.md](docs-traceability-no-validator.md)       | Open   | Low      | 1    | unassigned |
| [database/organizations-missing-rls-policy.md](database/organizations-missing-rls-policy.md) | Open   | High     | 1    | portal     |
| [api-codegen-no-drift-check.md](api-codegen-no-drift-check.md)               | Open   | Medium   | 0    | unassigned |
| [git-no-presubmit-pr-title-validation.md](git-no-presubmit-pr-title-validation.md) | Open | Medium | 1    | unassigned |
| [docs-agents-stale-adr-range.md](docs-agents-stale-adr-range.md)             | Open   | Low      | 1    | unassigned |
