# Identity and Access

> **Status**: Accepted
> **Authors**: Minh Hieu Tran <hieu.tran21198@gmail.com>
> **Last reviewed**: 2026-07-01
> **Realized by**: ADR-0013 *(planned — two-population topology)*, `services/portal/docs/specs/identity-provisioning.md` *(planned)*, `docs/wiki/architecture/auth-topology.md` *(planned)*, `glossary/{actor,platform-staff,tenant-staff,tenant-customer,external-identity,domain-record}.md` *(planned)*

> **PRD rule — requirements only.** This document defines *who* the system must identify, *which* of them authenticate, and *which responsibilities* belong to the identity provider versus the application. It treats an external identity provider (ZITADEL, per [ADR-0006](../adrs/0006-zitadel-identity-auth.md)) as the chosen **direction** but does **not** specify its organizations, projects, applications, claims, tokens, or the application's storage/isolation mechanism — those are decisions (`adrs/`) and designs (`specs/`).

## Problem / Context

The system must identify and authorize several kinds of people, and it must also hold records for people who never sign in at all. An external identity provider (ZITADEL, per [ADR-0006](../adrs/0006-zitadel-identity-auth.md)) is the chosen direction for **authentication and external identity**. But authentication is not the same as domain ownership: the application still owns *who belongs to which tenant*, *what they may do in the business*, and the records of people (customers) who have no reason to log in.

This PRD defines the actor taxonomy, draws the line between "needs authentication" and "is only a domain record", separates the three human populations, states how tenants are isolated from one another, and splits responsibilities between the identity provider and the application. It deliberately leaves the identity-provider modeling and the association mechanics to later specs, architecture docs, and ADRs.

## Users & personas

The actor taxonomy this PRD is about:

- **Platform internal staff** — our employees who operate the platform (the [backoffice](backoffice-and-portal.md) audience). **Always authenticate.**
- **Tenant staff** — a tenant's own people who run the tenant's business (the [portal](backoffice-and-portal.md) audience). **Authenticate only when they need portal access**; a staff member who never uses the portal can exist as a domain record without an identity-provider account.
- **Tenant customer** — a tenant's customer (e.g. the person a booking is for). **A domain record**, not an authenticated actor, unless and until "customer login" is introduced as a product capability.

## Requirements

**Actor kinds & who authenticates:**

- **R1** — THE SYSTEM SHALL recognize three human actor kinds: platform internal staff, tenant staff, and tenant customers.
- **R2** — WHEN a platform internal staff member accesses the platform THE SYSTEM SHALL require authentication through the identity provider.
- **R3** — WHEN a tenant staff member needs portal access THE SYSTEM SHALL require authentication through the identity provider.
- **R4** — WHEN a tenant staff member has no need for portal access THE SYSTEM SHALL allow them to exist as a domain record without an identity-provider account.
- **R5** — THE SYSTEM SHALL represent tenant customers as domain records that do **not** require identity-provider accounts.
- **R6** — IF customer login is later introduced as a product capability THEN THE SYSTEM SHALL require authentication for customers **at that time** (out of scope for v1); the identity-association model (R14) SHALL stay general enough to attach an external identity to a customer later **without reshaping the model**.

**Distinguishing the populations:**

- **R7** — THE SYSTEM SHALL make platform internal staff distinguishable from tenant staff such that neither population is ever granted the other's capabilities.
- **R8** — THE SYSTEM SHALL distinguish tenant staff (who operate a tenant) from tenant customers (who are served by a tenant).

**Association & isolation:**

- **R9** — WHEN an authenticated identity signs in THE SYSTEM SHALL associate it with exactly one domain actor and, for tenant actors, the single tenant they belong to.
- **R10** — THE SYSTEM SHALL isolate each tenant's staff and customers so that no tenant can observe or affect another tenant's people or data.
- **R11** — IF an authenticated identity cannot be associated with a known actor and scope THEN THE SYSTEM SHALL grant no access (fail closed).

**Responsibility split — identity provider vs application:**

- **R12** — The identity provider SHALL own authentication and external identity: credentials, sign-in, and the external identity record for those who log in.
- **R13** — The application SHALL own the business domain — tenants, staff, customers, bookings, billing, and tenant boundaries — and SHALL remain the source of truth for who belongs to which tenant and what they may do.
- **R14** — THE SYSTEM SHALL keep the association between an external identity and its domain actor owned by the application (the identity provider authenticates; the application decides who that identity *is* in the business).
- **R15** — WHEN business permissions are evaluated THE SYSTEM SHALL derive them from roles the application owns, not solely from assertions supplied by the identity provider.

**Lifecycle:**

- **R16** — WHEN a tenant staff member's need for portal access ends THE SYSTEM SHALL be able to remove their access without deleting their domain record.
- **R17** — WHEN a person's access is withdrawn at the identity provider THE SYSTEM SHALL cease honoring their access by their next sign-in or token refresh, bounded by a short token lifetime (near-real-time revocation is out of scope for v1).

**Cross-population access:**

- **R18** — WHEN platform internal staff access a specific tenant's data THE SYSTEM SHALL confine it to read-only and record it (the v1 support decision; see [Backoffice and Portal](backoffice-and-portal.md) R5/R14).

## Non-goals

- **Identity-provider modeling** — ZITADEL organizations, projects, applications, claims, and token shape are design/decision concerns (spec/ADR), not requirements.
- **Token format, session mechanics, middleware, and the data-isolation mechanism** — design concerns.
- **The association mechanics** — *how* a tenant staff member's external identity is linked to their domain record (invite-time, first sign-in, or pre-provisioned) is a spec concern.
- **Customer login / any customer-facing authentication** — explicitly out of scope for v1 (see R5, R6).
- **Tenant SSO / social / enterprise IdP federation.**
- **One person belonging to multiple tenants** under a single identity — **decided: one tenant per identity in v1** (R9). The domain may still store the same person as separate records in different tenants, so multi-tenant sign-in is not foreclosed; it is simply not built in v1.
- **MFA, password, and session policy specifics** beyond what the identity provider offers.

## Domain intent / ubiquitous language

Candidate terms; define canonically in [`glossary/`](../glossary/) once stable, then link.

- **actor** — a human the system must identify or hold a record for.
- **platform internal staff** — our employees who operate the platform.
- **tenant staff** — a tenant's own people who operate the tenant via the portal.
- **tenant customer** — a tenant's customer; a domain record in v1.
- **external identity** — the identity the identity provider owns for someone who logs in.
- **domain record** — a person the application knows about who does **not** necessarily authenticate.
- **identity association** — the application-owned link between an external identity and a domain actor.
- **tenant boundary** — the isolation line around one tenant's people and data.

## Alternatives considered

- **Give every tenant customer an identity-provider account** — rejected: customers don't need to log in in v1; it adds identity surface and cost for no product value (contradicts R5).
- **Give every tenant staff an identity-provider account regardless of portal access** — rejected: staff who never use the portal are just domain records (contradicts R4).
- **Trust the identity provider's asserted tenant/roles as the authorization source** — rejected: the application owns business authority and the tenant association (contradicts R13–R15).
- **Model platform internal staff as members of each tenant** — rejected: makes cross-tenant reach implicit and breaks the internal-vs-tenant distinction (contradicts R7).

## Open questions

- _None open._

_Resolved (v1 scope):_ **one tenant per identity** (R9); **customer login out of v1** but the association model stays general (R6, R14); **cross-tenant support is read-only and recorded** (R18); **revocation propagates by next sign-in / token refresh** under a short token lifetime (R17).

> All `[NEEDS CLARIFICATION]` markers are resolved — this PRD has passed the `Draft → Accepted` gate.

## Realized by

- **Decisions**: ADR-0013 — two-population auth topology and the IdP↔application responsibility split *(planned)*.
- **Designs**: `services/portal/docs/specs/identity-provisioning.md` — how a tenant-staff external identity links to its domain record and how portal access is granted/revoked *(planned)*; a future backoffice service spec for platform-staff access *(planned)*.
- **Terms**: `glossary/{actor,platform-staff,tenant-staff,tenant-customer,external-identity,domain-record,identity-association,tenant-boundary}.md` *(planned)*.

## References

- [Backoffice and Portal PRD](backoffice-and-portal.md) — the two surfaces these actors use.
- [ADR-0006 — Zitadel as the identity and auth provider](../adrs/0006-zitadel-identity-auth.md) — the identity-provider direction this PRD presumes.
- [ADR-0008 — RLS tenant isolation](../adrs/0008-tenant-scoped-unit-of-work-rls.md), [ADR-0009 — safe system-scope RLS](../adrs/0009-safe-system-scope-rls.md), [ADR-0011 — org-root RLS hardening](../adrs/0011-org-root-rls-hardening.md) — the isolation decisions R9–R11 build on.
- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md) — the rule that keeps the chosen provider swappable.
