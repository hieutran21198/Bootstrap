# 0016. Use git worktrees for parallel AI-agent sessions

- **Status**: Accepted
- **Date**: 2026-07-04
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace now has enough AI-agent and service tooling that one checkout is the bottleneck. Multiple agents can reason independently, but they still edit the same files, share one branch, and collide on stateful local services. The target workflow is one agent session per Git worktree, each on its own branch under `.worktrees/<slug>`, so a feature agent, reviewer agent, and docs agent can run without overwriting each other.

The existing stack already supports most of that shape:

- [ADR-0007](0007-nix-devenv-developer-environment.md) made Nix + devenv + direnv the environment boundary. Each checkout regenerates `.opencode/`, `.claude/`, `.editorconfig`, `.info`, and `go.work` locally.
- [ADR-0012](0012-git-workflow-and-conventions.md) made `git-guard` the single source of truth for branch naming, protected-branch commits, commit messages, and PR titles. The worktree command must reuse `git-guard branch-name`; it must not copy the branch regex.
- `core.git` installs hooks and sets `commit.template` only when `config.git.root == config.core.workspace.root`, which is true for a root devenv entered from a linked worktree. Git hooks also run with the working directory set to the active worktree root.
- Portal Postgres data already lives under the checkout-local `.devenv/state/`; only the TCP port collides. The Docusaurus docs app has the same issue on its default HTTP port.
- `.codegraph/` is gitignored and directory-local, so each worktree can carry its own index.

The decision must therefore settle the small number of shared conventions that keep these independent checkouts deterministic: where worktrees live, how ports are offset, how branches and slugs are derived, how ignored secrets are bootstrapped, and how Git's shared config caveat is handled.

## Decision

We will make Git worktrees the first-class isolation mechanism for parallel AI-agent sessions. Managed worktrees will live under the main checkout's `.worktrees/<slug>` directory, will use git-guard-valid non-protected work branches, and will carry a gitignored `.worktree-offset` marker that Nix reads to offset local service ports.

The implementation contract is [docs/specs/parallel-agent-worktrees.md](../specs/parallel-agent-worktrees.md). The settled decisions are:

1. **Port isolation uses a marker file, not generated Nix or environment variables.** Each managed linked worktree has a root-level `.worktree-offset` file containing one base-10 integer: the actual port offset to add to base ports. The main checkout reserves offset `0` and normally has no marker. Linked worktrees use slot indexes starting at `1`; `portOffset = slot * 10`. The stride is **10** because it is enough for today's Postgres and docs ports while leaving room for near-term local services. `ws-worktree` allocates by scanning live worktrees with `git worktree list --porcelain`, reading their markers, and choosing the lowest free positive slot, so removing a worktree recycles its slot. Nix reads the marker through the current Git worktree root at eval time; an absent marker means offset `0`.
2. **The Nix integration belongs in `packages/nix/core/worktree/`.** Port offsets have to affect `core.services.postgres`, so an `extra/` module would split the source of truth. The core module exposes `core.worktree.portOffset` with a default of `0`, packages `ws-worktree`, and registers it in `core.workspace.toolchainCommandInfos`. `core.services.postgres` consumes the offset by using `actualPort = core.services.postgres.port + core.worktree.portOffset` for the devenv Postgres service, `POSTGRES_PORT`, and `pg-info`. `apps/workspace-docs` consumes the same offset by running Docusaurus dev/serve on `3000 + core.worktree.portOffset`.
3. **`ws-worktree` is a Go tool under `tools/generators/ws-worktree/`.** It follows the existing `ws-tree` pattern: a small `package main`, unit-testable parsing/allocation helpers, built with `pkgs.buildGoModule` from the `tools` module, and wrapped by Nix with `git` and `git-guard` on `PATH`. A bash script was rejected because the branch, slug, marker, and include-file behavior needs tests.
4. **The command surface is intentionally small and branch-safe.** Fresh work uses `ws-worktree feature/<desc>` and branches from `main` (using `origin/main` after fetch when available, otherwise local `main`). Existing refs use `ws-worktree --ref <ref> [--branch <branch>]`; PRs use `ws-worktree --pr <number> [--branch <branch>]`, defaulting to `chore/pr-<number>` when no branch is supplied. Listing and cleanup are `ws-worktree --list` and `ws-worktree --remove <branch|slug|path> [--force]`. The slug is the target branch with `/` replaced by `-`; collisions fail rather than auto-suffixing. Every target branch is validated by shelling to `git-guard branch-name` and `git-guard branch-protect` so `main` and `release/*` are not used as agent work branches.
5. **Fresh worktrees copy only opted-in gitignored local files.** We will adopt a versioned root `.worktreeinclude` file using gitignore syntax. `ws-worktree` copies files that both match `.worktreeinclude` and are ignored by Git, preserving relative paths into the new worktree. The initial include policy is `.env*` and `deploy/local/.env`; tracked files are never copied and secret values are never printed.
6. **Code indexes are per worktree and explicit.** We will not symlink `.codegraph/` from the main checkout. `ws-worktree` prints `codegraph init` as a next step, but never runs indexing itself. This keeps each agent's code graph aligned with that worktree's branch.
7. **Shared Git config remains shared for now.** Git's repository-local config is shared by linked worktrees unless `extensions.worktreeConfig=true`. We will not enable that extension yet. The existing `git config --local commit.template "<worktree>/.gitmessage"` line may point the shared config at the last-entered worktree, but `.gitmessage` is tracked and identical in every worktree; the compatibility cost of enabling per-worktree config is not justified. Hook installation still fires when entering a linked worktree's root devenv, and Git hooks run normally inside linked worktrees.
8. **Ignored state is explicit.** The implementation will add `.worktrees/` and `.worktree-offset` to `.gitignore`. `.worktreeinclude` is **not** gitignored; it is versioned policy, not local state.

## Consequences

- **Positive**:
  - Multiple agents can work concurrently without file edits or branch state colliding.
  - Stateful local services can run concurrently because every managed worktree gets deterministic ports: main stays at the base ports, the first linked worktree adds `10`, the second adds `20`, and so on.
  - Branch naming remains governed by `git-guard`; the worktree tool does not create a second regex or convention surface.
  - Per-worktree `.codegraph/`, `.opencode/`, `.claude/`, `.devenv/state/`, and copied `.env*` files make each agent session self-contained.
- **Negative**:
  - The marker file is another local-state artifact that can be corrupted or manually removed. The tool and Nix module must fail loudly on invalid marker content rather than guessing.
  - Slug collisions are possible (`feature/a-b` and `feature/a/b` both map to `feature-a-b`). We accept an explicit failure over silent suffixes so paths stay predictable.
  - Copying `.env*` improves bootstrap but expands local secret duplication. The copy is limited to gitignored files selected by `.worktreeinclude`, and the files remain under gitignored worktrees.
  - Leaving Git config shared means a long-lived shell can observe `commit.template` set by another worktree until shell entry runs again. We accept this because the template content is identical and avoiding `extensions.worktreeConfig` keeps Git compatibility simpler.
- **Neutral**:
  - Worktrees live inside the repository under `.worktrees/`, so the main checkout's `.gitignore` must hide the entire tree.
  - `deploy/local` ZITADEL docker-compose isolation is not part of this decision; it remains shared/serialized.
  - OpenCode has no first-class worktree command. Agents start in the worktree directory and rely on devenv/direnv to regenerate directory-local config.

## Alternatives considered

- **Environment variable read with `builtins.getEnv`.** Rejected because it makes Nix evaluation depend on ambient shell state. A marker file is explicit, inspectable, and survives shell restarts.
- **Generated `devenv.local.nix` per worktree.** Rejected because it creates generated Nix code in every checkout and invites local edits to become hidden configuration. A numeric marker keeps the per-worktree state data-only.
- **Put worktree support in `packages/nix/extra/worktree/`.** Rejected because Postgres port wiring has to happen inside `core.services.postgres`; keeping the offset in `core/` avoids an optional module reaching back into mandatory service behavior.
- **Bash `ws-worktree` script.** Rejected because the command needs testable branch validation, slug collision handling, marker parsing, worktree-list parsing, and `.worktreeinclude` filtering. The existing Go `ws-tree` generator already gives this workspace a better pattern.
- **Dynamic free-port probing with `lsof`.** Rejected as the primary allocation mechanism because ports should be deterministic and recoverable from checked worktree state. We allocate slots from live worktrees, not from the current process table.
- **Monotonic worktree counter.** Rejected because removed worktrees would leave gaps forever and eventually produce surprising high ports. Scanning live worktrees recycles slots naturally.
- **Shared `.codegraph/` symlink.** Rejected because divergent branches would share a stale or incorrect code graph. Per-worktree init is slower once but correct.
- **Enable `extensions.worktreeConfig` now.** Rejected because the only current shared-config issue is the commit template path, whose content is identical across worktrees. The compatibility and migration cost can wait until there is a real per-worktree Git config need.

## References

- [Implementation spec: parallel agent worktrees](../specs/parallel-agent-worktrees.md)
- [ADR-0007: Manage the developer environment with Nix + devenv](0007-nix-devenv-developer-environment.md)
- [ADR-0012: Git workflow, commit, and pull-request conventions](0012-git-workflow-and-conventions.md)
- [`packages/nix/core/git/default.nix`](../../packages/nix/core/git/default.nix) — hook wiring and shared `commit.template` setup.
- [`packages/nix/core/services/postgres/default.nix`](../../packages/nix/core/services/postgres/default.nix) — base Postgres port and `POSTGRES_PORT` export.
- [`packages/nix/core/workspace/default.nix`](../../packages/nix/core/workspace/default.nix) and [`tools/generators/ws-tree/`](../../tools/generators/ws-tree/) — Go tool packaging pattern to mirror.
- [`tools/validators/git-guard/branch.go`](../../tools/validators/git-guard/branch.go) — branch-name validation source of truth.
- [Git `worktree` documentation](https://git-scm.com/docs/git-worktree) — linked worktrees, one-branch-one-worktree invariant, `list --porcelain`, removal/prune, and shared vs worktree-specific config.
- [Git hooks documentation](https://git-scm.com/docs/githooks) — hook working directory behavior.
- [Git config documentation](https://git-scm.com/docs/git-config) — config scopes and `--worktree` / `extensions.worktreeConfig`.
- [Claude Code worktrees documentation](https://code.claude.com/docs/en/worktrees.md) — `.worktreeinclude`, per-session worktrees, and explicit cleanup guidance.
- [OpenCode CLI documentation](https://opencode.ai/docs/cli) — OpenCode has CLI/session commands but no first-class worktree command; a worktree is a directory to start OpenCode in.
- Prior-art repositories cited during design: `alirezarezvani/claude-skills` git-worktree manager references, `getlago/lago-front` `scripts/lago-worktree.sh`, OpenEMR devops worktree compose overrides, and inside-repo `.worktrees/` examples from PJUllrich/devcontainer, kagenti, and claude-ctrl.
