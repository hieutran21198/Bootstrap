
# Agent roster docs drift from the generated Nix source of truth

> **Status**: Open
> **Priority**: Low
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-05
> **Last reviewed**: 2026-07-05

## What

The hand-maintained agent roster in root `README.md` and `docs/wiki/agent-team.md` drifted out of sync with the generated agent modules in `packages/nix/core/ai/agents/` — both docs said "seven subagents" and omitted `security-reviewer` and `dev-environment` until caught and fixed during a README rewrite on 2026-07-05.

## Why it exists

ADR-0014 added the `security-reviewer` agent and ADR-0019 added the `dev-environment` agent to the Nix module tree (`packages/nix/core/ai/agents/`), but the informal `docs/wiki/agent-team.md` note — whose own header states "Keep this table in sync with them" — and the root `README.md` mirror of it were not updated in lockstep. There is no automated check enforcing the sync between the generated module tree and these two prose documents, only a manual convention.

## Impact

- **Correctness**: —
- **Performance**: —
- **Maintainability**: signals that documentation mirroring a generated source of truth can silently go stale with no failure signal.
- **Developer experience**: anyone reading the README or wiki gets a stale, undercounted agent roster (missing two of nine subagents), and risks orienting new contributors or agents around an incomplete team.
- **Security**: —

## Resolution

Not yet planned. Two options on the table, neither committed:

1. A generator/validator that renders the roster table(s) directly from `core.ai.agents` + the capability allow-lists (`agents` allow-lists in `packages/nix/core/ai/mcps/` and `.../skills/`) so the docs can't drift — `docs/wiki/agent-team.md`'s own Notes section already flags this as a future `tools/generators/` renderer.
2. A lighter-weight CI/pre-commit check that fails when the agent count in `packages/nix/core/ai/agents/default.nix` imports doesn't match the count asserted in `docs/wiki/agent-team.md` / `README.md`.

`Status: Open`, `Priority: Low` — caught and hand-fixed same-day, no repeated pain yet.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter  | Symptom                                                                                                                                     | Evidence |
| ---------- | -------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 2026-07-05 | Low      | architect | Caught during a README template-positioning rewrite: both `README.md` and `docs/wiki/agent-team.md` said "seven subagents" and were missing `security-reviewer` / `dev-environment`; hand-fixed in the same pass. | —        |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- [ADR-0014](../adrs/0014-security-reviewer-agent.md) — added the `security-reviewer` agent to the Nix module tree.
- [ADR-0019](../adrs/0019-dev-environment-agent.md) — added the `dev-environment` agent to the Nix module tree.
- [`docs/wiki/agent-team.md`](../wiki/agent-team.md) — the informal roster note that drifted; its own Notes section already flags the missing automated renderer.
- [`packages/nix/core/ai/agents/`](../../packages/nix/core/ai/agents/) — the generated source of truth the docs must mirror.
