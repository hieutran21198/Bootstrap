# Merge vs Rebase

> **Scope**: every integration of one branch into another — landing a pull request into `main`, and updating a working branch with newer trunk.
> **Status**: Active
> **Decided by**: [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md)
> **Last reviewed**: 2026-07-01

**Rule.** Land pull requests into `main` with **squash-merge** (direct merge to `main` is forbidden — a PR is always required); use **rebase** only to bring a *local, unshared* branch up to date on `main`, and never rebase a branch that has been shared, is protected, or has already merged.

**Rationale.** Two operations, two jobs. Squash-merge is how work *enters* the trunk: it collapses a PR's messy intermediate commits into one clean Conventional Commit, keeping `main` linear, bisectable, and revertible one-PR-at-a-time. Rebase is how a branch *stays current*: replaying your commits on top of the latest `main` gives a clean, conflict-resolved-once history with no criss-cross merge commits — but rebasing rewrites commit hashes, so doing it to history other people (or the deploy pipeline) already have corrupts their view. The rule keeps rebase's benefit (clean local history) while fencing off its one real hazard (rewriting shared history).

**Apply.**

- **Landing to `main` → squash-merge via PR.**
  - No direct `git push` to `main` and no local `git merge … && push`; open a PR ([pull-requests.md](pull-requests.md)).
  - Merge with **Squash and merge**. The squash commit message must be a clean Conventional Commit ([commit-messages.md](commit-messages.md)) — normally the PR title.
- **Updating a local branch → rebase onto `main`.** Use rebase when **all** of these hold:
  - you want to pick up the latest `main`;
  - you want a linear, clean history;
  - the branch is **local only** (never pushed), **or** you are the only person working on it;
  - the branch is not protected and not already merged.
  - Workflow:

    ```bash
    git switch feature/tenant-invite   # your feat/… or fix/… branch
    git fetch origin
    git rebase origin/main
    # … resolve conflicts, git rebase --continue …
    git push --force-with-lease origin feature/tenant-invite
    ```

  - Always `--force-with-lease`, never a bare `--force`: it refuses to overwrite if someone else pushed in the meantime.
- **Do NOT rebase when** any of these hold — merge/leave history alone instead:
  - the branch is pushed and **someone else is working on it** (rewriting hashes breaks their clone);
  - it is a **protected branch** (`main`, `release/*`);
  - the branch has **already been merged**;
  - you cannot use `--force-with-lease` safely (shared upstream you do not control).
- **Release branches take fixes by cherry-pick, not merge** — see [workflow.md](workflow.md); do not `git merge main` into a `release/*` branch.

**Examples.**

✓ Good:

```bash
# Stay current on a private feature branch, then re-publish safely.
git fetch origin && git rebase origin/main
git push --force-with-lease origin feature/tenant-invite
# Land it: open a PR and use "Squash and merge" in GitHub.
```

✗ Bad:

```bash
git switch main && git merge feature/x && git push   # direct merge, bypasses PR
git rebase origin/main                                # on a shared branch others pulled
git push --force origin main                          # force-push to a protected branch
```

**Enforcement.** A GitHub ruleset on `main` and `release/*` (require a PR, squash-only merges, block direct and force pushes) — apply it with [`tools/scripts/setup-branch-protection.sh`](../../../tools/scripts/setup-branch-protection.sh), which also sets the repo to allow *only* squash-merge (ADR-0012 follow-up; needs repo admin). Locally, `git-guard branch-protect` (a `core.git` pre-commit hook) blocks direct commits on protected branches, and `check-merge-conflicts` blocks committing unresolved conflict markers. Until the ruleset is applied, "PR + squash only" and the rebase preconditions are additionally **code-review-enforced**.

## See also

- [Git conventions index](README.md)
- [Branch & release workflow](workflow.md) — where squash-merge and cherry-pick fit end to end.
- [Commit messages](commit-messages.md) — the squash commit must be a clean Conventional Commit.
- [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md) — the decision that established this rule.
- [git rebase](https://git-scm.com/docs/git-rebase) · [`--force-with-lease`](https://git-scm.com/docs/git-push#Documentation/git-push.txt---no-force-with-lease)
