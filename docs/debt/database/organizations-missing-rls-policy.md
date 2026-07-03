# The `organizations` tenant-root table ships with no Row-Level Security policy

> **Status**: Open
> **Priority**: High
> **Hits**: 1
> **Owner**: portal
> **Created**: 2026-07-03
> **Last reviewed**: 2026-07-03

## What

The `organizations` table has no Row-Level Security policy migration, despite [ADR-0011](../../adrs/0011-org-root-rls-hardening.md) deciding org-root self-keyed RLS.

## Why it exists

[ADR-0011](../../adrs/0011-org-root-rls-hardening.md) decided org-root RLS hardening — a `FORCE`d policy keyed on the row's own `id` (`id = current_setting('app.organization_id', true)`) plus a self-binding registration insert — explicitly to remove the tenant-root RLS exception. The corresponding `staff` RLS migration shipped (`services/portal/internal/infra/postgres/migrations/20260629000001_staff_rls.sql`), but a matching `organizations` RLS migration was never written. Confirmed: `organizations` is created in `services/portal/internal/infra/postgres/migrations/20260626000001_init.sql` (lines 3-12) with no `ENABLE`/`FORCE ROW LEVEL SECURITY` and no policy; `20260629000001_staff_rls.sql` is the only RLS migration in the tree. The decision landed in the ADR but never landed as SQL — the org-root table stayed on the "no policy" status quo ADR-0011 rejected.

## Impact

- **Security**: The tenant-root table is unprotected at the DB layer, so `FORCE ROW LEVEL SECURITY` / tenant isolation does not cover `organizations` rows. The `NOBYPASSRLS` `writer` role can read or mutate any organization's root row regardless of the bound `app.organization_id` — the exact cross-tenant leak class ADR-0008/0011 exist to eliminate, reopened on the one table that names the tenant. A single wrong id or missing predicate in a tenant-facing handler could rename, deactivate, or re-own another tenant's organization.
- **Correctness**: Reality contradicts the accepted decision — ADR-0011 is `Accepted` and reclassifies `organizations` as "tenant root (self-keyed RLS)", but the schema still behaves as "tenant root (no RLS)". Reviewers reasoning from the ADR will assume protection that does not exist.

Mitigating context: greenfield — the migrations are effectively pre-first-apply and there is no production data yet, so this is a latent hole rather than a live breach.

## Resolution

Add a goose migration that `ENABLE`s and `FORCE`s Row-Level Security on `organizations` with the [ADR-0011](../../adrs/0011-org-root-rls-hardening.md) self-keyed policy:

```sql
USING      (id = current_setting('app.organization_id', true))
WITH CHECK (id = current_setting('app.organization_id', true))
```

for the `organization` scope (`TO writer, reader`), which both admits the self-binding registration insert and constrains every other access to the bound org, plus the `system` read branch mirroring `system_read_staff` (`TO system_reader`, `app.scope = 'system'` + `app.organization_allowlist`). Add isolation tests covering the org-root table (fail-closed when unbound; no cross-tenant read/write on the `organization` scope). Author the policy against the now-corrected pattern in `tools/ai/skills/rls-patterns/SKILL.md`.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../../findings/`](../../findings/); link from *Evidence*.

| Date       | Severity | Reporter  | Symptom                                                                                                                                                                              | Evidence                                             |
| ---------- | -------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 2026-07-03 | High     | architect | Found during Security Reviewer agent rollout (ADR-0014) while aligning the rls-patterns skill to ADR-0009/0011; independent Architect review flagged the missing organizations RLS migration. | [ADR-0014](../../adrs/0014-security-reviewer-agent.md) |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](../README.md) was crossed.

## References

- [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md) — RLS as the authority for tenant isolation; the leak class this debt reopens on the tenant root.
- [ADR-0011](../../adrs/0011-org-root-rls-hardening.md) — the decision to put a self-keyed `FORCE`d policy on `organizations`; the resolution this debt tracks.
- [Database role and scope contract](../../conventions/database/role-and-scope-contract.md) — `admin`/`writer`/`reader`/`system_reader` roles + `app.scope` / `app.organization_id` GUCs the policy must read.
- `services/portal/internal/infra/postgres/migrations/20260626000001_init.sql` (lines 3-12) — creates `organizations` with no RLS.
- `services/portal/internal/infra/postgres/migrations/20260629000001_staff_rls.sql` — the shipped `staff` RLS migration whose org-root counterpart is missing.
- [ADR-0014](../../adrs/0014-security-reviewer-agent.md) — the Security Reviewer rollout during which this gap surfaced.
- `tools/ai/skills/rls-patterns/SKILL.md` — the policy-authoring pattern to mirror when resolving.
