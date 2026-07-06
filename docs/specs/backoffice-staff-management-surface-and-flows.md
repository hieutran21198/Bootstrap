# Backoffice staff-management surface and flows

> **Status**: Draft
> **Authors**: Architect
> **Last reviewed**: 2026-07-06
> **Tracks**: [PRD: backoffice-staff-management](../prds/backoffice-staff-management.md), [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md), [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md)

## Problem

Backoffice admins need a self-service surface to create, list, update, remove, and reissue onboarding credentials for platform-level backoffice staff. The design must realize the accepted PRD without reusing the tenant-scoped `staff.Staff` aggregate, without weakening tenant RLS, and without making the portal application a second password authority.

This spec covers the staff-management data model, REST surface, command/query flows, database privilege boundary, and credential lifecycle mechanics. The authorization rules that decide who may call those actions, including last-admin and forced-change gates, are primary in [the backoffice authorization model spec](backoffice-authorization-model.md).

## Goals

- Implement create, list, update, remove, and temporary-password reissue flows for backoffice staff accounts (PRD R1, R3, R4, R5, R9, R10, R11).
- Keep backoffice staff as a distinct platform aggregate with `admin` / `member` roles only.
- Introduce a fail-closed database boundary for backoffice tables: dedicated roles, explicit grants, forced RLS, and a named `DoBackofficeTransaction`/`DoBackofficeQuery` boundary.
- Run the backoffice runtime/deployment separately from the tenant-facing portal binary, with no backoffice DSN in tenant-facing portal configuration.
- Use Zitadel as the credential authority while never persisting or logging temporary passwords.
- Specify the 72-hour unused temporary-password expiry path, including the app-driven fallback if Zitadel v4.13.0 has no native TTL for initial passwords.

## Non-goals

- No tenant or customer staff management; tenant staff stay under the existing organization-scoped `staff.Staff` model.
- No broad cross-tenant tenant-data writes and no generic `DoSystemTransaction`.
- No MFA, self-service password reset, SSO/social login, invitation-only onboarding, or passwordless onboarding.
- No granular backoffice roles beyond `admin` and `member`.
- No UI component design; this spec defines API/application behavior and security boundaries.

## Background

- [PRD: Backoffice Staff Management](../prds/backoffice-staff-management.md) supplies requirements R1, R3, R4, R5, R9, R10, and R11 for this spec.
- [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md) decides that backoffice staff are a distinct platform-level aggregate.
- [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md) makes Zitadel authoritative for temporary credentials and first-login password-change state.
- [ADR-0009](../adrs/0009-safe-system-scope-rls.md) bans generic system writes until a separate ADR; this spec therefore defines a named, scoped backoffice write boundary rather than reviving a scope-less transaction path.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) is extended by ADR-0024 acceptance: implementation must add the scoped backoffice role/GUC contract to that convention.
- [Contract-first OpenAPI](../conventions/api/contract-first-openapi.md) requires a hand-authored OpenAPI contract under the service API directory with generated Echo delivery code.
- Local identity is pinned to Zitadel `v4.13.0` in [`deploy/local/.env.example`](../../deploy/local/.env.example).

## Design

### Runtime and deployment boundary

Backoffice staff management runs in a **separate runtime/deployment** from the tenant-facing portal command/query binaries. The backoffice runtime may live in the same Go module for code reuse, but it is a separate process with separate configuration and DSNs.

Mandatory boundary rules:

- The tenant-facing portal binary never receives `backoffice_authn`, `backoffice_writer`, or `backoffice_reader` DSNs.
- The backoffice runtime holds **no** tenant `writer`/`reader` DSNs at all until a separate accepted design licenses a specific tenant-data access path.
- Runtime wiring must make accidental import/config sharing visible in review: backoffice config fields are named separately, e.g. `BACKOFFICE_DATABASE_AUTHN_DSN`, `BACKOFFICE_DATABASE_WRITER_DSN`, and `BACKOFFICE_DATABASE_READER_DSN`.
- Backoffice access to tenant-owned data, if a later flow needs it, must use the ADR-0009 `system_reader` capability model in a separate design; this staff-management surface does not require tenant-data reads.

### Database privilege, RLS, and role/GUC contract

Backoffice tables are **not tenant data**, but they still must be fail-closed. “No RLS because it is not tenant data” is forbidden.

Implementation extends the database role-and-scope contract with:

| Runtime | Role | Grants | Scope GUCs | Notes |
| --- | --- | --- | --- | --- |
| Backoffice authentication lookup | `backoffice_authn` (`NOBYPASSRLS`, `NOINHERIT`) | explicit column `SELECT` on `backoffice.staff(id, provider_user_id, role, active)` only | `app.scope = 'backoffice'`, `app.backoffice_subject = <Zitadel subject>` | Used only by `ResolveBackofficeActorBySubject` before a roster `id` is known. |
| Backoffice command | `backoffice_writer` (`NOBYPASSRLS`, `NOINHERIT`) | explicit `SELECT, INSERT, UPDATE` on backoffice tables only | `app.scope = 'backoffice'`, `app.backoffice_actor_id = <staff id>` | Used only by `DoBackofficeTransaction`. |
| Backoffice query | `backoffice_reader` (`NOBYPASSRLS`, `NOINHERIT`) | explicit `SELECT` on backoffice tables only | `app.scope = 'backoffice'`, `app.backoffice_actor_id = <staff id>` | Used only by `DoBackofficeQuery`. |
| Tenant command/query | existing `writer` / `reader` | no `USAGE` on backoffice schema and no grants on backoffice tables | existing tenant/system GUCs only | Must not be able to read or write backoffice tables by default. |

The `backoffice_authn`, `backoffice_writer`, and `backoffice_reader` login roles are created by Nix `core.services.postgres` role provisioning, matching the `system_reader` precedent. Migrations own schema/table creation, RLS policies, and explicit grants to those pre-provisioned roles; migrations must not create ad-hoc request roles.

Backoffice tables live in a dedicated `backoffice` schema. Migrations must:

1. Revoke tenant-role access to the `backoffice` schema: no `USAGE` or table privileges for `writer`/`reader`.
2. Avoid schema-wide default grants that include backoffice tables for tenant roles. If existing provisioning grants schema-wide privileges, implementation must explicitly `REVOKE` those privileges and set default privileges for future backoffice tables to exclude tenant roles.
3. Grant `backoffice_authn`, `backoffice_writer`, and `backoffice_reader` privileges explicitly table-by-table; `backoffice_authn` receives only column-level `SELECT` on the bootstrap columns.
4. `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY` on every backoffice table.
5. Add policies only for the backoffice roles. A missing or wrong GUC fails closed.

Actor-bound policy shape for general roster reads/writes:

```sql
CREATE POLICY backoffice_staff_scope_writer
ON backoffice.staff
TO backoffice_writer
USING (
  current_setting('app.scope', true) = 'backoffice'
  AND nullif(current_setting('app.backoffice_actor_id', true), '') IS NOT NULL
)
WITH CHECK (
  current_setting('app.scope', true) = 'backoffice'
  AND nullif(current_setting('app.backoffice_actor_id', true), '') IS NOT NULL
);

CREATE POLICY backoffice_staff_scope_reader
ON backoffice.staff
TO backoffice_reader
USING (
  current_setting('app.scope', true) = 'backoffice'
  AND nullif(current_setting('app.backoffice_actor_id', true), '') IS NOT NULL
);
```

`app.backoffice_actor_id` is for fail-closed binding and audit correlation, not for row filtering; all active backoffice admins can manage the whole backoffice roster. The authorization model spec defines how a caller becomes an authorized actor before the GUC is bound.

Authentication bootstrap lookup has a separate, narrower role and policy because middleware initially has only the OIDC subject, not a `backofficestaff.ID`:

```sql
GRANT SELECT (id, provider_user_id, role, active)
ON backoffice.staff
TO backoffice_authn;

CREATE POLICY backoffice_staff_authn_lookup
ON backoffice.staff
FOR SELECT
TO backoffice_authn
USING (
  current_setting('app.scope', true) = 'backoffice'
  AND nullif(current_setting('app.backoffice_subject', true), '') IS NOT NULL
  AND provider_user_id = current_setting('app.backoffice_subject', true)
);
```

`backoffice_authn` has no `INSERT`, `UPDATE`, `DELETE`, no full-table `SELECT`, no grants on tenant tables, and no `app.backoffice_actor_id` policy branch. This keeps the actor-id GUC contract honest: the subject-bound lookup can only resolve the authenticated subject to the minimal roster fields needed to build or deny an actor; all subsequent roster reads/writes use `backoffice_reader`/`backoffice_writer` with `app.backoffice_actor_id` bound.

### Named application boundary

Add separate app-layer ports rather than widening the existing tenant UoW:

```go
type BackofficeTransactionalUnitOfWork interface {
    BackofficeStaff() backofficestaff.Writer
}

type BackofficeUnitOfWork interface {
    DoBackofficeTransaction(
        ctx context.Context,
        actorID backofficestaff.ID,
        handler BackofficeTransactionalUnitOfWorkHandler,
    ) error
}

type BackofficeTransactionalReadStore interface {
    BackofficeStaff() backofficestaff.Reader
}

type BackofficeReadStore interface {
    DoBackofficeQuery(
        ctx context.Context,
        actorID backofficestaff.ID,
        handler BackofficeTransactionalReadStoreHandler,
    ) error
}

type BackofficeActorLookup struct {
    StaffID        backofficestaff.ID
    ProviderUserID string
    Role           backofficestaff.Role
    Active         bool
}

type BackofficeActorResolver interface {
    ResolveBackofficeActorBySubject(ctx context.Context, providerSubject string) (BackofficeActorLookup, error)
}
```

The postgres implementation opens a transaction, validates `actorID` as UUIDv7, binds `app.scope = 'backoffice'` and `app.backoffice_actor_id = actorID` as the first statements via transaction-local `set_config(..., true)`, then hands the scoped accessor to the handler.

`ResolveBackofficeActorBySubject` is the only pre-authorization bootstrap read. It uses the `backoffice_authn` DSN, validates that `providerSubject` is non-empty, binds `app.scope = 'backoffice'` and `app.backoffice_subject = providerSubject` transaction-locally, and returns only `id`, `provider_user_id`, `role`, and `active`. It does **not** accept an actor id and does not expose a callback/read-store surface.

Because the provider subject is an external identifier and cannot be UUIDv7-validated, the subject GUC bind must be parameterized in the same style as the existing binders: `select set_config('app.backoffice_subject', ?, true)` after a non-empty check.

The `actorID` passed to `DoBackofficeTransaction` and `DoBackofficeQuery` may only come from `AuthorizedBackofficeActor.StaffID` constructed after `ResolveBackofficeActorBySubject`; it must never come from request path parameters, request bodies, headers, or raw provider claims.

Forbidden:

- Do not uncomment or reintroduce the scope-less `DoTransaction` path on the tenant connection.
- Do not add `BackofficeStaff()` to the tenant `TransactionalUnitOfWork` returned by `DoOrganizationTransaction`.
- Do not use `admin`/`BYPASSRLS` for request traffic.

### Domain aggregate

Create a new domain package for the platform account concept, e.g. `internal/domain/backofficestaff`.

Aggregate fields:

| Field | Type / rule |
| --- | --- |
| `id` | typed `backofficestaff.ID` generated with UUIDv7. |
| `providerUserID` | Zitadel human user id / OIDC subject; non-empty and unique while the row exists. |
| `email` | normalized email value object; unique among active accounts only. |
| `firstName`, `lastName` | trimmed, non-empty, length-limited. |
| `role` | **distinct** `backofficestaff.Role` with only `RoleAdmin` and `RoleMember`. It must not reuse or delegate parsing to tenant `staff.Role`; `owner` must be invalid. |
| `active` | boolean; `false` means removed/deactivated in the roster. |
| `temporaryPasswordIssuedAt` | nullable timestamp of the latest temporary credential issuance/reissue. |
| `temporaryPasswordInvalidatedAt` | nullable timestamp set when the unused temporary credential is invalidated after expiry. |
| `firstLoginCompletedAt` | nullable timestamp learned from provider state/event when the initial password has been replaced. |

The aggregate owns only non-secret roster and lifecycle metadata. It never contains the temporary password, a password hash, or an authoritative `mustChangePassword` flag. Whether the password still requires change is read from Zitadel through `infra/zitadel`.

### Persistence model

Primary table:

```text
backoffice.staff
  id text primary key
  provider_user_id text not null unique
  email text not null
  first_name text not null
  last_name text not null
  role text not null check (role in ('admin', 'member'))
  active boolean not null default true
  temporary_password_issued_at timestamptz null
  temporary_password_invalidated_at timestamptz null
  first_login_completed_at timestamptz null
  created_at timestamptz not null
  updated_at timestamptz not null
  deactivated_at timestamptz null
```

R9/A3 email reuse is implemented with a partial unique index, not a plain unique column:

```sql
CREATE UNIQUE INDEX backoffice_staff_active_email_unique
ON backoffice.staff (lower(email))
WHERE active;
```

The domain still normalizes email before persistence, but the index uses `lower(email)` as defense in depth so case-variant duplicates cannot bypass R9. This allows a removed account's email to be reused by a later active account while preventing two active accounts from sharing an email identity.

Optional audit/event tables may be added later, but they must follow the same dedicated-role + forced-RLS rules and must never store temporary-password values.

### REST surface

Author a contract-first OpenAPI document, e.g. `services/portal/api/backoffice-staff.yaml`, and generate Echo delivery code under the backoffice HTTP delivery package. Generated DTOs stay at the delivery boundary.

Initial operations:

| Operation | Method/path | Serves | Notes |
| --- | --- | --- | --- |
| Create staff | `POST /backoffice/staff` | R1, R9, R10 | Request: email, firstName, lastName, role. Response includes roster record plus `temporaryPassword` exactly once. |
| List staff | `GET /backoffice/staff` | R3 | Returns email, firstName, lastName, role, active, and credential-lifecycle summary without secrets. |
| Update staff | `PATCH /backoffice/staff/{id}` | R4, R9 | Allows firstName, lastName, email, role. Role changes defer last-admin checks to authorization spec. |
| Remove staff | `DELETE /backoffice/staff/{id}` | R5 | Deactivates roster/provider; preserves history. |
| Reissue temporary password | `POST /backoffice/staff/{id}/temporary-password` | R11 | Allowed only when the account has not completed first login or after expiry; response includes new temporary password exactly once. |

Authorization for these operations is defined in [the authorization spec](backoffice-authorization-model.md): every operation is admin-only, and remove/demote paths must preserve at least one active admin.

### Create flow

1. Backoffice HTTP delivery authenticates the caller and asks the authorization layer for an active admin actor (see authorization spec).
2. Validate email/name/role. Role parsing uses only `backofficestaff.NewRole`; `owner` is rejected.
3. Generate a temporary password in memory using a cryptographically secure random source. The generator must satisfy Zitadel's configured backoffice password policy and PRD R10.
4. Through `infra/zitadel`, create a human user in the dedicated backoffice Zitadel org and set the initial password with password-change-required semantics.
5. In `DoBackofficeTransaction`, insert the roster row with `active = true`, `provider_user_id`, and `temporary_password_issued_at = now()`.
6. If the DB insert fails, immediately deactivate/delete the just-created Zitadel user and return an error without returning the temporary password. If compensation fails, emit an operational alert; do not leave a returned password for an untracked roster row.
7. Return the created roster representation and the temporary password exactly once in the successful response.

No request, response, app error, audit row, structured log, or panic wrapper may include the temporary password. Delivery middleware must redact the create/reissue response body from access logs if response-body logging is ever enabled.

### List flow

List runs under `DoBackofficeQuery` and returns roster rows, including active state and non-secret credential lifecycle fields:

- `temporaryPasswordIssuedAt`
- `temporaryPasswordExpired` derived from provider state + `temporaryPasswordIssuedAt`
- `firstLoginCompletedAt`

The list endpoint does not expose provider-native claims beyond a stable internal backoffice staff id. Provider user id may be admin-visible only if an operational need is documented in the OpenAPI description.

### Update flow

Updates run in `DoBackofficeTransaction` and persist aggregate changes only after domain validation.

- Email changes must update Zitadel and the roster. If Zitadel update fails, the roster is not changed. If the roster update fails after the provider update, the adapter attempts to restore the previous provider email and emits an alert on compensation failure.
- Role changes use the backoffice role type and are subject to the last-admin safeguard in the authorization spec.
- Name changes update both roster and provider profile when Zitadel stores the corresponding profile fields; otherwise the roster remains the display authority for the backoffice UI.

### Remove flow

Remove means deactivation, not deletion. The authorization spec owns the active-access failure mode; this surface defines the mutation shape:

1. In `DoBackofficeTransaction`, validate last-admin constraints through the authorization service and set `active = false`, `deactivated_at = now()`.
2. Call the Zitadel adapter to deactivate/lock the provider user and revoke token issuance/session validity where supported.
3. If the provider call fails after the roster has been deactivated, keep `active = false`, return an error status that tells the admin the roster is blocked, enqueue/emit a retryable operational alert, and rely on authorization middleware to deny every request for the inactive roster account.

### Reissue temporary password flow

Reissue is an admin action for accounts that have not completed first login or whose temporary password expired.

1. Generate a new temporary password in memory.
2. Through `infra/zitadel`, set the user's password with password-change-required semantics and invalidate any previous temporary credential/session state supported by Zitadel.
3. In `DoBackofficeTransaction`, set `temporary_password_issued_at = now()`, clear `temporary_password_invalidated_at`, and keep `first_login_completed_at = null` unless the provider says first login already completed.
4. Return the new temporary password exactly once.

### Zitadel v4.13.0 credential primitives

The pinned target is Zitadel `v4.13.0` (`ZITADEL_VERSION=v4.13.0`). The implementation must verify exact method/field names against that version before coding the adapter. The expected primitives are:

- Human-user creation / password setting with a password-change-required flag. The local first-instance config already uses `ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORDCHANGEREQUIRED`, and runtime management API/SDK calls must use the equivalent human-user create/set-password primitive for backoffice users.
- Hosted Login v2 enforcement of the change-required state before issuing an ordinary OIDC session/token. This must be proven by an integration test against the local v4.13.0 stack.
- Password complexity policy on the Zitadel org. Backoffice users should live in a dedicated Zitadel org so the backoffice password policy can be configured without weakening tenant/customer identity policy.

Native TTL for unused initial passwords is not assumed. If v4.13.0 exposes a native unused-initial-password TTL that can be set to 72 hours, use it and keep the app-side timestamp for audit/reissue display. If not, use the fallback below.

### 72-hour expiry fallback

The fallback is a security control, not cleanup.

- `temporary_password_issued_at` is written only in `DoBackofficeTransaction` under the protected backoffice table boundary.
- A monitored job scans accounts with `temporary_password_issued_at < now() - interval '72 hours'`, no `first_login_completed_at`, and no `temporary_password_invalidated_at`.
- For each candidate, the job asks Zitadel whether the user still has change-required/initial-password state. The provider is authoritative for “unused vs used”.
- If Zitadel says the temporary password is still unused, the job invalidates the credential in Zitadel, sets `temporary_password_invalidated_at`, and emits metric/log evidence. The invalidation primitive must be conditional/atomic on the provider still reporting initial-password/change-required state, or the adapter must prove the chosen invalidation is safe after a legitimate password change. If the provider cannot supply either property, the implementation must not ship the fallback as accepted.
- If Zitadel says the password was changed, the job sets `first_login_completed_at` and does not invalidate.
- The job must be monitored: failures and stale candidates older than 72 hours plus the job interval alert operators.
- The login-adjacent path also performs the same provider-authoritative check. If an account presents an ordinary session while provider state still indicates an unused temporary password older than 72 hours, the backoffice denies access, invalidates the credential where possible, marks it expired, and tells the user to ask an admin for reissue.

### Password policy mapping

PRD R10 requires every temporary and staff-chosen password to be at least 12 characters long and include at least one letter and one number.

Backoffice implementation configures a dedicated Zitadel org password complexity policy that is equivalent-or-stricter:

- minimum length `>= 12`
- at least one alphabetic character, mapped to Zitadel's available letter/upper/lower policy controls
- at least one digit/number
- any additional Zitadel default requirements are accepted as stricter, not a PRD violation

If Zitadel's v4.13.0 policy cannot express exactly “one letter regardless of case”, configure the stricter available combination and document the delta in implementation evidence.

### Temporary-password handling

Temporary passwords are secrets with display-once semantics.

- Generate only in memory.
- Send only to Zitadel and the immediate create/reissue response.
- Never store in database rows, audit rows, traces, metrics, structured logs, task evidence, or error messages.
- UI must display once with clear “copy now” messaging and no later retrieval endpoint.
- If the response cannot be delivered to the admin, the safe recovery is reissue, not lookup.

## Alternatives considered

- **Backoffice tables without RLS because they are not tenant data** — rejected because tenant `writer`/`reader` currently have broad grants; a new non-RLS table would fail open to tenant-facing roles.
- **Reuse tenant `writer`/`reader` roles with application-only guards** — rejected because it repeats the class of failure ADR-0008 removed for tenant data and violates the accepted security condition.
- **Use a subject-bound policy branch on `backoffice_reader` for bootstrap lookup** — rejected because it widens the general reader role with two identities (`app.backoffice_subject` before authorization and `app.backoffice_actor_id` after authorization). A dedicated `backoffice_authn` role is one more role, but it keeps the pre-authorization lookup column-limited and preserves the actor-id GUC as the only general read/audit path.
- **A generic `DoTransaction` on the existing UnitOfWork** — rejected because ADR-0009 bans a scope-less/generic privileged write path on the tenant connection.
- **Plain unique email column** — rejected because the PRD allows email reuse after deactivation; a partial unique index on active rows matches R9/A3.
- **Application-owned password hashes and expiry state** — rejected by ADR-0025; Zitadel remains the credential authority.

## Open questions

- **Zitadel v4.13.0 primitive verification:** implementation must verify the exact management API/SDK method names for human-user create/set-password with change-required semantics, hosted Login v2 pre-token enforcement, and whether a native unused-initial-password TTL exists. This spec designs the required fallback if no native TTL exists.
- **Response-body logging posture:** if the backoffice runtime later enables HTTP response-body logging, the implementation must prove create/reissue bodies are redacted before this spec can move past Draft.

## Implementation plan

- [ ] **Draft → Accepted gate:** define and run privilege/RLS isolation tests proving tenant `writer`/`reader` are denied on the `backoffice` schema; `backoffice_authn`, `backoffice_writer`, and `backoffice_reader` all return `false` for `rolsuper OR rolbypassrls`; missing/wrong GUCs return zero rows for every backoffice policy; cross-branch GUCs fail closed (`app.backoffice_subject` on `backoffice_reader`/`backoffice_writer`, and `app.backoffice_actor_id` on `backoffice_authn`, return zero rows); `backoffice_authn` can select only `id`, `provider_user_id`, `role`, and `active`; and backoffice roles have no grants on tenant tables.
- [ ] Provision the backoffice database roles in Nix `core.services.postgres`; add the backoffice schema, forced RLS policies, explicit grants, and partial active-email unique index in migrations; update `docs/conventions/database/role-and-scope-contract.md` in the same implementation slice.
- [ ] Add the `backofficestaff` domain package with distinct ID, email/name, role, and aggregate lifecycle rules.
- [ ] Add `BackofficeActorResolver`, `BackofficeUnitOfWork`, and `BackofficeReadStore` ports and postgres adapters binding either `app.backoffice_subject` for bootstrap lookup or `app.backoffice_actor_id` for actor-bound reads/writes transaction-locally.
- [ ] Add the `infra/zitadel` management adapter for create user, set/reissue initial password, update profile/email, read credential state, invalidate temporary credential, and deactivate user.
- [ ] Author `services/portal/api/backoffice-staff.yaml`, generate delivery code, and implement handlers that translate DTOs to app commands/queries.
- [ ] Implement create, list, update, remove, and reissue use cases with the ordering/failure modes above.
- [ ] Add the 72-hour expiry job and login-adjacent expiry check, with metrics/alerts for stale unprocessed credentials.
- [ ] Add integration tests against Zitadel v4.13.0 for change-required behavior, password policy mapping, and expiry fallback.

## References

- [PRD: Backoffice Staff Management](../prds/backoffice-staff-management.md)
- [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md)
- [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md)
- [Backoffice authorization model spec](backoffice-authorization-model.md)
- [ADR-0009](../adrs/0009-safe-system-scope-rls.md)
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md)
- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md)
- [Contract-first OpenAPI convention](../conventions/api/contract-first-openapi.md)
- [`deploy/local/.env.example`](../../deploy/local/.env.example) — Zitadel `v4.13.0` pin.
