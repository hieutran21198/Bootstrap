{
  config,
  lib,
  ...
}:
{
  options.core.ai.skills.git-workflow =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = ''
          ---
          name: git-workflow
          description: This workspace's Git conventions — branch/release workflow, Conventional Commits, merge vs rebase, and pull-request rules — plus the git-guard validator that enforces them. Use when branching, committing, merging, rebasing, cutting a release, or opening/reviewing a pull request.
          user-invocable: false
          allowed-tools: Read, Grep, Glob, Bash
          ---

          # Git Workflow

          How work moves from a branch to `dev` in this repo, and the rules `git-guard` and
          CI will reject you for breaking. The authority is [`docs/conventions/git/`](../../../docs/conventions/git/);
          this skill is the operational summary. When a rule and this skill disagree, the
          convention file wins.

          ## When this applies

          - Creating a branch, committing, merging, or rebasing.
          - Cutting or patching a release.
          - Opening or reviewing a pull request.
          - Running a parallel agent session in its own Git worktree.

          ## The one-paragraph model

          `main` is the always-deployable trunk — **merging to it deploys to `dev`**. You
          never push to `main` directly. Cut a short-lived branch off `main`, commit with
          Conventional Commits, open a PR when ready, and land it with **squash-merge**
          after review + green CI. Releases are cut to `release/<version>` from `main`;
          hotfixes are **cherry-picked** from `main` onto the release branch.

          ## Branches (cut from `main`)

          - `feature/<kebab-desc>` · `fix/<kebab-desc>` · `hotfix/<kebab-desc>` — the common cases.
          - Other prefixes follow the commit type where natural: `docs/`, `chore/`, `refactor/`, `ci/`, `perf/`, `style/`, `test/`.
          - `release/<semver>` or `release/<sprint>-<semver>` (e.g. `release/1.4.0`, `release/s12-1.4.0`).
          - Optional issue key suffix: `feature/1234-tenant-invite`.
          - **Never commit directly on `main` or `release/*`** — the `branch-protect` hook blocks it.

          ## Worktrees (parallel agent sessions)

          Run each parallel agent session in its own Git worktree so agents never share a
          dirty tree, a branch, or a local service port. Authority:
          [`docs/conventions/git/worktrees.md`](../../../docs/conventions/git/worktrees.md).

          - **One session = one worktree = one branch.** Create it with `ws-worktree`,
            never raw `git worktree add` — the tool writes the port-offset marker, guards
            `.gitignore`, and copies your gitignored env files:
            ```bash
            ws-worktree feature/tenant-invite   # new .worktrees/feature-tenant-invite off main
            cd .worktrees/feature-tenant-invite
            direnv allow                        # regenerate directory-local env + agent config
            codegraph init                      # this worktree's own code index
            opencode                            # start the agent in this directory
            ```
          - **Branch names are git-guard-valid and non-protected.** `ws-worktree` shells to
            `git-guard branch-name` / `git-guard branch-protect`, so `main` and `release/*`
            are rejected as work branches. Use `--ref <ref>` / `--pr <number>` to base a new
            compliant branch on an existing ref or PR.
          - **Ports are offset automatically.** Each worktree carries a `.worktree-offset`
            marker (main = base, +10 per worktree), so portal Postgres and the docs server
            run concurrently without collision. Don't hand-edit or delete the marker.
          - **Clean up explicitly — never `rm -rf`:**
            ```bash
            ws-worktree --remove feature/tenant-invite   # then: git worktree prune
            ```
            Removal frees the port slot for reuse; it does not delete the branch.

          ## Commits (Conventional Commits 1.0.0)

          ```
          <type>(<scope>): <subject>

          [optional body]

          [optional footer(s)]
          ```

          - **type** — one of exactly: `feat fix docs style refactor test chore perf ci revert`. Nothing else (not `build`, not `feature`).
          - **scope** — optional noun for the area: `(portal)`, `(gormx)`, `(nix)`.
          - **subject** — imperative, lower-case start, **no trailing period**, aim ≤ 50 chars (hard limit 72).
          - **body** — blank line after subject; explain what/why.
          - **breaking** — `!` after type/scope and/or a `BREAKING CHANGE:` footer.
          - The editor is pre-seeded from `.gitmessage`. Prefer `git commit` (no `-m`) for non-trivial changes.

          ## Merge vs rebase

          - **Into `main`: squash-merge via PR only.** No direct merge, no direct push. The squash commit message must be a clean Conventional Commit (usually the PR title).
          - **Rebase only a local, unshared branch** to stay current:
            ```bash
            git fetch origin && git rebase origin/main
            git push --force-with-lease origin <branch>   # never bare --force
            ```
          - **Do NOT rebase** a branch that is shared/pushed-and-others-use-it, protected (`main`, `release/*`), or already merged.
          - **Release branches take fixes by cherry-pick**, never `git merge main`:
            ```bash
            git switch release/1.4.0 && git fetch origin
            git cherry-pick -x <sha>        # sha already merged to main
            ```

          ## Pull requests

          - **Title** = commit header: `<type>(<scope>): <description>`.
          - **Body** = fill every section of `.github/PULL_REQUEST_TEMPLATE.md` (What / Why / How / Testing / Screenshots / Checklist); link issues (`Closes #123`).
          - Keep PRs small and single-purpose. Open when it compiles, tests pass, and you have self-reviewed.
          - When **reviewing**, run the reviewer checklist in [`pull-requests.md`](../../../docs/conventions/git/pull-requests.md) (scope, correctness, tests, conventions, security/RLS, simplicity, docs, deployability).

          ## Self-check with git-guard (do this before committing / pushing / opening a PR)

          `git-guard` is the validator the hooks and CI use — run it yourself to fail fast:

          ```bash
          git-guard branch-name                 # current branch matches an allowed pattern?
          git-guard branch-protect              # are you about to commit on a protected branch?
          printf '%s\n' "feat(portal): add x" | { f=$(mktemp); cat >"$f"; git-guard commit-msg "$f"; }
          git-guard pr-title "feat(portal): add tenant invite flow"
          git-guard commit-range origin/main HEAD   # subjects of the commits you'd open a PR with
          ```

          Exit 0 = clean. Non-zero = it prints the exact rule you broke. If a hook blocks
          you, fix the message/branch — do not reach for `--no-verify`.

          ## Anti-patterns

          - Committing on `main`/`release/*`, or `git push`-ing to them directly.
          - A commit `type` outside the closed set, a capitalised subject, or a trailing period.
          - `git merge main` into a release branch (use cherry-pick).
          - `git push --force` (use `--force-with-lease`) or rebasing a shared/protected/merged branch.
          - Bypassing hooks with `--no-verify` to dodge a convention.
          - A vague PR title (`updates`, `wip`) — it becomes the squash commit on `main`.
          - Sharing one branch across two worktrees, or `rm -rf`-ing a worktree instead of `ws-worktree --remove` + `git worktree prune`.
        '';
        readOnly = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [
          "backend-engineer"
          "release-engineer"
          "frontend-engineer"
          "scribe"
          "dev-environment"
        ];
        description = "Agents this skill is available to (allowed); every other agent is denied.";
      };
    };
}
