# PR titles are not validated locally before `gh pr create`

> **Status**: Open
> **Priority**: Medium
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-04
> **Last reviewed**: 2026-07-04

## What

PR titles are validated only in CI (`.github/workflows/pr-validate.yml` runs `git-guard pr-title`), with no local/pre-submit step, so a non-compliant PR title is caught only after the PR is opened.

## Why it exists

Commit messages are validated locally by the commit-msg hook, but a PR title is authored at PR-open time — outside git's commit flow. Because squash-merge makes the PR title the commit subject, git-guard applies the full Conventional-Commit header rule to it (`validateHeader` in `tools/validators/git-guard/commit.go` — type set, lowercase imperative subject, no trailing period, ≤72 chars), but nothing runs that check before `gh pr create`.

## Impact

- **Developer experience**: PRs open red on the "PR validation / Validate PR title" check; wasted round-trip; the rule is discovered only after submitting.

## Resolution

Provide a pre-submit path — e.g. a devenv command or PR-open helper that runs `git-guard pr-title "<title>"` before opening the PR (mirroring the local commit-msg check), or bake it into the PR-open tooling.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter   | Symptom                                                                                     | Evidence |
| ---------- | -------- | ---------- | ------------------------------------------------------------------------------------------- | -------- |
| 2026-07-04 | Medium   | pr-author  | PR #12 title `docs: ADR-0018 contract-first REST API` failed `git-guard pr-title` because the subject started uppercase; caught only after opening. | PR #12   |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- `.github/workflows/pr-validate.yml` — the CI job that runs `git-guard pr-title`.
- `tools/validators/git-guard/commit.go` (`cmdPRTitle` / `validateHeader`) — the validation logic a pre-submit path would reuse.
- `docs/conventions/git/` — the commit-message rule whose header constraints also apply to PR titles.
- PR #12 — the encounter that surfaced this gap.
