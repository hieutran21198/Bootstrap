# Agent edit-permission map correctness relies on incidental key-sort/last-match coincidence

> **Status**: Open
> **Priority**: Low
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-06
> **Last reviewed**: 2026-07-06

## What

Agent `permission.edit` map correctness depends on `builtins.toJSON` rendering Nix attrset keys in alphabetical order and opencode resolving overlapping globs by last-match-wins over that emitted order; a future override glob that happens to sort *before* the broader base pattern it is meant to override would silently flip the intended allow/deny outcome with no eval-time error.

## Why it exists

ADR-0023 renders each agent's `permission.edit` as a Nix attrset of path-glob-to-action pairs. The renderer (`packages/nix/core/ai/default.nix`) serializes that attrset with `builtins.toJSON`, which sorts object keys alphabetically; opencode then resolves overlapping globs against a path via last-match-wins over the order the JSON was written in. The scheme was never designed as an *ordered*-rule abstraction — it works today only because alphabetical order happens to coincide with the intended precedence. The only current override, Scribe's `docs/wiki/architecture/*: deny` layered after the broader `docs/wiki/*: allow` (see `.opencode/agents/scribe.md:4` and ADR-0023 §"Built-in tool posture matrix"), sorts correctly by accident: `docs/wiki/architecture/*` alphabetically follows `docs/wiki/*`, so it lands later in the emitted JSON and wins as intended. Similarly, every agent's broad `"*": deny` base rule sorts before all of today's more specific allow rules (`*` sorts before any non-`*`-prefixed path segment), so it never accidentally shadows an intended allow. Neither property was asserted or tested — both are consequences of the current, small rule set and today's chosen path strings.

## Impact

- **Correctness**: Latent, no current breakage — the one existing override (Scribe's wiki/architecture deny) and every base `"*"` deny both currently sort into the correct precedence position. There is no verification (test or renderer check) that this holds, so it is unverified-safe rather than guaranteed-safe.
- **Security**: A future maintainer adding a more-specific override (e.g. a new deny meant to carve an exception out of a broader allow, or vice versa) could pick a path string that sorts alphabetically *before* the pattern it's meant to override. The renderer would emit valid JSON, `opencode` would apply it without complaint, and the agent would silently gain or lose write access to a resource contrary to the ADR-0023 posture matrix — with no error, warning, or failing check to catch it.
- **Maintainability**: The ordering contract is implicit and undocumented at the point of use; a contributor editing `core.ai.agents.<name>.posture` in `packages/nix/core/ai/default.nix` has no local signal that key order is load-bearing for override semantics.

## Resolution

Not yet decided — the Architect owns the fix decision for a renderer-owned concern. Candidate options surfaced during ADR-0023 implementation review:

- Add a renderer-level check or test that validates intended override precedence explicitly (e.g. assert that every "narrower" glob pattern for a given agent sorts after the "broader" pattern it is meant to override, or diff the posture matrix's documented intent against the emitted key order).
- Replace the implicit alphabetical-sort-as-precedence scheme with an ordered-rule abstraction — e.g. render `permission.edit` as an explicit ordered list (if/when opencode supports it) or a Nix structure that carries explicit precedence rather than relying on attrset key order plus JSON serialization behavior.

Route the actual choice through the Architect; this entry only records the shape of the risk.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter  | Symptom                                                                                                                                                                                                                    | Evidence                                                     |
| ---------- | -------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 2026-07-06 | Low      | architect | Surfaced during ADR-0023 implementation review as a latent debt candidate: map-valued permission correctness relies on `builtins.toJSON` alphabetical key order coinciding with opencode last-match-wins resolution, with no check enforcing that future overrides sort correctly. | ADR-0023 implementation review verdict; `.opencode/agents/scribe.md:4` |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- [ADR-0023: Hard-scope agent edit permissions by owned resource](../adrs/0023-hard-scope-agent-edit-permissions.md)
- `packages/nix/core/ai/default.nix` — renderer that serializes agent `posture` attrsets to JSON via `builtins.toJSON`.
- `.opencode/agents/scribe.md` — generated example carrying today's one (accidentally correct) override.
