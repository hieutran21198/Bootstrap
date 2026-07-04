# No automated drift check between OpenAPI contracts and generated code

> **Status**: Open
> **Priority**: Medium
> **Hits**: 0
> **Owner**: unassigned
> **Created**: 2026-07-04
> **Last reviewed**: 2026-07-04

## What

There is no automated check that `oapi-codegen` output stays in sync with the hand-authored OpenAPI contracts under `services/*/api/*.yaml`.

## Why it exists

[ADR-0018](../adrs/0018-contract-first-rest-api.md) adopted contract-first REST, and the [convention](../conventions/api/contract-first-openapi.md) restates the deterministic-regeneration rule, but both explicitly defer devenv/CI codegen wiring as a follow-up. Enforcement is currently manual PR review.

## Impact

- **Correctness**: generated HTTP delivery code can drift from the contract without failing CI; correctness depends on reviewer diligence.
- **Maintainability**: as more endpoints are generated, the chance that a contract change silently leaves stale generated output behind grows.

## Resolution

Add deterministic devenv/CI wiring that regenerates codegen output per contract and fails the build on any diff. ADR-0018 already records this as a follow-up.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date | Severity | Reporter | Symptom | Evidence |
| ---- | -------- | -------- | ------- | -------- |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- [ADR-0018](../adrs/0018-contract-first-rest-api.md) — adopted contract-first REST; lists codegen CI wiring as a follow-up.
- [Contract-first OpenAPI convention](../conventions/api/contract-first-openapi.md) — workspace rule; defers the same wiring.
- PR #12, PR #13 — introduced the ADR and convention.
