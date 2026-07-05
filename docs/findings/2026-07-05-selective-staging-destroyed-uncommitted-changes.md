# `git checkout --` during selective staging destroyed unrelated uncommitted hunks

> **Status**: Resolved
> **Authors**: release-engineer (agent session, PR #22)
> **Investigated**: 2026-07-05
> **Tracks**: PR #22 (`feature/handoff-audit-log`)

## Symptom

After committing a clean single-hunk change to `devenv.nix` on
`feature/handoff-audit-log`, the user's ~9 uncommitted agent-model-tuning hunks
in that same file vanished from the working tree.

## Reproduction

```text
# devenv.nix carried two unrelated, uncommitted change sets in one file:
#  - a plugin-enable hunk (the only one the brief asked to commit)
#  - ~9 agent-model-tuning hunks (the brief required these stay uncommitted)

git diff devenv.nix          # both change sets appear mixed together in one diff
git checkout -- devenv.nix   # intended: reset before re-inserting only the target hunk
                              # actual: discards ALL unstaged edits to the file, not
                              #         just the hunk being reset for re-insertion
# re-insert only the plugin-enable hunk, git add devenv.nix, git commit
# -> the 9 agent-model-tuning hunks are now gone from the working tree
```

## Hypotheses considered

- **H1: `git checkout -- <file>` only reverts the hunk currently being
  reworked, leaving other unstaged edits to the same file intact.** Disproved
  — `git checkout -- <file>` restores the entire file to its `HEAD`/index
  content; it has no concept of "hunk" and cannot selectively discard part of
  a file's unstaged state. Confirmed as the mechanism of loss (see Root
  cause).
- **H2: the destroyed hunks are recoverable from `git stash`.** Disproved —
  `git stash list` showed only `stash@{0}`, and diffing its content against
  the missing hunks showed it held older, unrelated changes. The stash that
  might have held the agent-model-tuning hunks had already been consumed by
  an earlier `git stash pop` in the same agent session, before the checkout
  ran.

## Investigation

- Reconstructed the agent session's action sequence: `git checkout --
  devenv.nix` was run to reset the file before re-inserting the desired
  hunk, on the (incorrect) assumption that checkout only affects the hunk in
  flight.
- Ran `git stash list` and diffed `stash@{0}` against the missing content —
  confirmed it was older and unrelated, ruling out stash-based recovery.
- Located the full pre-checkout diff for `devenv.nix` in the same agent
  session's own transcript (captured earlier via an unrelated `git diff`
  call) and used it as the reconstruction source.

## Root cause

`git checkout -- <file>` restores the file to its `HEAD` (or index) content
and discards **every** unstaged edit to that file — not only the hunk the
operator intends to reset. Because `devenv.nix` mixed two unrelated,
uncommitted change sets, the reset used to "start clean" before re-inserting
the commit-intended hunk destroyed the other, unrelated hunks along with it.
There was no other copy of the destroyed hunks: an earlier `git stash pop` in
the same session had already consumed the one stash that might have held
them.

## Resolution

- All 9 destroyed hunks were reconstructed from the `git diff` output
  captured earlier in the same agent session's transcript and re-applied to
  the working tree. A Nix eval of `devenv.nix` confirmed structural
  integrity after reconstruction. The pre-existing `stash@{0}` (older,
  unrelated content) was left untouched.
- **Preventive pattern** for "stage only hunk X, keep hunk(s) Y uncommitted"
  on a single file:
  1. `cp <file> /tmp/<file>-full` — snapshot the full working-tree state
     before any reset.
  2. `git checkout -- <file>` — reset to `HEAD`.
  3. Apply only the commit-intended hunk (X) to the now-clean file.
  4. `git add <file>` — stage exactly hunk X.
  5. `cp /tmp/<file>-full <file>` — restore the full working tree; the index
     still holds only X because step 4 already ran.
  6. Verify with both `git diff --cached <file>` (index shows only X) and
     `git diff <file>` (working tree still shows Y).
  Where interactive staging is available, prefer `git add -p` outright — it
  stages hunk X directly without ever resetting the working tree, removing
  the failure mode entirely.
- No convention or tooling currently enforces this pattern; it is recorded
  here so the next agent performing selective staging on a mixed file does
  not rediscover it by destroying uncommitted work. Candidate for promotion
  into [`docs/conventions/git/`](../conventions/git/) if the pattern recurs.

## References

- PR #22 (`feature/handoff-audit-log`) — the session in which this was
  discovered and recovered.
- [`docs/conventions/git/workflow.md`](../conventions/git/workflow.md) —
  branch/commit workflow; has no current guidance on selective staging
  within a single file — candidate location for a future convention.
- [`docs/conventions/agents/artifact-mediated-communication.md`](../conventions/agents/artifact-mediated-communication.md)
  — Completion Report protocol under which this was reported.
