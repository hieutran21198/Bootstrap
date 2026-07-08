# Backoffice authorization model

> **Status**: Draft
> **Authors**: Architect
> **Last reviewed**: 2026-07-06
> **Tracks**: [PRD: backoffice-staff-management](../prds/backoffice-staff-management.md), [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md), [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md)

## Problem

Backoffice staff management must be usable only by active backoffice admins, while active members may sign in for non-management work but cannot manage the roster. The system must also prevent the active admin set from reaching zero, block accounts that have not completed forced first-login password change, and deny removed accounts even if identity-provider state lags.

This spec defines the authorization model for backoffice admin/member checks, last-admin protection, forced-change gating, and active-account enforcement. The data model, REST operations, database role/GUC boundary, and credential issue/reissue flows are primary in [the surface and flows spec](backoffice-staff-management-surface-and-flows.md).

## Goals

- Enforce PRD R7: only active `admin` accounts can create, list, update, remove, or reissue credentials for backoffice staff.
- Enforce PRD R8 under concurrency: no demotion/removal/update can leave zero active admins.
- Enforce PRD R2/SC2: a user with a temporary password/change-required provider state cannot perform any ordinary backoffice action before completing the password change.
- Enforce PRD R5 across both authorities: removed staff are inactive in the roster and blocked at Zitadel, with roster middleware denying access even if provider state lags.
- Keep provider-specific claims and `urn:zitadel:*` details inside `infra/zitadel`.

## Non-goals

- No design for tenant/customer staff authorization.
- No UI design for access-denied, expired-temporary-password, or password-change screens.
- No granular permission model beyond `admin` and `member`.
- No decision to make Zitadel roles the authorization authority for backoffice roster management; the roster aggregate is the role/active authority for application authorization.

## Background

- [PRD: Backoffice Staff Management](../prds/backoffice-staff-management.md) supplies R2, R5, R7, and R8.
- [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md) makes the roster a platform aggregate with a distinct `admin` / `member` role type.
- [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md) makes Zitadel authoritative for temporary credential and password-change state.
- [OIDC provider integration](../conventions/auth/oidc-provider-integration.md) requires provider-specific SDKs and claims to stay in `infra/zitadel` behind neutral ports.
- [Backoffice staff-management surface and flows](backoffice-staff-management-surface-and-flows.md) defines the backoffice roles, tables, `ResolveBackofficeActorBySubject`, `DoBackofficeTransaction`, `DoBackofficeQuery`, and credential lifecycle metadata this spec consumes.

## Design

### Authorization authorities

Backoffice authorization combines two authorities, each with a narrow job:

| Authority | Owns | Does not own |
| --- | --- | --- |
| Zitadel | Authentication, token/session validity, provider user disabled state, password-change-required state, password complexity. | Backoffice admin/member authorization or last-admin business rules. |
| Backoffice roster | Backoffice role (`admin`/`member`), `active` flag, last-admin invariant, staff-management authorization. | Password validation, password hashes, or authoritative must-change-password state. |

Every ordinary backoffice request must pass both gates:

1. Authenticate the OIDC bearer/session through the provider adapter.
2. Read provider credential state through `infra/zitadel`; fail closed if password change is required and the route is not the allowed password-change completion path.
3. Resolve the provider subject to minimal roster actor fields through `ResolveBackofficeActorBySubject`, which uses the dedicated `backoffice_authn` role and subject-bound GUC defined in the surface spec.
4. Fail closed if no row exists or `active = false`.
5. Check the roster role for the requested action.

### Neutral principal and provider state

Extend the backoffice authentication adapter boundary with a neutral provider state value, without leaking Zitadel types:

```go
type ProviderCredentialState struct {
    Subject                string
    Email                  string
    PasswordChangeRequired bool
    ProviderUserDisabled   bool
}
```

The adapter may learn this from a token claim, introspection, or a user-API lookup, but all `urn:zitadel:*` claim names, SDK response types, and management API details stay inside `infra/zitadel`. Delivery/app code consumes only the neutral value.

If the adapter cannot determine `PasswordChangeRequired`, it returns a provider-state error and middleware denies ordinary backoffice access. Fail-open is forbidden.

### Bootstrap actor resolution

At the start of a request, middleware has a provider subject, not a `backofficestaff.ID`. It must therefore **not** call `DoBackofficeQuery`, because that boundary requires an already-resolved actor id for `app.backoffice_actor_id`.

Instead, middleware calls `ResolveBackofficeActorBySubject(ctx, providerSubject)`. That resolver is specified in [the surface and flows spec](backoffice-staff-management-surface-and-flows.md): it uses the dedicated `backoffice_authn` DSN, binds `app.scope = 'backoffice'` plus `app.backoffice_subject = <provider subject>`, and can read only `id`, `provider_user_id`, `role`, and `active` for the matching subject. Unknown subject, missing subject, missing GUC, disabled role, or multiple-row anomalies all fail closed.

The resolver returns enough information to construct `AuthorizedBackofficeActor` or deny access. It is not a general read-store and cannot list or mutate roster rows.

### Middleware order

Backoffice middleware runs in this order for every request:

1. **Authenticate** — validate OIDC bearer/session using the auth convention's provider-neutral port.
2. **Provider credential gate** — ask `infra/zitadel` for `ProviderCredentialState` or equivalent. If `ProviderUserDisabled` is true, return unauthenticated/forbidden. If `PasswordChangeRequired` is true, allow only the provider-hosted password-change completion/callback route and deny every other backoffice route.
3. **Bootstrap actor resolution** — call `ResolveBackofficeActorBySubject` with the provider subject. This is the only subject-bound lookup and runs under `backoffice_authn`, not `backoffice_reader`.
4. **Roster active gate** — if no roster row exists or the resolved row has `active = false`, deny access even if the provider token is otherwise valid. No cache may skip this check; `active` is enforced on every request.
5. **Actor construction** — construct `AuthorizedBackofficeActor{StaffID, Role}` from the resolver result. From this point on, actor-bound reads use `DoBackofficeQuery(ctx, actor.StaffID, ...)` and writes use `DoBackofficeTransaction(ctx, actor.StaffID, ...)`.
6. **Action authorization** — check role/action matrix below.

Provider-hosted password change before normal OIDC token issuance remains the preferred path. The middleware gate is the fail-closed fallback and defense-in-depth path if Zitadel ever exposes a token/session while the provider still reports change-required state.

### Role/action matrix

The roster role is the application authorization source.

| Action | Active admin | Active member | Inactive staff | Password-change-required staff |
| --- | --- | --- | --- | --- |
| Create backoffice staff | allow | deny | deny | deny |
| List roster | allow | deny | deny | deny |
| Update staff profile/email/role | allow, subject to last-admin | deny | deny | deny |
| Remove/deactivate staff | allow, subject to last-admin | deny | deny | deny |
| Reissue temporary password | allow | deny | deny | deny |
| Ordinary non-management backoffice work | allow | allow | deny | deny |
| Password-change completion path | provider-controlled | provider-controlled | deny if roster inactive | allow only for completing the change |

The delivery layer maps member attempts on staff-management endpoints to 403. Unauthenticated, provider-disabled, inactive, unknown-roster, and forced-change cases must not reveal whether a target staff id/email exists.

### Admin-only enforcement

Staff-management use cases accept an `AuthorizedBackofficeActor` rather than a raw OIDC principal:

```go
type AuthorizedBackofficeActor struct {
    StaffID backofficestaff.ID
    Role    backofficestaff.Role
}

func (a AuthorizedBackofficeActor) RequireAdmin() error
```

Only middleware/authorization services can construct this value after provider and roster checks. Every staff-management handler calls `RequireAdmin()` before invoking the command/query use case. The use cases still repeat the admin check as defense in depth; handlers are not the only enforcement point.

`DoBackofficeTransaction` and `DoBackofficeQuery` `actorID` arguments may only be sourced from `AuthorizedBackofficeActor.StaffID`. They must never be copied from request input, target staff ids, headers, query parameters, or raw OIDC/provider claims; this makes the `app.backoffice_actor_id` GUC an honest audit value by construction.

### Last-admin safeguard

Operations that can reduce the active admin set must serialize their read-modify-write sequence:

- removing/deactivating an active admin
- changing an active admin's role to member
- changing an active admin to inactive by any future operation

Implementation uses the backoffice writer connection and `DoBackofficeTransaction` with **serializable isolation** or an equivalent explicit row-lock strategy. The required concrete pattern is:

1. Start `DoBackofficeTransaction`.
2. Lock the active admin set in deterministic order:

   ```sql
   SELECT id
   FROM backoffice.staff
   WHERE active AND role = 'admin'
   ORDER BY id
   FOR UPDATE;
   ```

3. Compute whether the requested mutation would remove the target from the active admin set.
4. If the locked active-admin count is `<= 1` and the target would no longer be an active admin, reject the mutation and leave the row unchanged.
5. Otherwise apply the mutation and commit.
6. On serialization failure/deadlock, retry the whole transaction a bounded number of times or return a retryable conflict; never apply the mutation outside this transaction.

This prevents concurrent demotions/removals from each observing “there is another admin” and jointly reducing the active admin count to zero. The same check is used by remove and role-update flows in the surface spec.

### Forced-change gate

The preferred login flow is provider-hosted:

1. User signs in with the temporary password at Zitadel Login v2.
2. Zitadel sees password-change-required state and forces a password change before issuing an ordinary OIDC session/token.
3. The backoffice receives only a normal session after the provider reports `PasswordChangeRequired = false`.

The required fallback is fail-closed middleware:

- Middleware obtains the change-required signal from the provider adapter, never from a portal/backoffice roster flag.
- If `PasswordChangeRequired = true`, middleware denies every ordinary backoffice route.
- The only allowed path is the password-change completion/callback path needed to finish the provider-hosted flow.
- If the account's temporary credential is older than 72 hours, the middleware follows the expiry flow in the surface spec: deny access, invalidate where possible, mark the credential expired, and require admin reissue.

The backoffice database may store non-secret timestamps (`temporary_password_issued_at`, `first_login_completed_at`) for audit/display, but those timestamps are not the authority for “must change password”. They are reconciled from provider state.

### Active and provider-disabled enforcement

Removal/deactivation is intentionally enforced twice:

1. **Roster half:** set `backoffice.staff.active = false` under `DoBackofficeTransaction` after passing the last-admin safeguard.
2. **Provider half:** call Zitadel to deactivate/lock the provider user and revoke token issuance/session validity where supported.

Ordering and failure mode:

- The roster is deactivated first because the roster middleware runs on every backoffice request and can fail closed even while provider deactivation is delayed.
- After roster deactivation commits, the command calls Zitadel to deactivate/lock the user.
- If Zitadel deactivation fails, the roster remains inactive, all backoffice requests for that subject are denied by middleware, and an operational retry/alert is emitted.
- If the roster update fails, do not call Zitadel and leave the account active.
- If a retry later succeeds in Zitadel, no roster state change is needed.

This split means provider lag can at worst allow an identity-provider login, not backoffice access.

### Relationship to surface flows

- Create/list/update/remove/reissue endpoints and the protected backoffice DB boundary are defined in [the surface and flows spec](backoffice-staff-management-surface-and-flows.md).
- This spec is the source of truth for who may call those endpoints.
- The forced-change and 72-hour expiry checks span both specs: this spec defines the access gate, while the surface spec defines issuance timestamps, provider invalidation, reissue, and monitoring.

## Alternatives considered

- **Trust Zitadel roles/claims as the sole backoffice authorization source** — rejected because the roster aggregate owns role and active state, and last-admin protection is a domain invariant over roster rows.
- **Check active/role only at login and cache for the session** — rejected because R5 requires removal to prevent performing any action from that point forward. Middleware must read roster active state on every request or use an invalidation mechanism with equivalent immediate semantics; this spec requires the direct read.
- **Application-owned `must_change_password` flag** — rejected by ADR-0025 and the security condition. Forced-change state must come from Zitadel.
- **Best-effort last-admin check without locks** — rejected because concurrent demotions/removals can race and leave zero active admins.
- **Provider deactivation before roster deactivation** — rejected because a provider failure would leave the roster active; roster-first gives the backoffice app an immediate fail-closed gate.

## Open questions

- **Provider signal source:** implementation must verify against Zitadel v4.13.0 whether `PasswordChangeRequired` is available in a token claim, introspection response, or only through a user-management API lookup. The adapter boundary is fixed; the internal source is open until verified.
- **Password-change callback shape:** exact hosted Login v2 callback/route behavior must be verified during implementation so the middleware can allow only the minimal completion path.

## Implementation plan

- [ ] Add neutral provider credential-state methods/types to the backoffice auth adapter boundary and implement them in `infra/zitadel` without leaking provider claims.
- [ ] Add backoffice middleware that authenticates, checks provider credential state, resolves the actor through `ResolveBackofficeActorBySubject`, checks active state, and builds `AuthorizedBackofficeActor`; use `DoBackofficeQuery` only after actor construction.
- [ ] Apply the role/action matrix to all generated OpenAPI staff-management handlers and repeat admin checks in app use cases.
- [ ] Implement last-admin checks inside serialized `DoBackofficeTransaction` mutations for remove and role update.
- [ ] Implement roster-first deactivation plus provider deactivation/retry/alert behavior for remove.
- [ ] Add tests for member denial, inactive denial, unknown-roster denial, forced-change denial, last-admin concurrent demotion/removal, and provider-deactivation failure.

## References

- [PRD: Backoffice Staff Management](../prds/backoffice-staff-management.md)
- [ADR-0024](../adrs/0024-model-backoffice-staff-as-platform-aggregate.md)
- [ADR-0025](../adrs/0025-use-zitadel-for-backoffice-temporary-credential-lifecycle.md)
- [Backoffice staff-management surface and flows spec](backoffice-staff-management-surface-and-flows.md)
- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md)
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md)
