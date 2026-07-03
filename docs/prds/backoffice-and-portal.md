# Backoffice and Portal

> **Status**: Accepted
> **Authors**: Minh Hieu Tran <hieu.tran21198@gmail.com>
> **Last reviewed**: 2026-07-01
> **Realized by**: ADR-0013 *(planned — two-population topology)*, `docs/architecture/system-overview.md` + `docs/architecture/auth-topology.md` *(planned)*, portal & backoffice service specs *(planned)*

> **PRD rule — requirements only.** This document defines the **product boundary** between the two operational surfaces and what each is for. It names no service topology, deployment shape, framework, or storage mechanism — those are decisions (`adrs/`) and designs (`specs/`).

## Problem / Context

The platform has two distinct operational surfaces, serving two different audiences with two different goals:

- **Backoffice** — used by **platform internal staff** to operate, support, and manage the SaaS platform *across all tenants*.
- **Portal** — used by a **tenant's own people** (owners, admins, staff) to operate *their own tenant's business* (its customers, bookings, and billing).

These must not blur. A capability, convenience, or defect in one surface must never become reach into the other: platform operations and tenant operations are separate concerns with separate blast radii. This PRD fixes the boundary — who each surface is for, which capabilities belong to each, what stays strictly separate, what is genuinely shared, and what is deliberately out of scope for the first version. It intentionally defers *how people are identified and authorized* to the companion PRD, [Identity and Access](identity-and-access.md).

## Users & personas

**Backoffice (platform-level, cross-tenant):**

- **Platform operator / support** — our employee who runs day-to-day platform operations and assists tenants.
- **Platform admin** — our employee who manages internal staff, platform-wide settings, and tenant lifecycle.

**Portal (tenant-level, single-tenant):**

- **Tenant owner** — the person who brings a tenant onto the platform and administers it.
- **Tenant admin** — manages people and settings within one tenant.
- **Tenant staff / member** — runs the tenant's day-to-day business (customers, bookings) within one tenant.

**Not a user of either surface in v1:**

- **Tenant customer** — the tenant's own customer (e.g. a person a booking is for). In v1 a customer is a **domain record managed by tenant staff**, not a person who signs in. See [Identity and Access](identity-and-access.md).

## Requirements

**Backoffice — platform operations:**

- **R1** — WHEN platform staff onboard a new tenant THE SYSTEM SHALL establish that tenant and its first administrator as a deliberate act.
- **R2** — THE SYSTEM SHALL let platform staff suspend, reactivate, and offboard a tenant.
- **R3** — THE SYSTEM SHALL let platform staff view platform-wide operational status and health across tenants.
- **R4** — THE SYSTEM SHALL let platform admins manage internal staff and their access to the backoffice.
- **R5** — WHEN platform staff must assist a specific tenant THE SYSTEM SHALL permit **read-only** access to that one tenant's data, and only under a recorded reason (identity + enforcement mechanics deferred to [Identity and Access](identity-and-access.md)).

**Portal — tenant operations:**

- **R6** — THE SYSTEM SHALL let a tenant owner set up and administer their own tenant.
- **R7** — THE SYSTEM SHALL let tenant admins manage the tenant's own staff (add, assign role, deactivate) within that tenant.
- **R8** — THE SYSTEM SHALL let tenant staff manage the tenant's own customers as domain records.
- **R9** — THE SYSTEM SHALL let tenant staff manage the tenant's bookings.
- **R10** — THE SYSTEM SHALL let tenant admins configure tenant-scoped settings.

**Separation — the boundary:**

- **R11** — WHEN a portal user acts THE SYSTEM SHALL confine them to their own tenant; they SHALL never reach another tenant nor any platform operation.
- **R12** — THE SYSTEM SHALL treat platform staff as operators of the platform, not as default participants in any tenant's business (e.g. they do not appear as a tenant's staff or transact its bookings by default).
- **R13** — THE SYSTEM SHALL keep the backoffice and portal as separable surfaces such that being a user of one does not implicitly make a person a user of the other.
- **R14** — WHEN platform staff exercise cross-tenant access (R5) THE SYSTEM SHALL confine it to read-only and record who accessed which tenant, when, and why.

**Shared — true across both surfaces:**

- **R15** — THE SYSTEM SHALL require authenticated access to both surfaces (identity model deferred to [Identity and Access](identity-and-access.md)).
- **R16** — IF the acting scope (the platform, or a specific tenant) cannot be established THEN THE SYSTEM SHALL grant no access (fail closed).
- **R17** — THE SYSTEM SHALL present each actor only the capabilities appropriate to their role on that surface.
- **R18** — THE SYSTEM SHALL record every internal cross-tenant access (who, what, when, why — per R14) and every consequential state-changing action on both surfaces; routine reads need not be audited in v1.

## Non-goals

- **Billing of any kind** — both platform-billing-of-tenants and tenant-billing-of-customers are deferred to a dedicated future **Billing** PRD. v1 covers tenants, staff, customers, and bookings only.
- **Tenant customer self-service** (a customer-facing surface / login) — customers are domain records in v1; a customer surface is a separate future capability.
- **Public marketing site, sign-up funnel, or tenant self-serve registration flow** — v1 onboards tenants via backoffice only (R1); tenant self-signup is a later capability.
- **Cross-tenant *write* by platform staff** — support access is read-only in v1 (R5, R14); any break-glass write is a later decision (ADR).
- **Reseller / partner / tenant-of-tenant hierarchies.**
- **Fine-grained permission matrices** beyond coarse roles (owner / admin / staff on portal; operator / admin on backoffice).
- **Service topology, deployment, UI/UX, and storage** — all design/decision concerns for specs and ADRs.

## Domain intent / ubiquitous language

Candidate terms; define canonically in [`glossary/`](../glossary/) once stable, then link.

- **backoffice** — the platform-level operational surface used by internal staff, across tenants.
- **portal** — the tenant-level operational surface used by a tenant's own people, within one tenant.
- **platform staff / internal staff** — our employees who operate the platform (→ [Identity and Access](identity-and-access.md)).
- **tenant** — an isolated customer organization on the platform.
- **tenant staff** — a tenant's own people who operate the tenant via the portal.
- **tenant customer** — a tenant's customer, a domain record in v1.
- **booking** — a unit of the tenant's business managed in the portal.
- **platform billing vs tenant billing** — the platform charging tenants vs a tenant charging its customers (two different payer/payee relationships); both deferred to a future Billing PRD.
- **cross-tenant access** — platform staff accessing one specific tenant, deliberately and on the record.

## Alternatives considered

- **One unified console distinguished only by role flags** — rejected: blurs the platform/tenant boundary so a single role mistake could grant cross-surface reach (violates R11–R13).
- **Put tenant-support tools inside the portal for operators** — rejected: operators would need portal access into tenants, making cross-tenant reach implicit rather than deliberate and recorded (violates R12/R14).

## Open questions

- _None open._

_Resolved (v1 scope):_ billing is **deferred to a future Billing PRD** (out of scope); cross-tenant support **is** in v1 but **read-only and recorded** (R5, R14); booking management is **portal-only** — backoffice may only *view* bookings under read-only support access; tenant onboarding is **backoffice-only** (self-signup is a later capability); audit covers **cross-tenant access + consequential writes** (R14, R18).

> All `[NEEDS CLARIFICATION]` markers are resolved — this PRD has passed the `Draft → Accepted` gate.

## Realized by

- **Decisions**: ADR-0013 — two-population auth topology *(planned)*.
- **Designs**: portal service spec(s) and a future backoffice service spec *(planned)*.
- **Terms**: `glossary/{backoffice,portal,tenant,booking}.md` *(planned)*.

## References

- [Identity and Access PRD](identity-and-access.md) — the companion PRD; who these users are and how they are identified.
- [ADR-0003 — DDD + CQRS + Hexagonal architecture for services](../adrs/0003-service-architecture.md) — the service shape both surfaces are built on.
- [ADR-0006 — Zitadel as the identity and auth provider](../adrs/0006-zitadel-identity-auth.md) — context both surfaces presume.
- [ADR-0008 — RLS tenant isolation](../adrs/0008-tenant-scoped-unit-of-work-rls.md), [ADR-0009 — safe system-scope RLS](../adrs/0009-safe-system-scope-rls.md) — the isolation decisions R11–R14 build on.
