# 0012. Git workflow, commit, and pull-request conventions

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace already gates commit messages at the `commit-msg` stage — [ADR-0007](0007-nix-devenv-developer-environment.md) wires `commitizen` into `core.git` so every commit must be a Conventional Commit. But the *process* around those commits was never written down: how branches are cut, how work reaches `main`, how `main` reaches an environment, how a release is stabilised, and what merge strategy keeps history sane. That leaves a vacuum where each contributor invents their own branching and merging habits, and where an AI agent working the repo has no rule to follow.

The constraints that shape the answer:

- The remote is GitHub (`origin`), so pull requests, branch protection, and `.github/PULL_REQUEST_TEMPLATE.md` are the native mechanisms.
- The intended delivery model is **deploy-on-merge**: `main` is the always-deployable trunk and merging to it ships to the `dev` environment immediately (`.github/workflows/`).
- The repo is small and mostly single- or few-contributor, so a heavyweight long-lived-branch model (a permanent `develop`, release/hotfix branch pairs) is more ceremony than value.
- Conventional Commits is already mandatory, so the workflow should lean into what it unlocks: automatable changelogs and SemVer inference.

Conventions in this workspace are recorded per topic under `docs/conventions/`, one rule per file, each justified by an ADR ([conventions/README.md](../conventions/README.md)). There is no `git/` topic yet.

## Decision

**We will adopt a `main`-centric trunk workflow — short-lived branches, pull-request-gated squash-merges to a protected always-deployable `main`, rebase to keep local branches current, and release branches cut (or cherry-picked) from `main` — and record it as a new `docs/conventions/git/` topic.** The topic holds four living rule files:

1. **[workflow.md](../conventions/git/workflow.md)** — `main` is the latest ready-to-deploy code (auto-deploys to `dev` on merge); `feature/`, `fix/`, `hotfix/` … branches are cut from `main`; a big/stable release is cut to `release/{sprint?}{semver}` from `main`; small releases and hotfixes are **cherry-picked** from `main` onto the release branch.
2. **[commit-messages.md](../conventions/git/commit-messages.md)** — [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `<type>(<scope>): <subject>` with the allowed type set `feat/fix/docs/style/refactor/test/chore/perf/ci/revert`, seeded by a committed `.gitmessage` template wired through `core.git`.
3. **[merge-vs-rebase.md](../conventions/git/merge-vs-rebase.md)** — direct merge to `main` is forbidden; PRs land via **squash-merge**; **rebase** is for keeping a *local, unshared* branch current on `main` (`git pull --rebase`/`git rebase origin/main`, push with `--force-with-lease`) and is never used on pushed-shared, protected (`main`, `release/*`), or already-merged branches.
4. **[pull-requests.md](../conventions/git/pull-requests.md)** — PR title uses the commit header format `<type>(<scope>): <description>`; the PR body follows `.github/PULL_REQUEST_TEMPLATE.md`; a reviewer checklist defines the approval bar.

Supporting artefacts created with this decision:

- `.gitmessage` (repo root) — the commit-message scaffold; `core.git` sets `commit.template` on shell entry so it is active without manual `git config`.
- `.github/PULL_REQUEST_TEMPLATE.md` — the PR description template GitHub auto-loads.

## Consequences

- **Positive**:
  - One obvious path from idea to `dev`: branch off `main` → PR → review + green CI → squash-merge → auto-deploy. No permanent `develop` branch to keep in sync.
  - Squash-merge keeps `main` history one-commit-per-PR: readable, bisectable, and revertible as a unit; intra-PR "wip"/"fix typo" noise never reaches `main`.
  - Conventional Commit subjects on every squashed commit make changelog generation and SemVer bumps automatable later.
  - Release branches give stabilisation isolation without blocking trunk; cherry-pick keeps hotfixes surgical and traceable back to their `main` commit.
- **Negative**:
  - Rebasing shared branches is genuinely dangerous; the rule leans hard on `--force-with-lease` and a "local-only" precondition that contributors must internalise.
  - Squash-merge discards per-commit authorship granularity inside a PR (fine for this repo; noted for the record).
  - Cherry-picking releases is manual bookkeeping — the release branch's history diverges from `main` and must be curated by hand.
- **Neutral**:
  - The conventions taxonomy gains a `git/` topic (one `README.md` + four rule files).
  - Full enforcement of "no direct merge to `main`" and "PR + green CI required" depends on **GitHub branch-protection / ruleset** configuration, which is a repo-settings concern GitHub owns — not something `core.git` (a devenv/pre-commit module) can assert. Applying that ruleset is a follow-up (see References); until then the rule is review-enforced.

## Alternatives considered

- **GitFlow (permanent `develop` + `release`/`hotfix` branch pairs).** Rejected: the deploy-on-merge-to-`main` model makes a long-lived `develop` redundant, and the extra ceremony is disproportionate for a small-contributor repo. We keep GitFlow's *idea* of a release branch for stabilisation, without its permanent integration branch.
- **Merge-commit (`--no-ff`) instead of squash for PRs.** Rejected: it drags every intermediate WIP commit onto `main`, muddying history and changelog inference. Squash gives one clean Conventional Commit per PR.
- **Rebase-merge for PRs.** Rejected: replays each PR commit onto `main`, which both requires per-commit Conventional-Commit hygiene and produces multiple `main` commits per PR (harder to revert atomically). Rebase stays a *local hygiene* tool, not the merge strategy.
- **Tag-only releases, no release branch.** Rejected: a tag on `main` gives no place to stabilise or to land a hotfix without pulling in everything newer on `main`. The `release/*` branch + cherry-pick keeps releases isolated and surgical.

## References

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — the commit-message grammar `commitizen` enforces.
- [ADR-0007](0007-nix-devenv-developer-environment.md) — the devenv model; `core.git` (`packages/nix/core/git/default.nix`) wires `commitizen` and now `commit.template`.
- [conventions/git/](../conventions/git/) — the four rule files this decision established.
- [conventions/README.md](../conventions/README.md) — conventions taxonomy and lifecycle.
- Follow-up: apply a GitHub branch-protection ruleset on `main` and `release/*` (require PR, require passing checks, block direct pushes and force-pushes) so the "no direct merge / green CI required" rules are machine-enforced, not just review-enforced.
