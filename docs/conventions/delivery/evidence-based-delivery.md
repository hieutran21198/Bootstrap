# Evidence-based delivery

> **Scope**: every work item filed in Linear that tracks work against this workspace — features, bugs, debt, and chore items originating from `docs/prds/`, `docs/debt/`, `docs/specs/`, or `docs/findings/`.
> **Status**: Active
> **Decided by**: [ADR-0017](../../adrs/0017-evidence-based-delivery.md)
> **Last reviewed**: 2026-07-04

**Rule.** A Linear work item may transition to Done only when it carries linked evidence — raw verification output, a merged PR or commit reference, and pointers to the `docs/` record it realises — so that completion is demonstrated, not asserted.

**Rationale.** The on-disk `docs/` tree (PRDs, specs, debt register, findings) is the durable source of what the system should do and why; Linear is the working tracker that mirrors it for day-to-day progress. Without an evidence gate, a work item can be closed on a claim ("done") while the verification is missing, the PR is unmerged, or the `docs/` record is stale — and the two systems drift apart. Requiring evidence at close time keeps Linear a faithful reflection of `docs/`, makes status reports auditable, and stops "done" from meaning "I think it's done."

**Apply.**

- **Evidence task shape.** Every Linear work item that tracks workspace work carries three mandatory fields before it may be created:
  - **Acceptance criteria** — written as testable conditions (behavioural, not implementation-detail). A criterion is met when a reviewer can look at the evidence and judge it pass/fail without reading the code.
  - **Owner** — one named human or agent accountable for driving the item to Done. Every tracked item requires an owner; an unowned item is not filed.
  - **`docs/` reference** — a link or path to the source record in `docs/` (`prds/<x>.md`, `debt/<x>.md`, `specs/<x>.md`, `findings/<x>.md`). This is the durable record; the Linear item mirrors it.

- **Evidence at close time.** Before a work item transitions to Done, the owner (or the Scribe agent on their behalf) attaches:
  - **Raw verification output** — the terminal output of the relevant test / lint / build run, pasted into a comment or attached as a file. Not a screenshot of a green badge; the actual output so it can be re-read later.
  - **PR / commit link** — the merged PR URL (or, for non-PR work, the commit SHA) that delivered the change.
  - **`docs/` pointer** — the path (and, where the track format allows, a back-link from the `docs/` record to the Linear issue) to the PRD requirement, debt entry, or spec section this item realises.

- **Linear ↔ `docs/` mapping.** The on-disk record is the durable source; Linear issues mirror it.
  - Each Linear issue references its `docs/` record in the description or a dedicated field.
  - Where the `docs/` track format supports back-links (PRD `Realized by`, debt `References`, spec `Tracks`), the `docs/` record references the Linear issue in return.
  - The Scribe agent reconciles the two directions: if a `docs/` record exists without a Linear mirror, it files one; if a Linear item points at a `docs/` path that does not exist or is stale, it flags the discrepancy in a status report.

- **State lifecycle.** States advance on evidence, not assertion:
  - **Backlog** — item filed with acceptance criteria, owner, and `docs/` reference, but not yet started or scheduled.
  - **Todo** — owner has scheduled the item and it is ready to begin.
  - **In Progress** — owner is actively working; a branch or draft PR may exist.
  - **In Review** — PR open, awaiting review; evidence is accumulating but not yet complete.
  - **Done** — PR merged, evidence links attached (verification output + PR/commit link + `docs/` pointer), acceptance criteria judged met.
  - **Cancelled** — item will not be delivered; reason recorded in a comment.
  - An item may not skip from Backlog/Todo directly to Done; it must pass through In Progress (or In Review) so the evidence chain is visible.

- **Status reports.** When the Scribe produces a status report (sprint summary, weekly sync, ad-hoc), it reconciles Linear state against `docs/`:
  - Cite the evidence links on each Done item (PR link, verification output pointer).
  - Flag items where the Linear state and the `docs/` record disagree (e.g. Linear says Done but the PR is still open, or the debt entry is still `Open`).
  - The report is the audit trail — a reader should be able to trace every "done" claim back to raw output and a `docs/` record.

- **Roles.**
  - **Scribe agent (Delivery Record lane)** — files Linear items from `docs/` records, syncs state, attaches evidence at close time, reconciles the two directions in status reports. Uses the Linear MCP for all tracker operations.
  - **Humans and other agents** — supply the evidence artifacts: run the tests, open the PR, produce the verification output, update the `docs/` record. The Scribe does not fabricate evidence; it records what was produced.
  - **Architect** — reviews the convention itself (material changes need a new ADR) and may audit evidence quality during design reviews.

**Examples.**

✓ Good:

```text
Linear issue: PORTAL-42  "Implement staff invitation command handler"
  Acceptance criteria:
    - GIVEN a valid invitation payload, WHEN the command is executed,
      THEN a staff record is created with status "invited" and a
      72-hour-expiry UUIDv7 token.
    - GIVEN an expired token, WHEN validated, THEN the system returns
      an errorsx "invitation expired" error.
  Owner: backend-engineer
  docs/ reference: prds/staff-onboarding.md § Requirements R-03
  ---
  Evidence (at close):
    - Verification: `go test ./services/portal/internal/app/command/...`
      output attached (14 passed, 0 failed).
    - PR: https://github.com/<org>/bootstrap/pull/87 (merged)
    - docs/: prds/staff-onboarding.md updated Realized by → specs/staff-invitation.md
```

✗ Bad:

```text
Linear issue: PORTAL-42  "Implement staff invitation command handler"
  Status: Done
  (no acceptance criteria, no owner, no evidence links, no docs/ reference)
```

**Enforcement.** The Scribe agent is instructed to refuse to transition an item to Done via the Linear MCP unless the three evidence fields (verification output, PR/commit link, `docs/` pointer) are present. This is enforced by agent behavior and review/status-report audit, not by a mechanical validator. Status reports reconcile Linear against `docs/` and surface discrepancies. Humans and other agents are expected to supply evidence artifacts; the Scribe records them. Convention compliance is reviewed by the Architect during design reviews and by any contributor reading a status report.

## See also

- [Delivery conventions index](README.md)
- [ADR-0017](../../adrs/0017-evidence-based-delivery.md) — the decision that established this rule.
- [docs/ track lifecycle](../../AGENTS.md) — the on-disk record formats (PRD, spec, debt, finding) this convention mirrors into Linear.
- [Git pull-request conventions](../git/pull-requests.md) — the PR workflow whose merged output is the primary evidence artifact.
