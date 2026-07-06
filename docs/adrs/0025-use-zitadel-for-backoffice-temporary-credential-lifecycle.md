# 0025. Use Zitadel for backoffice temporary credential lifecycle

- **Status**: Accepted
- **Date**: 2026-07-06
- **Deciders**: product owner (human)
- **Supersedes**: -
- **Superseded by**: -

## Context

The accepted backoffice staff management PRD requires account creation with a system-generated temporary password, a mandatory password change before any other backoffice action, a password-strength rule, and expiry of an unused temporary password after 72 hours. These requirements sit on the boundary between the backoffice roster and the identity system.

ADR-0006 already adopted Zitadel as the workspace identity and auth provider, with services integrating through OIDC and provider-specific details contained behind an `infra/zitadel` adapter. That decision makes Zitadel responsible for authentication, login UX, and credential verification. The portal/backoffice application still owns its domain roster and authorization decisions, but it should not casually become a second password authority.

This ADR decides where the temporary credential, forced first-login password-change state, and unused-temporary-password expiry are authoritative: in Zitadel, or in the portal application as shadow credential state.

## Decision

We will make Zitadel the authority for backoffice temporary credentials, password-strength policy, forced first-login password change, and unused-temporary-password expiry; the portal/backoffice application only initiates lifecycle commands through its provider adapter and stores non-secret roster/audit metadata. The `must change password` state lives in Zitadel, and the login flow must complete the provider's password-change step before the backoffice accepts an ordinary authenticated session.

## Consequences

- **Positive**:
  - The application does not store password hashes, validate temporary passwords, or maintain a second credential state machine, preserving ADR-0006's identity-provider boundary.
  - The forced first-login change can occur in the provider login flow before a normal OIDC session is accepted by the backoffice, directly supporting the PRD's requirement that no other backoffice action is available first.
  - Password-strength and credential audit behavior are centralized in the identity provider instead of being split across provider and application code.
  - Reissuing or expiring a temporary credential becomes an identity lifecycle operation with one authority: Zitadel.
- **Negative**:
  - The onboarding flow becomes coupled to Zitadel management APIs and login behavior; tests and local development need the identity stack, not only the portal database.
  - If Zitadel does not provide one exact native primitive for the 72-hour unused-temporary-password expiry, the application may need a scheduled or on-demand command that invalidates the temporary credential in Zitadel. That command may keep non-secret timing metadata, but the credential's validity must still be changed in Zitadel, not enforced by a shadow app flag.
  - Identity-provider outages can block account creation, reissue, first-login change, or expiry handling.
  - Specs must define how a temporary password is delivered/displayed safely; this ADR only decides the authority and state boundary.
- **Neutral**:
  - The backoffice aggregate from ADR-0024 can store the provider subject/user id and non-secret lifecycle timestamps for roster display, audit, or reissue decisions, but not the password or authoritative `must change password` flag.
  - The OIDC adapter remains provider-specific behind `infra/zitadel`; app and delivery layers consume neutral authentication results per the auth convention.
  - If the provider ever emits a token for an account still marked as requiring password change, backoffice middleware must fail closed for all ordinary routes and allow only the password-change completion path. The preferred flow is provider-hosted change before token issuance.
  - **Acceptance note (2026-07-06):** the product owner accepted this ADR together with ADR-0024's separate-runtime boundary and scoped backoffice role/GUC-contract extension. Security-review conditions on Zitadel primitive verification, forced-change enforcement, 72-hour expiry fail-direction, password complexity, temporary-password handling, and active-account blocking are mandatory downstream spec obligations.

## Alternatives considered

- **Application-owned temporary passwords and `must_change_password` state** — rejected because it makes the portal/backoffice application a password system in parallel with Zitadel. The app would need to generate, hash, validate, expire, and clear credentials, then ensure every backoffice route checks the shadow state after authentication; one missed gate would violate the first-login restriction.
- **Split ownership: Zitadel authenticates the password, portal stores the forced-change and expiry flags** — rejected because it creates two sources of truth. A user could be authenticated by the provider while the app thinks the credential is expired or still temporary, or the app could clear a flag while the provider still treats the credential as initial.
- **Zitadel-owned credential lifecycle** — chosen because ADR-0006 already makes the identity provider the credential authority. The application may orchestrate account creation, reissue, and expiry through the adapter, but the durable password-change requirement and credential validity live in the provider.
- **Bypass temporary passwords with an invitation or passwordless setup flow** — rejected for this PRD because the accepted requirements explicitly call for a system-generated temporary password and forced replacement at first login. A future PRD may choose a different onboarding credential model.

## References

- Tracks: [prds/backoffice-staff-management.md](../prds/backoffice-staff-management.md)
- [ADR-0006](0006-zitadel-identity-auth.md) — Zitadel as the identity and auth provider.
- [ADR-0024](0024-model-backoffice-staff-as-platform-aggregate.md) — distinct platform-level backoffice staff aggregate.
- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md) — provider-specific SDK and claims stay behind `infra/zitadel`.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) — separates identity from portal tenant/system data scope.
- [Backoffice staff-management surface and flows spec](../specs/backoffice-staff-management-surface-and-flows.md) — realizes account creation, credential issue/reissue, expiry, and temporary-password handling.
- [Backoffice authorization model spec](../specs/backoffice-authorization-model.md) — realizes forced-change and active-account access gates.
- [Zitadel documentation](https://zitadel.com/docs) — provider behavior to use through the adapter and verify in the downstream implementation spec.
