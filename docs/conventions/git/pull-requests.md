# Pull Requests

> **Scope**: every pull request opened against this repository, and every review of one.
> **Status**: Active
> **Decided by**: [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md)
> **Last reviewed**: 2026-07-01

**Rule.** Title every pull request in the commit-header format `<type>(<scope>): <description>`, fill the body from [`.github/PULL_REQUEST_TEMPLATE.md`](../../../.github/PULL_REQUEST_TEMPLATE.md), and merge only after a reviewer has cleared the review checklist below and CI is green.

**Rationale.** The PR is the one gate every change passes before it reaches the always-deployable `main`, so it carries two jobs. A structured **title** (same grammar as commits) becomes the squash commit that lands on `main` — get it right once and the changelog is right. A structured **body** (What / Why / How / Testing) gives the reviewer the context to judge the change instead of reverse-engineering it from the diff. A shared **review checklist** makes "approved" mean the same thing every time, so the deploy-on-merge trunk stays trustworthy.

**Apply.**

- **Title = commit header.** `<type>(<scope>): <description>`, same allowed types and style as [commit-messages.md](commit-messages.md) (imperative, lower-case, no trailing period). This is what "Squash and merge" uses as the `main` commit, so make it releasable prose.
  - ✓ `feat(portal): add tenant invitation flow`
  - ✗ `Tenant invites` / `WIP` / `Fixes`
- **Body from the template.** GitHub auto-loads [`.github/PULL_REQUEST_TEMPLATE.md`](../../../.github/PULL_REQUEST_TEMPLATE.md). Fill every section; delete a section only if it is genuinely N/A (say why). The sections:
  - **What** — what the PR does.
  - **Why** — motivation and context.
  - **How** — key implementation details worth highlighting.
  - **Testing** — which tests were added/updated and what manual testing was done.
  - **Screenshots** — before/after for any UI change.
  - **Checklist** — the author's self-review boxes.
  - Link issues in the footer (`Closes #123`).
- **Keep PRs small and single-purpose.** One logical change per PR; it reviews faster and reverts cleanly. Split unrelated work.
- **Open when ready to review** ([workflow.md](workflow.md)) — compiles, tests pass locally, self-reviewed. Use GitHub *Draft* for work-in-progress.
- **Author, before requesting review:** rebase on latest `main` if the branch is local-only ([merge-vs-rebase.md](merge-vs-rebase.md)), ensure CI is green, complete the self-review checklist.
- **Reviewer, before approving — the review checklist:**

  - [ ] **Scope** — the PR does one thing; title + description match the actual diff.
  - [ ] **Correctness** — the change does what it claims; edge cases and error paths are handled.
  - [ ] **Tests** — meaningful tests cover the change; they actually exercise the new behaviour; CI is green.
  - [ ] **Conventions** — follows workspace conventions ([Go](../go/README.md), [database](../database/role-and-scope-contract.md), [auth](../auth/), etc.) and existing patterns in the touched area.
  - [ ] **Readability** — names, structure, and comments make intent clear; complex logic is explained.
  - [ ] **Simplicity** — no needless abstraction, dead code, or scope creep (YAGNI).
  - [ ] **Security & data** — inputs validated at boundaries; no secrets in code, logs, or fixtures; tenant/RLS scope respected where relevant.
  - [ ] **Performance** — no obvious N+1s, unbounded queries, or hot-path regressions.
  - [ ] **Docs** — ADR / convention / architecture / README updated when the change warrants it.
  - [ ] **Migrations & compatibility** — schema/API changes are backward-compatible or the break is called out (`BREAKING CHANGE`).
  - [ ] **No leftovers** — no debug prints, commented-out code, stray TODOs, or new warnings.
  - [ ] **Deployability** — safe to auto-deploy to `dev` on merge (feature-flagged / reversible if risky).

- **Merge** with squash-merge after approval + green CI; delete the branch ([merge-vs-rebase.md](merge-vs-rebase.md)).

**Examples.**

✓ Good:
```text
Title:  feat(portal): add tenant invitation flow

## What
Adds an org-scoped invitation flow with a 72h-expiry UUIDv7 token.
## Why
Onboarding needs a way to add staff without an admin creating each account.
## How
New command handler + repo method; token validated at the boundary.
## Testing
- [x] Unit tests added/updated
- [ ] Integration tests added/updated
- [x] Manual testing performed
Closes #142
```

✗ Bad:
```text
Title:  updates
(empty body, no context, no tests noted, direct-to-main intent)
```

**Enforcement.** CI ([`.github/workflows/pr-validate.yml`](../../../.github/workflows/pr-validate.yml)) runs `git-guard pr-title` (and branch-name) on every PR, so an off-format title fails a required check. A GitHub ruleset makes review + that check mandatory before merge to `main`/`release/*` — apply it with [`tools/scripts/setup-branch-protection.sh`](../../../tools/scripts/setup-branch-protection.sh) (ADR-0012 follow-up; needs repo admin). Template completeness and the reviewer checklist are **code-review-enforced** (a human reviewer runs the checklist); `commitizen` + `git-guard` validate the squash commit that results.

## See also

- [Git conventions index](README.md)
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../../.github/PULL_REQUEST_TEMPLATE.md) — the body template GitHub loads.
- [Commit messages](commit-messages.md) — the title grammar the squash commit reuses.
- [Merge vs rebase](merge-vs-rebase.md) — squash-merge into `main`, no direct merge.
- [Branch & release workflow](workflow.md) — where the PR sits in the path to `dev`.
- [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md) — the decision that established this rule.
