# 0006. Zitadel as the identity and auth provider

- **Status**: Proposed
- **Date**: 2026-06-26
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

[ADR-0003](0003-service-architecture.md) §1 placed a `zitadel` package under `services/*/internal/infra/` as the identity adapter, but never chose the identity provider itself. Every service in this workspace needs authentication (who is the caller) and authorization (what may the caller do). The alternatives are: build it ourselves, adopt a managed SaaS, or self-host an IAM platform.

Constraints that shaped the options:

- **Go-native footprint.** The workspace is a Go monorepo; a JVM-based IAM (Keycloak) adds a 2–8 GB RAM process and a second operational culture. Zitadel's API is a single Go binary (~200–500 MB RAM) backed by PostgreSQL — the same database the services already use. The Login v2 UI is a separate Next.js container, but it is a thin frontend, not a second operational culture.
- **Self-hostable for the scaffold.** The workspace is scaffold-stage and Nix/devenv-driven; a managed-only SaaS (Auth0) cannot run offline or in `devenv shell` without network and billing setup. Local dev must boot with `docker compose up`.
- **Multi-tenancy is first-class.** Services will host multiple organizations; the IAM must isolate tenants by design, not by convention.
- **Built-in UI.** A scaffold should not ship a hand-rolled login page or admin console. The IAM must provide both so services integrate via OIDC, not by rebuilding auth UX.
- **Standards-based integration.** Downstream Go services must validate tokens via OIDC/JWKS, not via a vendor-proprietary protocol, so the choice is reversible at the service boundary.

## Decision

We adopt **Zitadel** (self-hosted, PostgreSQL-backed) as the identity and auth provider for every service in this workspace. Local development boots Zitadel via docker compose in [`deploy/local/`](../../deploy/local/). Services integrate through OIDC using the official [`zitadel-go`](https://github.com/zitadel/zitadel-go) SDK.

Concretely:

1. **Provider.** Zitadel v4 (Go API binary, event-sourced state in PostgreSQL, separate Next.js Login v2 UI). CockroachDB is no longer supported upstream (v3+); PostgreSQL is the only database. We pin a stable tag in [`deploy/local/.env.example`](../../deploy/local/.env.example).

2. **Local scaffold.** `deploy/local/docker-compose.yaml` runs four core services: `postgres` (state), `zitadel-api` (IAM), `zitadel-login` (Login v2 UI, required by v4), and `proxy` (Traefik router that fronts the API and Login UI on a single port). Zitadel boots with `start-from-init --masterkey`, which creates the schema, the default instance, the admin user, and the `login-client` machine service account on first run. Redis and OpenTelemetry are upstream optional profiles (`--profile cache` / `--profile observability`) and are not included in the scaffold.

3. **Configuration surface.** All Zitadel config is env-driven via `deploy/local/.env.example` (copied to `.env`). The load-bearing variables: `ZITADEL_MASTERKEY` (32 chars, encrypts data at rest, immutable after init), `ZITADEL_DOMAIN` / `ZITADEL_EXTERNALPORT` / `ZITADEL_EXTERNALSECURE` (external URL shape), `ZITADEL_DATABASE_POSTGRES_DSN` (postgres connection), and `ZITADEL_FIRSTINSTANCE_*` (default org, admin user, login client).

4. **Service integration.** Each service's `infra/zitadel` adapter (per [ADR-0003](0003-service-architecture.md) §1) integrates via standards-based OIDC: the discovery document at `${ZITADEL_ISSUER}/.well-known/openid-configuration` and the JWKS at `${ZITADEL_ISSUER}/oauth/v2/keys`. The official `zitadel-go` SDK (`github.com/zitadel/zitadel-go/v3`) provides the `authentication` and `authorization` middleware. The exact token-validation strategy, middleware shape, and application-registration choices (OIDC PKCE for web apps, JWT profile for APIs, PAT for machine clients) are adapter design and live in a future spec or convention — this ADR decides only the provider and the standards-based integration contract.

5. **Endpoints (local).** Console: `http://localhost:8080/ui/console`. OIDC discovery: `http://localhost:8080/.well-known/openid-configuration`. JWKS: `http://localhost:8080/oauth/v2/keys`. REST API gateway: `http://localhost:8080/api`.

## Consequences

- **Positive**:
  - **Go-native, one culture.** Zitadel's API is a single Go process (~200–500 MB RAM) backed by PostgreSQL — the same database the services already use. No JVM, no Infinispan, no sticky sessions. The Login v2 UI is a separate Next.js container, but it is a thin frontend routed by Traefik, not a second operational culture.
  - **Multi-tenancy by design.** Zitadel's Organizations are first-class isolated tenants with custom branding, IdPs, and delegated admin — not realm-per-tenant convention. Services inherit tenant isolation from the IAM rather than reinventing it.
  - **Built-in Login UI and Admin Console.** The scaffold ships auth UX without writing it. Services redirect to Zitadel for login and consume the resulting OIDC session; the console manages users/projects/roles without a custom admin app.
  - **Standards-based, reversible.** OIDC + JWKS is the integration contract. A service that validates OIDC tokens today can point at any compliant IAM tomorrow; the choice is reversible at the service boundary.
  - **Event-sourced audit trail.** Every identity change is an immutable event, which gives auditability a solid foundation without a separate audit pipeline. Compliance certification (SOC 2, ISO 27001) is still separate work; the event log is the substrate, not the certification.
  - **Local dev boots offline.** `docker compose up` in `deploy/local/` brings up a working IAM with admin user and console; no SaaS signup or network dependency.
- **Negative**:
  - **PostgreSQL-only.** v3+ dropped CockroachDB. PostgreSQL is mainstream, but the IAM is now structurally tied to one database engine. A future migration away from PostgreSQL would be non-trivial.
  - **Younger than Keycloak.** Zitadel (2019) has a smaller community and fewer certified compliance regimes than Keycloak (2014). No HIPAA, ISO 27018, or FedRAMP — only SOC 2 Type II and ISO 27001. If those certifications become required, this decision must be revisited.
  - **Event-sourcing learning curve.** Debugging requires reading the event log, not a row in a users table. Operators new to event sourcing will need to learn the model.
  - **Major-version migration risk.** v2→v3 required schema work; future major versions may too. The IAM must be upgraded in CI before production, not blindly.
  - **Feature gaps vs Auth0.** No push MFA, no bot detection, no adaptive MFA, no fine-grained Zanzibar-style FGA. Partial ABAC. If advanced risk-based auth becomes a product need, this decision must be revisited.
- **Neutral**:
  - **Fills the `infra/zitadel` slot reserved by [ADR-0003](0003-service-architecture.md) §1.** The directory layout already anticipated an identity adapter; this ADR names the provider and the integration contract that the adapter implements.
  - **`deploy/local/` becomes the local infra home.** The scaffold previously held only `.gitkeep`; this ADR establishes `deploy/local/` as the canonical location for local docker-compose infrastructure, extensible to future services (e.g., a local postgres for the portal service itself).
  - **`zitadel-go` SDK is the integration library.** Services depend on `github.com/zitadel/zitadel-go/v3` for middleware; the SDK is versioned independently of the Zitadel server, so server upgrades and SDK upgrades are decoupled.
  - **Four-service local stack.** The compose runs postgres, zitadel-api, zitadel-login, and Traefik — matching the upstream v4 default. The Login v2 UI is a separate Next.js container (not embedded in the API binary), routed by Traefik. This is more moving parts than a single binary, but each part is a standard container with one job.

## Alternatives considered

- **Keycloak** — the most feature-complete OSS IAM with deep SAML/LDAP adapters. Rejected because it is Java/Quarkus (2–8 GB RAM, JVM operational culture in a Go workspace), its multi-tenancy is realm-per-tenant convention rather than first-class Organizations, and its footprint is disproportionate for a scaffold that boots in `devenv shell`.
- **Auth0** — excellent DX and managed SaaS. Rejected because it is managed-only (cannot boot offline in `devenv shell`), post-Okta pricing has climbed sharply, and it does not fit a self-hosted scaffold that must run without network or billing setup.
- **Ory (Hydra + Kratos + Keto)** — headless, Go-based, OIDC-certified. Rejected because it ships no UI: the scaffold would have to build the login page and admin console, which is exactly the work an IAM should remove. Best for teams that already own the user database; we do not.
- **Self-hosted custom auth** — full control. Rejected because re-implementing auth, MFA, session management, audit logs, and compliance is a known anti-pattern; the workspace is not in the identity business.

## References

- [ADR-0003](0003-service-architecture.md) §1 — reserved the `infra/zitadel` adapter slot this ADR fills.
- [`deploy/local/docker-compose.yaml`](../../deploy/local/docker-compose.yaml) — the local scaffold this ADR establishes.
- [`deploy/local/.env.example`](../../deploy/local/.env.example) — configuration surface for the local scaffold.
- [Zitadel docs](https://zitadel.com/docs) — official documentation.
- [Zitadel docker compose guide](https://zitadel.com/docs/self-hosting/deploy/compose) — upstream compose reference.
- [`zitadel-go` SDK](https://github.com/zitadel/zitadel-go) — official Go integration library (`github.com/zitadel/zitadel-go/v3`).
- [Zitadel OIDC endpoints](https://github.com/zitadel/zitadel/blob/main/apps/docs/content/apis/openidoauth/endpoints.mdx) — discovery, JWKS, token, userinfo.
- [CockroachDB deprecation advisory (A10015)](https://github.com/zitadel/zitadel/blob/main/apps/docs/content/support/advisory/a10015.mdx) — PostgreSQL-only from v3+.
