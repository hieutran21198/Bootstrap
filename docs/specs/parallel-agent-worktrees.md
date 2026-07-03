# Parallel agent worktrees

> **Status**: Accepted
> **Authors**: Architect
> **Last reviewed**: 2026-07-04
> **Tracks**: [ADR-0016](../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md)

## Problem

AI agents need to run in parallel against the same repository without sharing a dirty worktree, branch, Postgres port, docs server port, generated agent config, or code index. Git worktrees provide file and branch isolation, but this workspace still needs a deterministic local convention and tooling layer so every worktree is created the same way and every service port is offset without hand-editing Nix files.

This spec is the implementation contract for the Go `ws-worktree` command, the Nix `core.worktree` module, and the docs/skill updates that make the workflow durable.

## Goals

- Create managed Git worktrees under the main checkout's `.worktrees/<slug>` directory.
- Keep each agent session on a git-guard-valid, non-protected work branch.
- Allocate deterministic per-worktree port offsets so portal Postgres and the workspace docs server can run concurrently.
- Bootstrap gitignored local env files through `.worktreeinclude` without copying tracked files.
- Keep code indexes, agent config, devenv state, and service data directory-local.
- Document the convention and teach the `git-workflow` skill the create/use/cleanup flow.

## Non-goals

- No changes to `git-guard` branch, commit, PR, or protected-branch rules.
- No automatic `direnv allow`, `devenv up`, `codegraph init`, or agent launch.
- No shared or symlinked `.codegraph/` index.
- No per-worktree isolation for `deploy/local` ZITADEL docker-compose host ports.
- No GitHub branch-protection or PR workflow changes.
- No automatic remote branch deletion during worktree cleanup.

## Background

- [ADR-0016](../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) records the decisions this spec implements.
- `packages/nix/core/git/default.nix` builds `git-guard`, installs hooks, and sets `commit.template` on root shell entry.
- `packages/nix/core/services/postgres/default.nix` owns `core.services.postgres.port`, passes it to devenv's Postgres service, exports `POSTGRES_PORT`, and renders `pg-info`.
- `packages/nix/core/workspace/default.nix` builds `ws-tree` with `pkgs.buildGoModule`, registers command descriptions through `core.workspace.toolchainCommandInfos`, generates `.info`/`.editorconfig`, and prints `ws-info` on shell entry.
- `services/portal/devenv.nix` sets the portal Postgres base port from `secrets.POSTGRES_PORT` and exposes migrate/pg-info commands.
- `apps/workspace-docs/devenv.nix` wraps Docusaurus `npm run start` / `serve`, which otherwise default to port `3000`.
- `tools/validators/git-guard/branch.go` accepts `feature|fix|hotfix|docs|chore|refactor|ci|perf|style|test` work branches plus `main` and `release/*`; `ws-worktree` must call the CLI instead of duplicating that regex.

## Design

### Directory layout and identity

- The managed worktree parent is the **main worktree** path reported by the first record from `git worktree list --porcelain`, plus `/.worktrees`.
- A managed worktree path is `.worktrees/<slug>` under that main worktree.
- The slug is derived from the target branch by replacing `/` with `-` and leaving all other valid branch characters unchanged.
- If the slug path already exists, or if `git worktree list --porcelain` already contains a different worktree at that path, `ws-worktree` fails. It must not auto-suffix slugs.
- Each managed linked worktree contains a root-level `.worktree-offset` marker. The marker content is a single base-10 integer plus optional trailing newline; it is the actual port offset, not the slot index.

Examples:

| Branch | Slug | Slot | Marker | Postgres if base `5432` | Docs if base `3000` |
| ------ | ---- | ---- | ------ | ----------------------- | ------------------- |
| main checkout | — | 0 | absent | 5432 | 3000 |
| `feature/tenant-invite` | `feature-tenant-invite` | 1 | `10` | 5442 | 3010 |
| `fix/rls-policy` | `fix-rls-policy` | 2 | `20` | 5452 | 3020 |

### Port allocation

- `portStride = 10`.
- Slot `0` is reserved for the main checkout.
- Managed linked worktrees use positive slots: `1`, `2`, `3`, ...
- `portOffset = slot * portStride`.
- To allocate, `ws-worktree`:
  1. Runs `git worktree list --porcelain`.
  2. Filters worktree paths under the main worktree's `.worktrees/` directory.
  3. Reads each live managed worktree's `.worktree-offset` marker.
  4. Fails on a missing, negative, non-integer, or non-stride-aligned marker in a managed worktree.
  5. Chooses the lowest positive slot not present in the live marker set.
- Removed worktrees do not reserve slots. The tool may run `git worktree prune` before listing; if it does not, it must ignore records whose worktree path no longer exists only after printing a prune hint.
- Allocation is deterministic and does not use a monotonic counter or dynamic `lsof` probing.

### Nix module contract

Add `packages/nix/core/worktree/default.nix` and import it from `packages/nix/core/default.nix`.

Options:

- `core.worktree.enable` — normal module enable flag.
- `core.worktree.markerFileName` — string, default `.worktree-offset`.
- `core.worktree.portStride` — integer, default `10`.
- `core.worktree.portOffset` — read-only integer. When enabled, read `${config.git.root}/.worktree-offset`; when the file is absent, use `0`.

Behavior:

- Invalid marker content fails Nix evaluation with a clear message naming `.worktree-offset`.
- `portOffset` must be `>= 0` and divisible by `portStride`.
- The module builds `ws-worktree` from `tools/generators/ws-worktree` using the same `pkgs.buildGoModule` pattern as `ws-tree`.
- The wrapped `ws-worktree` binary must have `git` and `git-guard` on `PATH`.
- The module adds `ws-worktree` to `packages` and registers it in `core.workspace.toolchainCommandInfos`.
- Enable `core.worktree.enable = true` in the root, `services/portal`, and `apps/workspace-docs` devenv consumers so root tooling, portal Postgres, and docs ports all see the offset.

Postgres wiring:

- Keep `core.services.postgres.port` as the configured **base** port.
- In `packages/nix/core/services/postgres/default.nix`, compute `actualPort = cfg.port + config.core.worktree.portOffset`.
- Use `actualPort` for `services.postgres.port`, `POSTGRES_PORT`, and every `pg-info` line that displays the listen port.
- Keep role creation, passwords, database name, RLS roles, and grants unchanged.

Docs app wiring:

- In `apps/workspace-docs/devenv.nix`, compute `docsPort = 3000 + config.core.worktree.portOffset`.
- `docs-dev` must pass the computed port to Docusaurus start.
- `docs-serve` must pass the computed port to Docusaurus serve for consistency.
- `docs-install` and `docs-build` are unchanged.

### `ws-worktree` command contract

Implement `tools/generators/ws-worktree/` as a small Go `package main`, with unit-testable helpers for argument parsing, branch/slug derivation, worktree porcelain parsing, offset allocation, gitignore checks, and `.worktreeinclude` selection.

Usage:

```text
ws-worktree <branch>
ws-worktree --ref <ref> [--branch <branch>]
ws-worktree --pr <number> [--branch <branch>]
ws-worktree --list
ws-worktree --remove <branch|slug|path> [--force]
ws-worktree --help
```

Fresh branch:

- `ws-worktree feature/<desc>` creates a new local branch from `main`.
- If `origin` exists and `git fetch origin main` succeeds, create from `origin/main`; otherwise create from local `main`.
- Do not switch or mutate the local `main` branch.
- Fail if the target branch already exists; tell the user to use `--ref` for an existing branch.

Existing ref:

- `ws-worktree --ref <local-branch>` checks out an existing local branch into a new worktree.
- `ws-worktree --ref <ref> --branch <branch>` creates a new local target branch at any Git ref, tag, commit, or remote branch.
- If `--ref` does not name a local branch and `--branch` is absent, fail with usage guidance.
- Never pass `--force` to `git worktree add`; Git's one-branch-one-worktree invariant must stand.

Pull request:

- `ws-worktree --pr <number>` fetches `refs/pull/<number>/head` from `origin` and creates a local branch `chore/pr-<number>`.
- `ws-worktree --pr <number> --branch <branch>` uses the supplied compliant target branch instead.
- Do not configure an upstream or push destination automatically.

Branch safety:

- Every target branch is validated by running `git-guard branch-name <branch>`.
- Every target branch is also checked with `git-guard branch-protect <branch>` so `main` and `release/*` cannot be used as agent work branches.
- The command may use `main`, `release/*`, tags, commits, or remote refs as `--ref` bases; only the target branch is restricted.
- The command must not duplicate the branch-name regex from `git-guard`.

Runtime gitignore guard:

- The implementation PR must update `.gitignore` with `.worktrees/` and `.worktree-offset`.
- At runtime, `ws-worktree` checks the main worktree's `.gitignore` before creating a worktree.
- If either pattern is missing, fail before `git worktree add` and print the exact lines to add. Do not silently edit `.gitignore`.

Creation steps:

1. Resolve the repository main worktree path and current invoking worktree path.
2. Validate the command arguments and target branch.
3. Derive the slug and ensure the path is free.
4. Allocate the lowest free positive port slot and compute the marker value.
5. Create the worktree with `git worktree add`.
6. Write `.worktree-offset` in the new worktree root.
7. Copy `.worktreeinclude`-selected files from the invoking worktree into the new worktree.
8. Print the next-step block.

Next-step output must include at least:

```text
Created worktree
  path: <absolute path>
  branch: <branch>
  slug: <slug>
  port offset: <offset>
  portal Postgres: <base + offset if known, otherwise base + offset formula>
  docs dev: <3000 + offset>

Next steps:
  cd <path>
  direnv allow
  codegraph init
  opencode   # or start the agent CLI you want in this directory
```

Listing:

- `ws-worktree --list` lists managed worktrees under `.worktrees/` only.
- Show slug, branch, slot, port offset, and path.
- Mark missing or invalid markers as errors; do not hide corrupted state.

Removal:

- `ws-worktree --remove <branch|slug|path>` resolves a managed worktree and runs `git worktree remove <path>`.
- `--force` passes `--force` to `git worktree remove` after printing that dirty/untracked files may be discarded.
- Removal deletes the worktree directory and therefore its marker; it does not delete local or remote branches.
- After removal, run or suggest `git worktree prune`.

### `.worktreeinclude` copy contract

Add a versioned root `.worktreeinclude` file with:

```text
.env*
deploy/local/.env
```

Copy rules:

- Interpret `.worktreeinclude` with gitignore-style patterns relative to the invoking worktree root.
- Copy only files that match `.worktreeinclude` **and** are ignored by Git according to `git check-ignore` / `git ls-files --ignored --others --exclude-standard`.
- Never copy tracked files.
- Preserve relative paths and create parent directories.
- Do not print file contents.
- If a target file already exists, fail rather than overwrite it.
- File copies should use restrictive permissions suitable for secrets (`0600` for files, `0700` for created directories).
- If `.worktreeinclude` is absent, copy nothing and continue.

### Code index and agent config

- `.codegraph/` remains gitignored and per worktree.
- `ws-worktree` prints `codegraph init`; it does not run it.
- `.opencode/` and `.claude/` remain generated by devenv/direnv per directory. No OpenCode worktree integration is needed; start OpenCode from the worktree directory.

### Git hooks and shared config

- Do not change `core.git` hook rules.
- Do not enable `extensions.worktreeConfig` as part of this feature.
- The root devenv in a linked worktree still satisfies `config.git.root == config.core.workspace.root`, so the existing hook and `commit.template` setup runs there.
- Service/app sub-devenvs keep the current behavior: they do not install root hooks because their workspace root is the subtree, not the Git root.

### Scribe deliverables

The scribe implements the documentation and skill layer against this spec:

- Add `docs/conventions/git/worktrees.md` using the convention template sections: Rule, Rationale, Apply, Examples, Enforcement.
- Link it from `docs/conventions/git/README.md` and reference ADR-0016.
- Extend `tools/ai/skills/git-workflow/SKILL.md` with the worktree-per-agent flow: create, `direnv allow`, `codegraph init`, run agent, remove worktree, keep one branch per worktree, use git-guard-valid branch names.
- Add `.worktrees/` and `.worktree-offset` to `.gitignore`.
- Add the tracked `.worktreeinclude` file shown above.

## Alternatives considered

- See [ADR-0016](../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) for the decision rationale.
- Implementation alternatives rejected there include `builtins.getEnv`, generated `devenv.local.nix`, an `extra/worktree` module, a bash command, monotonic counters, dynamic free-port probing, shared `.codegraph/`, and enabling `extensions.worktreeConfig` now.

## Open questions

- None. Implementation watch items are verification risks, not design questions: invalid markers must fail loudly, slug collisions must fail, and hook behavior must be smoke-tested from a linked worktree.

## Implementation plan

- [ ] **Backend-engineer:** Add `tools/generators/ws-worktree/` with the command contract above and unit tests for args, branch/slug derivation, porcelain parsing, offset allocation/reuse, gitignore guard, and `.worktreeinclude` filtering.
- [ ] **Backend-engineer:** Add `packages/nix/core/worktree/default.nix`, import it from `packages/nix/core/default.nix`, package/wrap `ws-worktree`, and register it in `core.workspace.toolchainCommandInfos`.
- [ ] **Backend-engineer:** Wire `core.worktree.portOffset` into `core.services.postgres` actual port, `POSTGRES_PORT`, and `pg-info` without changing roles or RLS setup.
- [ ] **Backend-engineer:** Wire `apps/workspace-docs` `docs-dev` and `docs-serve` to `3000 + core.worktree.portOffset`.
- [ ] **Backend-engineer:** Enable `core.worktree.enable = true` in root, portal, and workspace-docs devenv consumers.
- [ ] **Scribe:** Add the Git worktrees convention doc, README link, git-workflow skill update, `.gitignore` lines, and tracked `.worktreeinclude`.
- [ ] **Release-engineer:** Smoke-test two managed worktrees running portal Postgres and docs dev concurrently, and prove `git-guard branch-name` / hooks run inside a linked worktree.
- [ ] **Security-reviewer:** Confirm copied env files remain gitignored/local and the Postgres/RLS role contract is unchanged.

## References

- [ADR-0016](../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md)
- [Git worktree documentation](https://git-scm.com/docs/git-worktree)
- [Git hooks documentation](https://git-scm.com/docs/githooks)
- [Git config documentation](https://git-scm.com/docs/git-config)
- [Claude Code worktrees documentation](https://code.claude.com/docs/en/worktrees.md)
- [OpenCode CLI documentation](https://opencode.ai/docs/cli)
- [`packages/nix/core/workspace/default.nix`](../../packages/nix/core/workspace/default.nix)
- [`packages/nix/core/services/postgres/default.nix`](../../packages/nix/core/services/postgres/default.nix)
- [`services/portal/devenv.nix`](../../services/portal/devenv.nix)
- [`apps/workspace-docs/devenv.nix`](../../apps/workspace-docs/devenv.nix)
- [`tools/validators/git-guard/branch.go`](../../tools/validators/git-guard/branch.go)
