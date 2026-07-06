# Schema-wide `writer`/`reader` grants make every new non-RLS table fail-open by default

> **Status**: Open
> **Priority**: Medium
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-06
> **Last reviewed**: 2026-07-06

## What

`core.services.postgres` provisions `writer` with schema-wide `SELECT, INSERT, UPDATE, DELETE` and `reader` with schema-wide `SELECT` ([role-and-scope-contract.md](../../conventions/database/role-and-scope-contract.md)), so any new table created in the default schema is writable/readable by both tenant-facing roles the moment it exists — fail-**open** — unless whoever adds the table remembers to `ENABLE`/`FORCE` RLS and add a policy before the migration ships.

## Why it exists

[ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md) made schema-wide grants + `NOBYPASSRLS` roles the tenant-isolation contract: RLS is the authority, so a schema-wide grant is safe *as long as every table in the schema carries a `FORCE`d policy*. That held while every table in the schema was tenant-scoped organization data reachable only through `DoOrganizationTransaction`/`DoOrganizationQuery`. The contract has no rule for a table that is *not* tenant data — nothing in [role-and-scope-contract.md](../../conventions/database/role-and-scope-contract.md) or the [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) says a new table must add an explicit `REVOKE` before the tenant roles' schema-wide grant reaches it. The gap was latent until a non-tenant use case (backoffice platform staff) needed a table in reach of the same database that tenant `writer`/`reader` connect to.

## Impact

- **Security**: A new table added to a schema the tenant `writer`/`reader` roles have schema-wide grants on is writable/readable by both roles from the moment its migration runs, with no RLS policy required to make that legal — "secure by default" is inverted. "No RLS because it's not tenant data" looks locally reasonable and is silently wrong.
- **Maintainability**: Every new non-tenant table needs someone to remember an explicit `REVOKE` + default-privilege exclusion (or a schema-level `REVOKE ... ON SCHEMA ... FROM writer, reader`) that is not enforced by any structural rule, lint, or CI check — it depends on the author's and reviewer's memory of this specific failure shape.
- **Developer experience**: The failure is invisible until someone goes looking; there is no test, migration lint, or isolation-test gate today that fails a new table for missing the `REVOKE`.

## Resolution

Not yet started. The backoffice staff-management spec discharges the *instance* of this debt for its own tables — dedicated `backoffice_authn`/`backoffice_writer`/`backoffice_reader` roles, explicit `REVOKE`+default-privilege exclusion on the `backoffice` schema, and `ENABLE`+`FORCE` RLS with policies scoped to the backoffice roles only (see [backoffice-staff-management-surface-and-flows.md § Database privilege, RLS, and role/GUC contract](../../specs/backoffice-staff-management-surface-and-flows.md#database-privilege-rls-and-rolegunc-contract) and its "Alternatives considered" rejection of "no RLS because it's not tenant data") — but that is a per-feature fix, not a workspace rule.

**Recommended follow-up (not applied by this entry):** state the general rule explicitly in [`docs/conventions/database/role-and-scope-contract.md`](../../conventions/database/role-and-scope-contract.md) and the [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) — every new table outside the existing tenant-scoped set must either (a) ship with `FORCE`d RLS admitting only the intended role(s), or (b) be explicitly carved out of the schema-wide tenant grants (dedicated schema + `REVOKE` + default-privilege exclusion) before or in the same migration that creates it. Flagging this as a follow-up only: a convention change of this shape may warrant its own ADR, and is out of scope for this debt entry to apply.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../../findings/`](../../findings/); link from *Evidence*.

| Date       | Severity | Reporter          | Symptom                                                                                                                                                                                                      | Evidence                                                                                                                                                    |
| ---------- | -------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-07-06 | Medium   | Security-Reviewer | During the backoffice-staff-management design review, flagged that a plain new `backoffice.staff` table would be writable by tenant-facing `writer`/`reader` by default under the existing schema-wide grant contract, purely because it lives in reach of the same roles — forcing the spec to add dedicated roles + explicit `REVOKE`s instead of relying on the existing contract. | [adr-acceptance-and-spec-conditions.md](../../../.sdlc/backoffice-staff-management/coordination/adr-acceptance-and-spec-conditions.md) (condition 1); [backoffice-staff-management-surface-and-flows.md](../../specs/backoffice-staff-management-surface-and-flows.md) |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](../README.md) was crossed.

## References

- [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md) — the schema-wide-grant + `NOBYPASSRLS` contract this debt exposes a gap in.
- [Database role and scope contract](../../conventions/database/role-and-scope-contract.md) — the current rule; recommended (not yet applied) home for the general fail-closed-by-default statement.
- [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) — recommended (not yet applied) home for the how-to.
- [Backoffice staff-management surface and flows spec](../../specs/backoffice-staff-management-surface-and-flows.md) — the per-feature discharge of this debt (dedicated roles, explicit `REVOKE`, forced RLS) and its "Alternatives considered" rejection of "no RLS because it's not tenant data".
- [`.sdlc/backoffice-staff-management/coordination/adr-acceptance-and-spec-conditions.md`](../../../.sdlc/backoffice-staff-management/coordination/adr-acceptance-and-spec-conditions.md) — condition 1 (DB privilege fail-open risk) and the durable-learning routing note that originated this entry.
