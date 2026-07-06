# Parallel-Agent Worktrees

> **Scope**: every parallel AI-agent session and any Git worktree created against this repository — the `.worktrees/` tree, its `.worktree-offset` markers, and the `ws-worktree` tool.
> **Status**: Active
> **Decided by**: [ADR-0016](../../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md)
> **Last reviewed**: 2026-07-04

**Rule.** Run each parallel agent session in its own Git worktree under the main checkout's `.worktrees/<slug>` directory, created with `ws-worktree <branch>` on a git-guard-valid non-protected work branch (one branch → one worktree), bootstrapped with `direnv allow` + `codegraph init`, and torn down with `ws-worktree --remove` / `git worktree remove` + `git worktree prune` — never `rm -rf`.

**Rationale.** AI agents that share one checkout collide on files, on the current branch, and on stateful local ports (portal Postgres, the docs server). Git worktrees give each session its own working tree and branch for free; the only pieces this workspace has to standardise are *where* worktrees live, *how* their branches are named, and *how* their service ports are offset — so every session is created the same way and two agents can run concurrently without hand-editing Nix. Confining worktrees to `.worktrees/<slug>` keeps them inside one gitignored subtree; deriving the slug from the branch keeps paths predictable; a per-worktree `.worktree-offset` marker lets Nix offset ports deterministically instead of probing for free ones. Reusing `git-guard` for branch validation means the worktree flow adds no second branch-naming convention.

**Apply.**

- **Layout & identity.** Managed worktrees live under the *main* checkout's `.worktrees/<slug>`. The slug is the target branch with `/` replaced by `-` (`feature/tenant-invite` → `feature-tenant-invite`). Slug collisions fail loudly — `ws-worktree` never auto-suffixes — so keep branch names distinct.
- **Always create with `ws-worktree`, never raw `git worktree add`.** `ws-worktree feature/<desc>` branches fresh work off `main` (from `origin/main` when a fetch succeeds, otherwise local `main`); `ws-worktree --ref <ref> [--branch <branch>]` bases a worktree on an existing branch, tag, or commit; `ws-worktree --pr <number> [--branch <branch>]` checks out a PR head. The tool also writes the port-offset marker, guards `.gitignore`, and copies your gitignored env files — a hand-run `git worktree add` skips all three.
- **Branches are git-guard-valid and non-protected.** Every target branch is validated by `git-guard branch-name` and `git-guard branch-protect`, so `main` and `release/*` can never be an agent work branch (they may still be used as an `--ref` base). One branch maps to exactly one worktree — Git enforces this invariant and `ws-worktree` never passes `--force` to defeat it.
- **Bootstrap each worktree explicitly.** `ws-worktree` prints the next steps but runs none of them: `cd` into the new worktree, `direnv allow` to regenerate its directory-local `.opencode/`, `.claude/`, `.editorconfig`, and env, then `codegraph init` to build that worktree's own `.codegraph/` index (never shared or symlinked from the main checkout). Start the agent CLI from inside the worktree directory.
- **Concurrent services via the port offset.** Each managed worktree carries a root-level `.worktree-offset` marker holding one base-10 integer — the actual port offset. The main checkout reserves offset `0` and normally has no marker; linked worktrees add `10` per slot (first `+10`, second `+20`, stride `10`). Nix reads the marker so portal Postgres runs on `base + offset` and the docs server on `3000 + offset`, letting two sessions run at once. Do not hand-edit or delete the marker — invalid content fails loudly.
- **Bootstrap secrets through `.worktreeinclude` only.** The versioned root `.worktreeinclude` (currently `.env*` and `deploy/local/.env`) names the gitignored local files a fresh worktree should receive. `ws-worktree` copies only files that both match a pattern **and** are gitignored; tracked files are never copied and an existing target is never overwritten. Patterns are simple globs (shell `filepath.Match` semantics) plus exact paths — not full gitignore-style syntax, so no `**`, negation, or directory-recursive rules; `.env*` and `deploy/local/.env` are simple globs and work as-is. Add new local-secret patterns there rather than copying files by hand.
- **Clean up, never `rm -rf`.** End a session with `ws-worktree --remove <branch|slug|path>` (or `git worktree remove <path>`), then `git worktree prune`. `rm -rf` orphans the worktree in Git's metadata. Removal frees the port slot for reuse; it never deletes the local or remote branch.

**Examples.**

✓ Good:

```bash
# One agent session = one worktree on its own git-guard-valid branch off main.
ws-worktree feature/tenant-invite         # creates .worktrees/feature-tenant-invite
cd .worktrees/feature-tenant-invite
direnv allow                              # regenerate directory-local env + agent config
codegraph init                            # build this worktree's own code index
opencode                                  # start the agent in this directory

# Concurrent services just work: this worktree's Postgres/docs ports are offset +10.
# When the session ends, remove the worktree (not rm -rf) and recycle its slot.
ws-worktree --remove feature/tenant-invite
git worktree prune
```

✗ Bad:

```bash
git worktree add ../scratch main                     # protected branch, outside .worktrees/, no offset marker
git worktree add .worktrees/dup feature/a --force    # forces a second worktree onto one branch
rm -rf .worktrees/feature-tenant-invite              # orphans the worktree in git's metadata
```

**Enforcement.** Tool-assisted, with a manual remainder:

- **`ws-worktree`** shells to `git-guard branch-name` / `git-guard branch-protect` for every target branch, so off-pattern or protected branches fail at creation; it refuses to run unless `.gitignore` contains `.worktrees/` and `.worktree-offset`, and fails loudly on a missing, non-integer, or non-stride-aligned `.worktree-offset` marker.
- **`git worktree add`** (invoked without `--force`) enforces the one-branch-one-worktree invariant.
- **Nix** (`core.worktree`, [`packages/nix/core/worktree/default.nix`](../../../packages/nix/core/worktree/default.nix)) fails evaluation on an invalid marker, so a corrupted offset cannot silently mis-port a service.
- **Manual / code-review-enforced**: using `ws-worktree` rather than raw `git worktree add`, running `direnv allow` + `codegraph init` per worktree, and cleaning up with `--remove` + `prune` instead of `rm -rf`.

## See also

- [Git conventions index](README.md)
- [Branch & release workflow](workflow.md) — the branch naming and protection rules a worktree branch must satisfy.
- [ADR-0016](../../adrs/0016-use-git-worktrees-for-parallel-ai-agent-sessions.md) — the decision that established this rule.
- [Parallel agent worktrees spec](../../specs/parallel-agent-worktrees.md) — the implementation contract for `ws-worktree`, the `core.worktree` Nix module, and `.worktreeinclude`.
- [Git worktree documentation](https://git-scm.com/docs/git-worktree) — linked worktrees, the one-branch-one-worktree invariant, and removal/prune.
