# OIDC provider integration

> **Scope**: every service that authenticates callers against the workspace identity provider — the slim OIDC port in `services/*/internal/app/{command,query}/port.go`, the HTTP auth middleware under `services/*/internal/delivery/`, and the provider adapter under `services/*/internal/infra/<provider>/` (today `infra/zitadel/`).
> **Status**: Active
> **Decided by**: [ADR-0006](../../adrs/0006-zitadel-identity-auth.md)
> **Last reviewed**: 2026-07-01

**Rule.** Depend on a slim, provider-neutral OIDC interface declared beside the other ports in `app/command/port.go` and `app/query/port.go`; confine the identity provider's SDK (`zitadel-go`) and every OIDC/token specific to a single adapter in `infra/<provider>` (`infra/zitadel`) that implements it — `domain`, `app`, and `delivery` never import the SDK.

**Rationale.** [ADR-0006](../../adrs/0006-zitadel-identity-auth.md) chose ZITADEL but committed to *standards-based, reversible* integration and explicitly deferred "the exact token-validation strategy, middleware shape, and application-registration choices" to a convention. Reversibility only holds if provider types never leak past one adapter: the moment a `zitadel-go` type (`*oauth.IntrospectionContext`, the `pkg/http/middleware` interceptor, a `urn:zitadel:…` claim key) appears in `delivery` or `app`, swapping to Keycloak stops being "add one adapter" and becomes a cross-cutting rewrite. The app layer already owns its ports in `port.go` — `UnitOfWork` (write) and `ReadStore` (read); the OIDC port sits right beside them and `infra/zitadel` implements it exactly the way `infra/postgres/uow` implements `UnitOfWork` ([service-architecture.md § Unit of Work](../go/service-architecture.md#unit-of-work)). Keeping the interface *slim* — the few methods the app actually consumes — keeps the abstraction strong and the security-critical token-validation surface in one auditable place.

**Apply.**

- **The port is a slim interface in the existing `port.go`, not a new package.** Add it to `internal/app/command/port.go` (beside `UnitOfWork`) and `internal/app/query/port.go` (beside `ReadStore`). Do **not** create an `app/auth` package or a producer-side `ports/` package — the app layer defines the interface it consumes, right where its other ports live. Because CQRS is physical (two binaries, no shared app types across command/query — see [service-architecture.md § CQRS is physical](../go/service-architecture.md#cqrs-is-physical)), each side declares its own copy; the same concrete adapter satisfies both by structural typing.
- **Keep it slim.** Declare only what the app consumes — token in, neutral identity out:
  - `Authenticator` — `Authenticate(ctx, bearerToken string) (Principal, error)`, where `bearerToken` is the raw `Authorization` header value.
  - `Principal` is a small neutral value: `Subject` (IdP user id), `Email`, the IdP org id, `Roles`. **IdP-native identifiers only** — it does *not* carry the portal's `organization.ID`.
  - Neutral sentinel errors — `ErrUnauthenticated`, `ErrProviderUnavailable` — that `delivery` maps to HTTP status (401 / 503) without knowing the provider.
- **The adapter** (`internal/infra/zitadel/`) is the **only** package that imports `github.com/zitadel/zitadel-go/v3`. It returns a concrete `*zitadel.Authenticator` (accept interfaces, return concrete types), asserts `var _ command.Authenticator = (*Authenticator)(nil)` (and the query one), builds the authorizer once, calls `CheckAuthorization`, translates `*oauth.IntrospectionContext` → the neutral `Principal`, and translates provider errors → the neutral sentinels.
- **Token strategy is an adapter detail, behind the port.** Default to **offline JWT/JWKS** verification (`oauth.DefaultJWTAuthorization(resourceID)`): no per-request round-trip; it validates issuer + audience + expiry and caches JWKS from OIDC discovery. Use **introspection** (`oauth.WithIntrospection` + JWT-profile `IntrospectionAuthenticationJWTProfile`) only when you need up-to-the-second revocation, optionally short-TTL cached. Callers never see which is in use.
- **Delivery uses OUR middleware, not the SDK's.** A thin Echo middleware in `delivery/http` depends on the `Authenticator` port — never `zitadel-go/pkg/http/middleware`. It reads `Authorization`, calls `Authenticate`, stores the `Principal` in the request context; `ErrUnauthenticated → 401`, `ErrProviderUnavailable → 503`. Authorization (role checks) runs *after* authentication, off `Principal.Roles`.
- **Identity → tenant mapping stays out of the port and the adapter.** The portal binds RLS by its own `organization.ID` (a portal-DB UUIDv7), which is **not** the IdP org id ([role-and-scope-contract](../database/role-and-scope-contract.md)). Resolving `Principal.Subject` / IdP org → portal `organization.ID` + `staff.ID` is an application lookup designed in a service-local spec (`services/portal/docs/specs/`). Bootstrap subtlety for that spec: the lookup must run under a scope RLS admits — it cannot be an ordinary org-bound read *before* the org is known.
- **Config** — issuer URL, resource/client id, JWKS or key-file path — lives in `config/` (env-driven via [`packages/go/env`](../../../packages/go/env)) and is passed to the adapter constructor. No provider config in `app`/`domain`.
- **Reversibility check.** Swapping ZITADEL → Keycloak must touch **only** `internal/infra/<newprovider>/`, the constructor wiring in `cmd/http/*/main.go`, and `config/`. If a swap would force an edit in `app/`, `domain/`, or `delivery/`, the boundary has leaked — fix the port, not the caller.

**Examples.**

✓ Good:
```go
// internal/app/command/port.go — the slim OIDC port sits beside UnitOfWork.
package command

import "context"

type UnitOfWork interface {
	DoOrganizationTransaction(ctx context.Context, id organization.ID, handler TransactionalUnitOfWorkHandler) error
}

// Principal is the authenticated caller as the identity provider sees it —
// IdP-native identifiers only, never the portal's organization.ID.
type Principal struct {
	Subject       string   // IdP user id (ZITADEL `sub`)
	Email         string
	ProviderOrgID string   // IdP org id — NOT organization.ID
	Roles         []string
}

var (
	ErrUnauthenticated     = errors.New("command: unauthenticated")
	ErrProviderUnavailable = errors.New("command: identity provider unavailable")
)

// Authenticator verifies an OIDC bearer token. Slim on purpose: token in,
// neutral Principal out. Implemented by internal/infra/zitadel.
// app/query/port.go declares the identical pair for the read binary.
type Authenticator interface {
	Authenticate(ctx context.Context, bearerToken string) (Principal, error)
}
```

```go
// internal/infra/zitadel/authenticator.go — the ONLY package that imports zitadel-go.
package zitadel

import (
	"context"
	"errors"
	"fmt"

	"github.com/zitadel/zitadel-go/v3/pkg/authorization"
	"github.com/zitadel/zitadel-go/v3/pkg/authorization/oauth"
	"github.com/zitadel/zitadel-go/v3/pkg/zitadel"

	"bootstrap/services/portal/internal/app/command"
)

type Authenticator struct {
	z *authorization.Authorizer[*oauth.IntrospectionContext]
}

// New builds the offline-JWT authorizer (JWKS via OIDC discovery; aud = resourceID).
// Local stack: zitadel.New(issuer, zitadel.WithInsecure("8080")).
func New(ctx context.Context, issuer, resourceID string) (*Authenticator, error) {
	z, err := authorization.New(ctx, zitadel.New(issuer),
		oauth.DefaultJWTAuthorization(resourceID))
	if err != nil {
		return nil, fmt.Errorf("zitadel: init authorizer: %w", err)
	}
	return &Authenticator{z: z}, nil
}

func (a *Authenticator) Authenticate(ctx context.Context, bearer string) (command.Principal, error) {
	authCtx, err := a.z.CheckAuthorization(ctx, bearer)
	switch {
	case errors.Is(err, &authorization.UnauthorizedErr{}):
		return command.Principal{}, command.ErrUnauthenticated
	case errors.Is(err, &authorization.ServiceUnavailableErr{}):
		return command.Principal{}, command.ErrProviderUnavailable
	case err != nil:
		return command.Principal{}, fmt.Errorf("zitadel: check authorization: %w", err)
	}
	return command.Principal{
		Subject:       authCtx.UserID(),        // `sub`
		Email:         authCtx.Username,         // preferred_username; swap for an email claim if enabled
		ProviderOrgID: authCtx.OrganizationID(), // claim urn:zitadel:iam:user:resourceowner:id
		Roles:         rolesFrom(authCtx),
	}, nil
}

var _ command.Authenticator = (*Authenticator)(nil)
```

✗ Bad:
```go
// internal/delivery/http/command/middleware.go — WRONG.
// delivery imports zitadel-go and reaches for the provider's claim type directly.
// Swapping to Keycloak means rewriting every delivery binary, not adding one adapter.
import (
	"github.com/zitadel/zitadel-go/v3/pkg/authorization"
	"github.com/zitadel/zitadel-go/v3/pkg/authorization/oauth"
	zhttp "github.com/zitadel/zitadel-go/v3/pkg/http/middleware"
)

func authMiddleware(mw *zhttp.Interceptor[*oauth.IntrospectionContext]) echo.MiddlewareFunc {
	return echo.WrapMiddleware(mw.RequireAuthorization()) // provider bound to delivery
}

func handler(c echo.Context) error {
	authCtx := authorization.Context[*oauth.IntrospectionContext](c.Request().Context())
	orgID := authCtx.OrganizationID() // ← delivery depends on a zitadel-go type + claim
	// ...
}
```

**Enforcement.** Code review. The neutrality boundary is a review gate: **any import of `github.com/zitadel/zitadel-go/...` outside `internal/infra/<provider>/` is a defect**, and so is a `urn:zitadel:…` claim string anywhere but the adapter. The `var _ command.Authenticator = (*Authenticator)(nil)` assertion catches port drift at build time. A dedicated `oidc-patterns` skill and a `tools/validators` import-boundary check (fail CI when the SDK is imported outside the adapter) are planned follow-ups.

## See also

- [Auth conventions index](README.md)
- [ADR-0006](../../adrs/0006-zitadel-identity-auth.md) — the decision that adopted ZITADEL and licensed this convention.
- [Service architecture](../go/service-architecture.md) — the dependency rule and the `UnitOfWork`/`ReadStore` port precedent this specializes.
- [Database role and scope contract](../database/role-and-scope-contract.md) — RLS binds by `organization.ID`, the target of the identity → tenant mapping.
- [`deploy/local/` README](../../../deploy/local/README.md) — local ZITADEL endpoints (issuer, OIDC discovery, JWKS).
- [`zitadel-go` SDK](https://github.com/zitadel/zitadel-go) — `pkg/authorization`, `pkg/authorization/oauth`, `pkg/http/middleware` (`github.com/zitadel/zitadel-go/v3`).
