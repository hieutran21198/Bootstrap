# Branch & Release Workflow

> **Scope**: every branch, merge, and release cut against this repository's `origin`.
> **Status**: Active
> **Decided by**: [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md)
> **Last reviewed**: 2026-07-01

**Rule.** `main` is the always-deployable trunk (merging to it deploys to `dev`); cut short-lived `feature/`, `fix/`, `hotfix/` branches from `main` and land them back only through a reviewed, CI-green pull request, and stabilise a big release on a `release/` branch cut from `main` while small releases and hotfixes are cherry-picked from `main` onto that branch.

**Rationale.** A single trunk that is always ready to deploy removes the "which branch is real?" question and makes `dev` a faithful mirror of merged work. Short-lived branches keep integration small and conflicts cheap. A dedicated `release/` branch gives a place to stabilise a release without freezing the trunk, and cherry-pick keeps a hotfix surgical — one known commit moved onto the release, not "everything newer on `main`." The alternative (a permanent `develop` integration branch, à la GitFlow) buys nothing here because deploy already happens on merge to `main`.

**Apply.**

- **`main` is sacred and deployable.** It holds the latest reviewed code and is what deploys to `dev` on every merge. Never push to it directly (see [merge-vs-rebase.md](merge-vs-rebase.md)); never leave it red.
- **Branch off `main`** for all work, named by intent:
  - `feature/<short-kebab-desc>` — new capability.
  - `fix/<short-kebab-desc>` — bug fix targeting `main`.
  - `hotfix/<short-kebab-desc>` — urgent fix destined for a live release.
  - Other prefixes follow the commit `type` where it reads naturally (`docs/`, `chore/`, `refactor/`, `ci/`). Optionally suffix with an issue key: `feature/1234-tenant-invite`.
- **Open a PR when the work is ready to review** (not before it compiles and its tests pass locally). Keep branches short-lived — rebase onto `main` to stay current rather than letting them age.
- **Merge only after approval + green CI**, via squash-merge ([merge-vs-rebase.md](merge-vs-rebase.md)). Delete the branch after merge.
- **Deploy to `dev` is automatic** on merge to `main` — assume every merge ships.
- **Big / stable release**: cut a release branch from `main`:
  - `release/<semver>` (e.g. `release/1.4.0`), or with a sprint prefix when tracked by sprint: `release/<sprint>-<semver>` (e.g. `release/s12-1.4.0`).
  - Stabilise on that branch (release-blocking fixes only); tag the release commit (`v1.4.0`).
- **Small release / hotfix**: do not re-cut a branch — **cherry-pick** the specific commit(s) from `main` onto the existing `release/*` branch:

  ```bash
  git checkout release/1.4.0
  git fetch origin
  git cherry-pick <sha>            # -x records the source sha in the message
  git push origin release/1.4.0
  ```

  Land the fix on `main` first (via PR) so the release only ever cherry-picks code that already exists on the trunk.

**Examples.**

✓ Good:

```bash
# Feature flow: branch off main, PR, squash-merge, auto-deploy to dev.
git switch main && git pull --rebase origin main
git switch -c feature/tenant-invite
# … work, commit (Conventional Commits) …
git push -u origin feature/tenant-invite   # then open a PR

# Release flow: stabilise a big release, hotfix by cherry-pick.
git switch main && git switch -c release/1.4.0
git push -u origin release/1.4.0
git cherry-pick -x 9f2c1ab                 # a hotfix already merged to main
```

✗ Bad:

```bash
git switch -c feature/x release/1.4.0   # branched off a release, not main
git switch main && git commit -am "quick fix" && git push   # direct push to main
git switch release/1.4.0 && git merge main   # dragged all of main into a release
```

**Enforcement.** Layered:

- **Local** (`core.git` hooks, `packages/nix/core/git/default.nix`): `git-guard branch-protect` (pre-commit) blocks direct commits on `main`/`release/*`; `git-guard branch-name` (pre-push) rejects off-pattern branch names.
- **CI** ([`.github/workflows/pr-validate.yml`](../../../.github/workflows/pr-validate.yml)): validates branch name and PR title on every PR.
- **Server-side**: a GitHub ruleset on `main` and `release/*` (require a PR + passing checks, block direct/force pushes) — apply it with [`tools/scripts/setup-branch-protection.sh`](../../../tools/scripts/setup-branch-protection.sh) (needs repo admin; ADR-0012 follow-up). Until the ruleset is applied, trunk-only-via-PR is additionally **code-review-enforced**. Release/cherry-pick discipline is review-enforced.

## See also

- [Git conventions index](README.md)
- [Merge vs rebase](merge-vs-rebase.md) — why direct merge to `main` is forbidden and when rebase is safe.
- [Pull requests](pull-requests.md) — the review gate every branch passes through.
- [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md) — the decision that established this workflow.
