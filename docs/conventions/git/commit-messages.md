# Commit Messages

> **Scope**: every commit in this repository, and the squashed commit each pull request lands as.
> **Status**: Active
> **Decided by**: [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md), [ADR-0007](../../adrs/0007-nix-devenv-developer-environment.md)
> **Last reviewed**: 2026-07-01

**Rule.** Write every commit as a [Conventional Commit 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — `<type>(<scope>): <subject>`, an optional body, and optional footers — using only the allowed type set `feat / fix / docs / style / refactor / test / chore / perf / ci / revert`.

**Rationale.** A machine-readable commit grammar turns history into a data source: changelogs and SemVer bumps can be generated (`feat` → MINOR, `fix` → PATCH, `BREAKING CHANGE` → MAJOR), and a human reading `git log` sees intent at a glance. It is not optional here — `commitizen` rejects non-conforming messages at the `commit-msg` stage ([ADR-0007](../../adrs/0007-nix-devenv-developer-environment.md)) — so following the format is the difference between a commit that lands and one that bounces.

**Apply.**

- **Format:**

    ```text
    <type>(<scope>): <subject>

  [optional body]

  [optional footer(s)]
  ```

- **Type** — one of the allowed set:

  | Type       | Use for                                                        | SemVer |
  | ---------- | -------------------------------------------------------------- | ------ |
  | `feat`     | a new feature                                                  | MINOR  |
  | `fix`      | a bug fix                                                      | PATCH  |
  | `docs`     | documentation only                                             | —      |
  | `style`    | formatting / whitespace, no behaviour change                   | —      |
  | `refactor` | code change that neither fixes a bug nor adds a feature        | —      |
  | `test`     | adding or correcting tests                                     | —      |
  | `chore`    | build, tooling, deps, housekeeping                             | —      |
  | `perf`     | performance improvement                                        | PATCH  |
  | `ci`       | CI/CD configuration and scripts                                | —      |
  | `revert`   | reverts a previous commit (footer: `Refs: <sha>`)              | —      |

- **Scope** *(optional)* — a noun for the area touched, in parentheses: the module, package, or service (`feat(portal): …`, `fix(gormx): …`, `chore(nix): …`). Omit it if the change is cross-cutting.
- **Subject** — imperative mood, lower-case start, **no trailing period**; keep it short — aim for ≤ 50 chars (hard limit 72) ("add tenant invite flow", not "Added tenant invite flow.").
- **Body** *(optional)* — one blank line after the subject; explain **what and why**, not how; wrap at ~72 columns.
- **Footers** *(optional)* — one blank line after the body, git-trailer format (`Token: value`, token uses `-` for spaces):
  - Breaking changes: `!` after the type/scope (`feat(api)!: …`) and/or a `BREAKING CHANGE: <desc>` footer (uppercased).
  - Issue links: `Refs: #123`, `Closes #123`.
  - Attribution: `Reviewed-by: …`, `Co-authored-by: …`.
- **Use the template.** `core.git` sets `commit.template` to the repo's [`.gitmessage`](../../../.gitmessage), so `git commit` (no `-m`) opens the editor pre-seeded with this format and a checklist. Prefer it over one-line `-m` commits for anything non-trivial.
- **Squash lands one commit.** Because PRs squash-merge ([merge-vs-rebase.md](merge-vs-rebase.md)), the **squash commit message** is the one that reaches `main` and feeds changelogs — make it a clean Conventional Commit (usually the PR title). Intra-PR "wip" commits are fine locally; they disappear on squash.

**Examples.**

✓ Good:

```text
feat(portal): add tenant invitation flow

Invitations are issued per organization and expire after 72h. The token
is a UUIDv7 so it sorts by issue time and validates at the boundary.

Closes #142
```

```text
fix(gormx): bind scope GUC transaction-locally

BREAKING CHANGE: New() now requires a *gorm.Config; callers must pass one.
```

✗ Bad:

```text
Updated stuff.                     # no type, capitalised, vague, trailing period
feature: add invites               # "feature" is not an allowed type (use feat)
fix(portal): Fixed the bug where.  # capitalised subject, trailing period, no info
```

**Enforcement.** Two `commit-msg` hooks wired by `core.git` (`packages/nix/core/git/default.nix`): `commitizen` rejects any non–Conventional-Commit message, and **`git-guard commit-msg`** ([`tools/validators/git-guard/`](../../../tools/validators/git-guard/)) additionally enforces this workspace's *closed* type set and subject style (lower-case start, no trailing period, length). On a PR, CI ([`.github/workflows/pr-validate.yml`](../../../.github/workflows/pr-validate.yml)) revalidates the PR title (the squash commit) and, advisorily, the branch's commit subjects. The `.gitmessage` template (also wired by `core.git`) makes the format the path of least resistance.

## See also

- [Git conventions index](README.md)
- [`.gitmessage`](../../../.gitmessage) — the commit template `core.git` activates.
- [Pull requests](pull-requests.md) — the PR title reuses this header format and becomes the squash commit.
- [ADR-0012](../../adrs/0012-git-workflow-and-conventions.md) — the decision that established this rule.
- [ADR-0007](../../adrs/0007-nix-devenv-developer-environment.md) — the devenv model that wires `commitizen`.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — the upstream specification.
