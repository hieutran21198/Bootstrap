# Git conventions

Workspace-wide rules for how we branch, commit, review, and release with Git. Each rule below is a standalone file; this README is the index.

> **Scope**: every contributor and automated agent working in this repository — all branches, commits, and pull requests against `origin`.
> **Status**: Active
> **Decided by**: [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md)
> **Last reviewed**: 2026-07-01

## Index

| #   | Document                                     | One-liner                                                                                       |
| --- | -------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1   | [Branch & release workflow](workflow.md)     | `main` is the deployable trunk; short-lived branches off `main`; release branches by cut or cherry-pick. |
| 2   | [Commit messages](commit-messages.md)        | Conventional Commits `<type>(<scope>): <subject>`, seeded by the `.gitmessage` template.        |
| 3   | [Merge vs rebase](merge-vs-rebase.md)        | Squash-merge PRs into `main`; rebase only local, unshared branches to stay current.             |
| 4   | [Pull requests](pull-requests.md)            | PR title = commit header; body from the PR template; reviewer checklist is the approval bar.    |

## Enforcement (how these rules are checked)

These conventions are enforced by tooling, not just review:

- **`git-guard`** ([`tools/validators/git-guard/`](../../../tools/validators/git-guard/)) — the Go validator (commit message, branch name, PR title) that is the single source of truth for both local hooks and CI.
- **Local hooks** (`core.git`, [`packages/nix/core/git/default.nix`](../../../packages/nix/core/git/default.nix)) — `commitizen` + `git-guard` at `commit-msg`, `branch-protect` at pre-commit, `branch-name` at pre-push.
- **CI** ([`.github/workflows/pr-validate.yml`](../../../.github/workflows/pr-validate.yml)) — revalidates PR title, branch name, and commit subjects on every PR.
- **Server-side ruleset** — [`tools/scripts/setup-branch-protection.sh`](../../../tools/scripts/setup-branch-protection.sh) applies the `main`/`release/*` protection (require PR + green CI, squash-only, no direct/force push).
- **`git-workflow` skill** — teaches agents these rules so they self-comply.

## See also

- [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md) — the decision that established this topic.
- [Workspace conventions index](../README.md) — sibling topics.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — the commit grammar `commitizen` enforces.
- [`.gitmessage`](../../../.gitmessage) · [`.github/PULL_REQUEST_TEMPLATE.md`](../../../.github/PULL_REQUEST_TEMPLATE.md) — the templates these rules wire in.
