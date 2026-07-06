# 0009. Safe `system`-scope RLS: separate role, capability gate, read-only first

- **Status**: Accepted
- **Date**: 2026-06-29
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

> **Implementation note (2026-06-29):** Accepted, and the four-layer design (separate `system_reader` role + split policies + capability gate + read-side `DoSystemQuery`) was implemented immediately rather than deferred — the workspace opted to build the read-only `system` primitive up front. The "read-only first" constraint still holds: only `DoSystemQuery` exists; `DoSystemTransaction` (system writes) remains deferred to its own future ADR. The "separate runtime" rule also still holds: no `system_*` DSN is wired into the tenant-facing portal. See [`docs/specs/portal/system-scope-rls.md`](../../services/portal/docs/specs/system-scope-rls.md) for the build.

## Context

[ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) established RLS as the authority for tenant isolation with two named scopes — `organization` and `system` — bound transaction-locally. It named, but explicitly deferred, an open risk:

> "`system` scope is a sharp tool: a bug in a cross-tenant job (or the future back-office) runs against every tenant's rows at once. Authorization (who may bind `system`) must gate it at the application layer — RLS only enforces the data boundary, not who is allowed to widen it."

ADR-0008's planned implementation widens visibility with a **single policy** carrying an `OR` branch, bound to the **same** `writer`/`reader` roles the tenant-facing portal uses:

```text
current_setting('app.scope', true) = 'system' OR organization_id = current_setting('app.organization_id', true)
```

The consequence is that the *only* thing standing between the tenant-facing connection and every tenant's data is "did the application remember to gate who sets `app.scope = system`?" One missed gate, or one buggy code path on the `writer`/`reader` connection that sets that GUC, turns a tenant-facing connection into cross-tenant access — and RLS cannot help, because the policy itself permits it. Production post-mortems of multi-tenant breaches converge on exactly this shape: a new code path skips the tenant filter, authorization sits on the render/handler layer instead of the data layer, or the cross-tenant path reuses a `BYPASSRLS` "master key."

The `system` scope is greenfield — no `system`-scope code, no principal/identity layer, and no DI wiring for the UoW/Read Store exist yet (only the `organization` scope and a domain `staff.Role` enum). So this is a design decision to make *before* the first consumer, not a retrofit. The question this ADR answers: **how does the application safely decide who may widen RLS to `system`, and how is blast radius bounded — without weakening ADR-0008's core model?**

## Decision

**We will implement `system` scope as a capability-gated, read-only-first unit-of-work scope backed by a dedicated `system_reader` Postgres role with its own policy — not as an `OR` branch on the tenant-facing `writer`/`reader` roles.** This refines ADR-0008 (its core philosophy stands) and supersedes one concrete detail: that `writer`/`reader` serve both scopes via a single `OR` policy.

Four layers, none sufficient alone:

1. **A dedicated role.** Add `system_reader` — `NOBYPASSRLS`, **no** inheritance from `writer`/`reader`, **no** schema-wide grants, explicit `SELECT` only on tables opted into the system policy. The tenant-facing `writer`/`reader` roles get **no** `system` policy branch, so setting `app.scope = system` on a tenant connection matches no policy and **fails closed** (zero rows) instead of widening.

2. **Split policies by role.** Org-scoped tables carry two policies: an organization policy `TO writer, reader` (`app.scope = organization AND organization_id = current_setting('app.organization_id', true)`), and a system read policy `TO system_reader` (`app.scope = system AND organization_allowed(organization_id)`). Each table opts into the system policy explicitly.

3. **An app-layer capability gate.** `system` is a scope of the unit of work (ADR-0008), but *binding* it requires an unforgeable, typed capability that a caller must obtain first. This reconciles "scope is a property of the unit of work" with "authorize who may bind `system`": any caller may *choose* a scope, but the `system` entry point's type signature demands a `SystemReadCapability` that only an authorizer can mint.

   ```go
   // Application layer (services/portal/internal/app/...).
   type SystemPrincipal struct {
       Kind    SystemPrincipalKind // worker (operator added later)
       Subject string              // worker name / operator id
   }

   // Construct ONLY via AllOrganizations() or OnlyOrganizations(ids).
   type SystemTarget struct{ /* unexported */ }

   // Minted ONLY by SystemScopeAuthorizer; unexported fields.
   type SystemReadCapability struct{ /* unexported */ }

   type SystemScopeAuthorizer interface {
       AuthorizeSystemRead(
           ctx context.Context,
           principal SystemPrincipal,
           target SystemTarget,
           purpose string,
       ) (SystemReadCapability, error)
   }
   ```

   The capability carries its target, so a caller cannot authorize one target and bind another. Domain aggregates never learn about principals — this lives in the app layer.

4. **A read-side port only, first.** The read port gains exactly one method; the write side gains nothing.

   ```go
   type ReadStore interface {
       DoOrganizationQuery(ctx context.Context, id organization.ID, handler TransactionalReadStoreHandler) error
       DoSystemQuery(ctx context.Context, cap SystemReadCapability, handler TransactionalReadStoreHandler) error
   }
   // NOT added: DoSystemTransaction(...) — see "read-only first" below.
   ```

   `bindSystemRLS` (the binder, mirroring `bindOrganizationRLS`) sets, as the first statements of the transaction and all transaction-local (`set_config(..., true)`): `app.scope = 'system'`, an explicit org-allowlist GUC (`app.organization_allowlist`), and audit metadata (subject / purpose / capability id). The allowlist is taken from inside the capability.

**Org-allowlist reinforcer (fail-closed).** The capability is minted with either `AllOrganizations()` → `app.organization_allowlist = '*'`, or `OnlyOrganizations([ids])` → a validated UUIDv7 id list. The system policy **requires** the allowlist GUC; a **missing** allowlist must mean **zero rows**, never "all tenants." Targeting all tenants is an explicit `'*'`, never an implicit default.

**Read-only first.** We add `DoSystemQuery` and **defer** `DoSystemTransaction` until a concrete, justified cross-tenant write consumer exists. A future system write requires its own ADR: a distinct `SystemWriteCapability`, a `system_writer` role, per-table write policies with explicit `WITH CHECK`, audit, and a named consumer.

**Separate runtime — rule now, build later.** We will **not** wire a `system_*` DSN into the tenant-facing portal binary/deployment. The first real `system` consumer (the cross-tenant worker; later, a back-office service) runs as a separate command/deployment with its own `system_reader` DSN. Sharing the Go module is fine; sharing the running tenant-facing process is not. We state the rule now and build the separate runtime when the consumer arrives.

**Forbidden (anti-patterns this ADR bans):**

- No `system` policy branch on the tenant-facing `writer`/`reader` roles.
- No `admin` / superuser / `BYPASSRLS` DSN outside migrations.
- No `system_*` DSN in the tenant-facing portal binary or deployment.
- No generic `DoTransaction` / scope-less runtime DB accessor.
- No session-level `SET`; only transaction-local `set_config(..., true)`.
- No missing allowlist defaulting to all tenants — missing fails closed.
- No `system` writes without a separate accepted ADR.

## Consequences

- **Positive**:
  - Blast radius is materially smaller. With a dedicated role, a bug that sets `app.scope = system` on the tenant-facing connection fails closed (no applicable policy) instead of exposing every tenant. The hard boundary is the database, not "did we remember to gate it."
  - Auditability improves: `system` access is visible in `current_user`, connection metadata, and Postgres logs — not only in app-side GUC logging.
  - Least privilege by construction: `system_reader` is read-only, granted table-by-table, denied everywhere else by missing grants and missing policy.
  - The capability gate makes "who may widen to `system`" a typed, app-layer fact — a `DoSystemQuery` call simply cannot compile without an authorizer-minted capability.
  - The org-allowlist shrinks "all tenants" to "these N" for jobs that only need a subset, and fails closed when unset.
- **Negative**:
  - More moving parts than ADR-0008's single `OR` policy: a second role, a second policy per opted-in table, a capability type, and an authorizer. Each org-scoped table must now opt into the system policy deliberately.
  - Read-only-first means a genuine cross-tenant *write* job is not yet expressible — it must either loop per-tenant under `organization` scope or wait for the system-write ADR. This is intentional friction.
  - The authorizer is a real auth surface that must be implemented and tested (capability minting, target binding, audit) before the first `system` consumer ships.
- **Neutral**:
  - ADR-0008's core stands unchanged: RLS is the authority, `system` widens via RLS (never `BYPASSRLS`), scope is a property of the unit of work, GUCs are transaction-local, unbound fails closed, `admin` is migrations-only.
  - The first principal kind is `worker`; an `operator` kind, back-office RBAC, two-person approval, and time-bound capabilities are deferred to when a back-office UI or destructive system write exists.
  - `staff.Role` (`owner`/`admin`/`member`) remains orthogonal — it governs what an actor may do inside an org, not who may bind `system`.

## Alternatives considered

- **Keep ADR-0008's single `OR` policy on `writer`/`reader`.** Rejected: the only boundary is application discipline ("did we gate `app.scope = system`?"). One missed gate gives a tenant-facing role cross-tenant visibility, and the database offers no second line of defense — exactly the documented breach shape.
- **Use `admin` / `BYPASSRLS` for system jobs.** Rejected: violates ADR-0008's core safety property. A missing tenant filter becomes unrestricted database access; the most powerful actor would have the least guardrail.
- **Build full back-office RBAC + operator identity now.** Rejected as premature — no consumer exists. The minimal abstraction (typed `SystemPrincipal` + capability gate) keeps the door open; operator RBAC and two-person approval land with the back-office that needs them.
- **Add `DoSystemTransaction` alongside `DoSystemQuery` now.** Rejected: shipping a generic cross-tenant *write* primitive before a justified consumer is exactly the sharp tool ADR-0008 warned about. System writes earn their own ADR with `WITH CHECK` policies and a `system_writer` role.
- **Make the allowlist optional (unset = all tenants).** Rejected: an implicit "all tenants" default is fail-open. Missing allowlist must be zero rows; all-tenant access is the explicit `'*'` choice.

## References

- [ADR-0008](0008-tenant-scoped-unit-of-work-rls.md) — the two-scope RLS model this ADR refines; supersedes its single-`OR`-policy-on-`writer`/`reader` detail (the `system`-scope half).
- [ADR-0004](0004-typed-aggregate-ids-uuidv7.md) — UUIDv7 ids; the allowlist holds validated `organization.ID` values.
- [ADR-0006](0006-zitadel-identity-auth.md) — identity/auth provider; the future `operator` principal kind will relate to it.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) — the role + GUC convention this ADR extends with `system_reader` and `app.organization_allowlist`.
- [Portal database schema](../../services/portal/docs/specs/database-schema.md) — per-table tenant classification; each org-scoped table opts into the system read policy.
- `services/portal/internal/infra/postgres/readstore/readstore.go` — where `DoSystemQuery` + `bindSystemRLS` will live (read-side).
- `services/portal/internal/app/query/port.go` — the `ReadStore` port that gains `DoSystemQuery`.
- `packages/nix/core/services/postgres/default.nix` — provisions roles; gains the `system_reader` login role.
- `rls-patterns` skill — `tools/ai/skills/rls-patterns/SKILL.md` — policy authoring; will gain the `system_reader` policy pattern.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [`CREATE POLICY`](https://www.postgresql.org/docs/current/sql-createpolicy.html) · [`CREATE ROLE`](https://www.postgresql.org/docs/current/sql-createrole.html)
- [OWASP — Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — enforce authorization at the data layer, fail closed.
