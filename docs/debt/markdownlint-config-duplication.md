# Markdownlint ruleset is duplicated between the Nix module and the CI workflow

> **Status**: Open
> **Priority**: Medium
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-06
> **Last reviewed**: 2026-07-06

## What

The markdownlint ruleset and ignore globs are maintained in two places — the Nix module `packages/nix/core/toolchains/markdown/default.nix` (source for the local pre-commit hook via the generated, gitignored `.markdownlint-cli2.jsonc`) and an inlined copy in the CI workflow `.github/workflows/pr-validate.yml` — so the two can silently drift.

## Why it exists

GitHub Actions runners have no Nix store, and the generated `.markdownlint-cli2.jsonc` is a gitignored Nix-store symlink that CI cannot read. PR #31 inlined the ruleset and ignore globs directly into the `.github/workflows/pr-validate.yml` markdownlint job to keep the CI job self-contained.

## Impact

- **Maintainability**: a ruleset or exclusion change made in the Nix module does not reach CI (or vice versa) unless both copies are updated by hand, so a PR can pass the local pre-commit hook and still fail CI, or the reverse. Frequency is low — the ruleset rarely changes — but each divergence is confusing when it happens.
- **Developer experience**: contributors debugging a markdownlint failure have to check two sources of truth instead of one. The sibling `git-conventions` CI job already avoids this exact class of drift by building `git-guard` from source rather than inlining its rules.

## Resolution

Single-source the config: run the CI markdownlint step inside the devenv/Nix environment so it consumes the generated `.markdownlint-cli2.jsonc` directly, or add a CI step that renders the config from the Nix source before linting, then delete the inlined heredoc from the workflow. Until then, treat it as a manual rule: any change to the markdown ruleset or ignore globs must update **both** `packages/nix/core/toolchains/markdown/default.nix` and `.github/workflows/pr-validate.yml`.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter | Symptom                                                                                                                                              | Evidence |
| ---------- | -------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 2026-07-06 | Medium   | scribe   | Debt introduced and discovered in the same change while fixing PR #31's markdownlint CI gate — the ruleset had to be inlined into the workflow because CI cannot read the Nix-generated config file. | PR #31   |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- PR #31 (<https://github.com/hieutran21198/Bootstrap/pull/31>) — introduced the CI markdownlint gate and the inlined duplicate ruleset.
- `packages/nix/core/toolchains/markdown/default.nix` — source of truth for the local pre-commit markdownlint config.
- `.github/workflows/pr-validate.yml` — the CI job carrying the inlined duplicate.
