# 0024. Model backoffice staff as a platform aggregate

- **Status**: Accepted
- **Date**: 2026-07-06
- **Deciders**: product owner (human)
- **Supersedes**: -
- **Superseded by**: -

## Context

The accepted backoffice staff management PRD defines **backoffice staff** as the platform's internal operators and support staff, explicitly distinct from any tenant organization's own staff. Those accounts are platform-level: they are not owned by a tenant organization, they have exactly one role from `admin` / `member`, and they must support roster-management rules such as last-active-admin protection.

The existing `staff.Staff` aggregate is a different concept. It represents an employed person **inside an Organization**, carries a required `organizationID`, accepts the tenant role set `owner` / `admin` / `member`, and rejects an empty organization at construction. The write path reinforces that model: `DoOrganizationTransaction` validates an `organization.ID` and binds `app.organization_id` transaction-locally before any writer runs, so every `staff` write is tenant-scoped by RLS.

That creates the core tension for this ADR: reusing `staff.Staff` for backoffice accounts would require either inventing an owning organization or weakening the tenant RLS model for a platform-level account that has no owning organization. ADR-0008/ADR-0011 make organization scope the normal write boundary for tenant data, and ADR-0009 deliberately keeps `system` scope read-only first with no generic `DoSystemTransaction` for cross-tenant writes.

## Decision

We will model backoffice staff as a distinct platform-level aggregate, not as `staff.Staff` with a sentinel or nullable organization. The aggregate lives outside tenant-scoped `staff` tables and `DoOrganizationTransaction`; downstream specs must give it a dedicated platform/backoffice persistence and authorization boundary without introducing a generic cross-tenant `DoSystemTransaction` over tenant-owned data.

## Consequences

- **Positive**:
  - The domain model matches the PRD boundary: tenant staff remain organization-owned people, while backoffice staff are platform operators with only `admin` / `member` roles.
  - Tenant RLS invariants stay intact. No fake organization, null `organization_id`, or widened tenant policy is needed to persist platform-level accounts.
  - Backoffice authorization can be designed around the backoffice role set and last-admin safeguard instead of overloading `staff.RoleOwner` or tenant membership semantics.
  - The new aggregate can still follow the existing service architecture conventions: private fields, typed aggregate ID, value-object validation, CQRS ports, and collection-style repositories.
- **Negative**:
  - This adds a new domain/persistence surface instead of reusing the existing `staff` package and repositories.
  - Common concepts such as email, personal names, active/deactivated state, and role parsing may need duplication or carefully factored validation without collapsing the two domain concepts.
  - A dedicated platform/backoffice write boundary must be specified and reviewed. It cannot piggyback on tenant `DoOrganizationTransaction`, and it must not become the generic system-write primitive ADR-0009 intentionally deferred.
- **Neutral**:
  - `staff.Staff` remains the tenant-scoped aggregate for organization staff, with its existing `organizationID` and `owner` role semantics unchanged.
  - If a future backoffice flow reads tenant-owned data, it still uses the ADR-0009 `system_reader`/capability model for cross-tenant reads. This ADR only decides the platform account model.
  - The backoffice aggregate will likely reference the identity provider's subject/user id, but credential lifecycle ownership is decided separately in ADR-0025.
  - **Acceptance note (2026-07-06):** the product owner accepted this ADR with two clarifications carried into downstream specs: the backoffice write boundary runs as a separate runtime/deployment and its privileged DSN must stay out of the tenant-facing portal binary; and this ADR licenses a scoped backoffice role/GUC-contract extension without a separate ADR, provided the spec defines the concrete roles, GUCs, policy shape, and follow-up update to the database role-and-scope convention. Security-review conditions are mandatory spec obligations.

## Alternatives considered

- **Reuse `staff.Staff` with a sentinel/platform organization** — rejected because it creates a tenant row that is not really a tenant, requires every backoffice account write to bind a fake `app.organization_id`, and pollutes tenant semantics with platform authorization. It also leaves the incompatible `owner` role in the role set and does not help when backoffice flows need true cross-tenant reads.
- **Reuse `staff.Staff` with a nullable organization** — rejected because it breaks the aggregate's explicit non-empty-organization invariant and pushes the exception into RLS policy design. A `NULL` organization either fails closed under the existing policy or requires a special policy branch that weakens the tenant isolation contract ADR-0008/ADR-0011 exist to protect.
- **Reuse `staff.Staff` through a system-scope write path** — rejected because ADR-0009 intentionally forbids generic system writes until a separate accepted ADR justifies them. Creating platform accounts should not require a cross-tenant write primitive over tenant-owned tables.
- **Create a distinct platform-level backoffice-staff aggregate** — chosen because it preserves the PRD's distinct concept, keeps tenant RLS scoped to tenant data, and lets the backoffice role and lifecycle rules be modeled directly.

## References

- Tracks: [prds/backoffice-staff-management.md](../prds/backoffice-staff-management.md)
- [ADR-0003](0003-service-architecture.md) — service architecture and aggregate conventions.
- [ADR-0004](0004-typed-aggregate-ids-uuidv7.md) — typed aggregate IDs and UUIDv7 generation.
- [ADR-0005](0005-collection-style-repositories.md) — collection-style repository ports.
- [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) — tenant RLS authority and organization/system scope model.
- [ADR-0009](0009-safe-system-scope-rls.md) — dedicated read-only system scope and no generic system writes.
- [ADR-0011](0011-org-root-rls-hardening.md) — tenant-root RLS hardening.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) — application roles and transaction-local scope GUCs.
- [Backoffice staff-management surface and flows spec](../specs/backoffice-staff-management-surface-and-flows.md) — realizes this ADR and discharges the data-model/security-review conditions.
- [Backoffice authorization model spec](../specs/backoffice-authorization-model.md) — realizes this ADR's role/active-state authorization implications.
- `services/portal/internal/domain/staff/` — existing organization-scoped staff aggregate, role, and email value object.
- `services/portal/internal/infra/postgres/uow/uow.go` — tenant-scoped write boundary that binds `app.organization_id`.
