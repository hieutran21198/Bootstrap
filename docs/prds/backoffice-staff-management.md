# Backoffice Staff Management

> **Status**: Accepted
> **Authors**: Scribe (agent session, backoffice staff management PRD)
> **Last reviewed**: 2026-07-06
> **Realized by**: — (pending)

> **PRD rule — requirements only.** Capture **what** users need and **why**. Do **not** name a technology, API, schema, or design — the "how" belongs in [`specs/`](../specs/) and the decision in [`adrs/`](../adrs/). If you catch yourself designing, stop and push it downstream.
>
> **Draft → Accepted self-check.** Before changing `Status` out of `Draft`, confirm: every requirement has a stable ID; every requirement is singular, measurable where relevant, and testable by inspection/demo/test; success criteria are measurable and technology-agnostic; scope has explicit in/out boundaries; assumptions and constraints are explicit and not design decisions; no `[NEEDS CLARIFICATION]` markers remain; no implementation details leaked into requirements, success criteria, or Downstream Handoff; every domain term is defined in or nominated for [`glossary/`](../glossary/); downstream links are listed under **Realized by**.

## Problem / Context

The platform's backoffice is operated by an internal team of operators and support staff, but there is currently no controlled way to manage who those people are or what they can do. Today, granting or removing a person's ability to sign into and act within the backoffice has no defined, self-service path for the team's own admins — every account change depends on someone outside the team. As the operator/support team grows, this becomes a bottleneck and a security gap: there is no record of who currently has backoffice access, no controlled onboarding step that forces a new hire to set their own credential before use, and no way for the team to remove a departing member's access without external help.

This capability lets a designated backoffice admin manage the roster of backoffice staff directly — onboarding new staff with a forced first-login credential change, viewing and updating existing staff, and removing staff who should no longer have access — without needing to make every account change a special request outside the team.

This PRD covers only the platform's own internal backoffice staff (the operators and support people who sign into the backoffice itself). It does not cover any tenant's own staff, and it does not cover cross-tenant management of a customer's staff.

## Users & personas

- **Backoffice Admin** — an internal operator responsible for the backoffice staff roster: creates new staff accounts, edits existing accounts' details and role, and removes staff who should no longer have access.
- **Backoffice Member** — an internal operator who uses the backoffice for their day-to-day work but has no ability to manage other staff accounts.
- **Newly onboarded staff** — a person who was just given a backoffice staff account (as an admin or a member) and is completing their first sign-in, including the mandatory change away from the temporary password they were issued.

## Success criteria / metrics

- **SC1** — A backoffice admin can create a new staff account, and the newly onboarded staff member can complete first sign-in — including the mandatory password change — without external help, in 5 of 5 observed onboarding trials.
- **SC2** — 100% of newly created backoffice staff accounts are blocked from performing any backoffice action other than changing the temporary password, until that password change is completed.
- **SC3** — A backoffice admin can find any existing staff account and complete an update to its name, email, or role in 100% of observed update attempts, without needing engineering assistance.

## Requirements

- **R1** — WHEN a backoffice admin creates a backoffice staff account by providing its email, first name, last name, and role, THE SYSTEM SHALL create the account with a system-generated temporary password and mark it as requiring a password change before the account can be used for any other action. SO THAT new staff can be onboarded without a self-chosen credential being shared or set up in advance.
- **R2** — WHEN a backoffice staff member signs in using a temporary password, THE SYSTEM SHALL require the member to set a new password before granting access to any other backoffice function.
- **R3** — THE SYSTEM SHALL let a backoffice admin view the list of all backoffice staff accounts, including each account's email, first name, last name, role, and whether it is active.
- **R4** — WHEN a backoffice admin updates a backoffice staff account's first name, last name, email, or role, THE SYSTEM SHALL persist the change and reflect it the next time the account is viewed.
- **R5** — WHEN a backoffice admin removes a backoffice staff account, THE SYSTEM SHALL deactivate the account — preventing it from signing into or performing any action in the backoffice from that point forward — while preserving its record and history.
- **R6** — THE SYSTEM SHALL assign each backoffice staff account exactly one role, either admin or member.
- **R7** — THE SYSTEM SHALL restrict backoffice staff-management actions (create, view the roster, update, remove) to accounts with the admin role; accounts with the member role SHALL NOT be able to perform them.
- **R8** — IF an action would remove or demote the last remaining active admin account, THEN THE SYSTEM SHALL reject that action and leave the account unchanged. SO THAT the backoffice staff roster never becomes unmanageable.
- **R9** — THE SYSTEM SHALL NOT permit two active backoffice staff accounts to share the same email identity.
- **R10** — THE SYSTEM SHALL require every temporary and staff-chosen backoffice password to be at least 12 characters long and include at least one letter and one number.
- **R11** — IF a temporary password remains unused for 72 hours after issuance, THEN THE SYSTEM SHALL expire it and require an admin to reissue a new temporary password before that account can complete first login.

## Non-goals

- Tenant self-service staff management, and cross-tenant/customer staff management, are explicitly out of scope — this PRD covers only the platform's own internal backoffice staff.
- Rich or granular role-based access control beyond the two-role (admin/member) model is out of scope for this PRD.
- Multi-factor authentication, single sign-on/social login, and self-service "forgot password" recovery are out of scope; a self-service credential-recovery capability is a candidate for a later PRD.
- Choosing the identity, credential, or storage technology that will implement these requirements is out of scope; see Downstream Handoff.

## Scope (In / Out)

### In scope

- Creating a backoffice staff account (email, first name, last name, role) with a forced, admin-only onboarding step that issues a temporary password (serves R1, SC1).
- Forcing a temporary-password holder to set a new password before any other backoffice action (serves R2, SC2).
- Viewing/listing all backoffice staff accounts, including each account's email, first name, last name, role, and active status (serves R3, SC3).
- Updating an existing backoffice staff account's first name, last name, email, or role (serves R4, SC3).
- Removing a backoffice staff account so it can no longer access the backoffice (serves R5).
- Enforcing exactly one role per account from {admin, member}, and restricting staff-management actions to admins (serves R6, R7).
- Preventing the backoffice staff roster from losing its last active admin (serves R8).
- Preventing duplicate active accounts for the same email identity (serves R9).
- A minimum password-strength rule for temporary and staff-chosen passwords, and an expiry/reissue rule for unused temporary passwords (serves R10, R11).

### Out of scope

- Any tenant/organization's own staff — those are managed under the platform's existing tenant-scoped staff concept, not this capability.
- Cross-tenant or customer-facing staff management of any kind.
- Any role beyond admin/member (e.g. an "owner" tier) for backoffice staff.
- MFA, SSO/social sign-in, and self-service password reset/recovery — candidates for a later PRD.
- The technology, storage, or credential-provisioning mechanism used to satisfy these requirements — see Downstream Handoff.

## Assumptions & Constraints

### Assumptions

- **A1** — Backoffice staff accounts are provisioned by an admin only; there is no self-registration path for backoffice staff. Affects R1, R7.
- **A2** — "Remove" (R5) is deactivation — a reversible action that preserves the account's history — accepted as the intended behaviour. Affects R5, R8.
- **A3** — An email address is a sufficient and stable identity key for uniqueness checks among **active** backoffice staff accounts (R9); no additional identity attributes are required to distinguish accounts. Once a backoffice staff account is removed (R5), its email address is available for reuse by a new active account — reuse is not blocked once the prior account is no longer active. Affects R5, R9.
- **A4** — The only password-reset path in scope for this PRD is the forced first-login change described in R2; no other self-service or admin-triggered reset path is assumed. Affects R2 (see also Non-goals).

### Constraints

- **C1** — Backoffice staff accounts are a platform-internal concept, distinct from any tenant organization's own staff; this PRD's requirements apply only to the former. Source: confirmed product scope. Affects R1–R11.
- **C2** — None beyond C1.

## Domain intent / ubiquitous language

- **Backoffice staff** — a person with an account that lets them sign into and act within the platform's internal backoffice (→ `glossary/backoffice-staff.md` once defined).
- **Backoffice admin** — a backoffice staff role authorized to manage the backoffice staff roster (→ `glossary/backoffice-admin.md` once defined).
- **Backoffice member** — a backoffice staff role that can use the backoffice but not manage other staff accounts (→ `glossary/backoffice-member.md` once defined).
- **Temporary password** — a system-generated credential issued when a backoffice staff account is created, valid only until it is replaced at first login (→ `glossary/temporary-password.md` once defined).
- **First-login password change** — the mandatory step in which a backoffice staff member replaces their temporary password before any other backoffice action is permitted (→ `glossary/first-login-password-change.md` once defined).

## Alternatives considered

- **Allowing backoffice staff to self-register** — not chosen because uncontrolled self-registration undermines the admin-managed roster this capability exists to provide; onboarding stays admin-initiated (R1).
- **A three-tier role model matching the tenant staff model (owner/admin/member)** — not chosen because backoffice staff do not need an "owner" tier; two roles (admin/member) are sufficient to separate roster-management authority from general backoffice use (R6, R7).
- **Blocking email reuse indefinitely once a backoffice staff account is removed** — not chosen; a departed staff member's email would otherwise stay unusable forever even though they no longer have an active account. R9's uniqueness rule applies only to active accounts, and A3 records that a removed account's email may be reused by a new active account.
- **Including self-service password reset in this PRD's scope** — not chosen because it introduces a separate identity-recovery concern with its own risk profile; deferred to a later PRD (see Non-goals).

## Open questions

None — all clarifications resolved at acceptance. The product owner accepted both recommended defaults: "remove" means deactivate (baked into R5, A2), and the password-strength/expiry thresholds are 12 characters minimum with one letter and one number, with a 72-hour unused-temporary-password expiry (baked into R10, R11).

## Downstream Handoff

- **ADR candidate** — backoffice staff data-modeling and implementation approach, kept distinct from the platform's tenant-scoped staff concept per this PRD's product-level boundary (see Constraint C1); serves R1, R6; downstream question: how should backoffice staff accounts be modeled and implemented while preserving that distinction?
- **ADR candidate** — credential provisioning and forced first-login password-change enforcement approach; serves R1, R2; downstream question: what mechanism issues, validates, and enforces replacement of a temporary credential?
- **Spec candidate** — backoffice staff-management surface and flows (create, view/list, update, remove); serves R1, R3, R4, R5; downstream question: what interaction flow and presentation let an admin perform each staff-management action?
- **Spec candidate** — admin-versus-member authorization model within the backoffice; serves R7, R8; downstream question: what mechanism enforces that only admin-role accounts can perform staff-management actions, including the last-admin safeguard?

## Realized by

- **Decisions**: — (pending)
- **Designs**: — (pending)
- **Terms**: — (pending)

## References

- [ADR-0022](../adrs/0022-expand-prd-required-sections.md) — the expanded PRD section set this PRD follows.
- Confirmed scope, personas, candidate success criteria, and candidate requirements synthesized from a product scoping conversation on backoffice staff management (no external ticket).

Author review checklist before requesting `Accepted` (confirmed true at acceptance):

- [x] Requirements are complete enough for downstream ADR/spec authors to proceed without guessing product intent.
- [x] Every requirement has a stable ID and is singular, testable, and observable.
- [x] Requirements and success criteria are measurable where relevant and technology-agnostic.
- [x] Success criteria use stable `SC#` IDs, have measurable user/business outcomes, and avoid internal implementation metrics.
- [x] Scope has explicit **In scope** and **Out of scope** lists; every requirement fits inside the stated scope.
- [x] Assumptions and constraints are explicit, falsifiable where relevant, and do not choose a design.
- [x] Downstream Handoff lists only ADR/spec candidates or design topics tied to `R#` / `SC#` IDs — no chosen technologies or task plans.
- [x] No architecture, API, schema, framework, storage, deployment, or task detail appears as a requirement.
- [x] Open questions are explicit; no `[NEEDS CLARIFICATION]` markers remain for acceptance.
- [x] Domain terms are linked to or nominated for the glossary, and downstream docs are linked under **Realized by**.
</content>
