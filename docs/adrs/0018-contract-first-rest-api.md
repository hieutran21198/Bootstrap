# 0018. Contract-first REST API with OpenAPI and oapi-codegen

- **Status**: Accepted
- **Date**: 2026-07-04
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The portal service is approaching its HTTP delivery boundary. Today the CQRS split exists at the app layer in `services/portal/internal/app/{command,query}/`, with a query-only HTTP binary stub under `services/portal/cmd/http/query/`. The `delivery/http` boundary and the second, command-side HTTP binary are the intended shape this ADR enables. The shared Echo wrapper exposes the underlying `*echo.Echo` through `Echox.Echo()` specifically so delivery code can register routes on the configured server.

The API surface needs one durable source of truth. If handlers, request/response DTOs, generated docs, and client expectations are authored separately, they will drift. The workspace also already has a precedent for keeping external/provider-specific code at the boundary: [ADR-0006](0006-zitadel-identity-auth.md) chose ZITADEL, while the auth convention keeps provider SDK details behind `infra/zitadel` and exposes neutral app-facing ports.

This decision has a scope split:

- The **convention** for REST API authoring is workspace-global and belongs under `docs/conventions/api/` as a follow-up.
- The first **contract artifacts** are portal-local and will be created under `services/portal/api/`.

Neither `services/portal/api/` nor `services/portal/internal/delivery/` exists yet. This ADR establishes the intended layout; implementation will create those directories and the generated code that lives there.

## Decision

We will expose service APIs over **REST** and use a **contract-first OpenAPI workflow**: hand-author OpenAPI YAML as the source of truth, then generate Go delivery-boundary code from that contract with **oapi-codegen** using its Echo v4 server generator.

For the portal service, the proposed layout is:

- **Source of truth**: `services/portal/api/*.yaml`
- **Generated Go boundary code**: `services/portal/internal/delivery/http/{command,query}/`

The generated code is a derived artifact at the HTTP boundary. It mounts onto the shared Echo server via `Echox.Echo()` route registration and must not become an application or domain dependency. Application use cases remain behind the existing command/query app ports; delivery code translates between generated HTTP shapes and app-facing inputs/outputs.

The workspace-wide rule that says how to author, name, generate, and review these contracts will be written later as a global convention under `docs/conventions/api/`. This ADR records the decision only.

## Consequences

- **Positive**:
  - OpenAPI YAML becomes the single source of truth for HTTP shape; generated Go code, documentation, and future clients derive from the same contract instead of drifting from handler implementations.
  - REST keeps the transport browser-, proxy-, and documentation-friendly without introducing a protobuf/gRPC runtime or a second IDL into the service boundary.
  - `oapi-codegen` fits the existing server stack because it has a native Echo v4 server generator; generated route interfaces can be mounted on the `*echo.Echo` exposed by `packages/go/server/echox`.
  - Generated/provider-specific details stay at a boundary, matching the ZITADEL adapter precedent: inner `app` and `domain` packages do not depend on generated HTTP types.
  - The portal layout can mirror the physical CQRS split by placing generated command and query HTTP code under separate delivery packages.
- **Negative**:
  - Contributors must maintain hand-authored OpenAPI with the same care as code; invalid or stale YAML blocks generation and misleads consumers.
  - Generated code creates review noise and ownership questions unless the follow-up convention and CI wiring make regeneration deterministic.
  - Some Go shapes will be constrained by OpenAPI modeling and by the generator's choices; app-layer DTOs may need explicit translation instead of reusing generated types directly.
  - Contract-first work adds an up-front design step before a handler can be implemented.
- **Neutral**:
  - Implementation will create the net-new portal API contract directory (`services/portal/api/`) and delivery output directories (`services/portal/internal/delivery/http/{command,query}/`).
  - Follow-up: add a global `docs/conventions/api/` rule for contract naming, ownership, generation, review, and import boundaries.
  - Follow-up: add devenv/CI codegen wiring so generated Go is reproducible and checked.
  - Follow-up: build the first reference implementation that demonstrates the OpenAPI contract, generated Echo server code, and app-layer translation.
  - Follow-up: fix the stale ADR range in the root `AGENTS.md`; ADR numbering on disk already continues past the old range.
  - Open question: should portal use one `openapi.yaml`, or split contracts into `command.yaml` and `query.yaml` to mirror the two-binary CQRS layout?
  - Open question: what standard error-envelope shape and API versioning strategy should the global API convention require?

## Alternatives considered

- **gRPC/protobuf** — contract-first RPC with strong generated clients and server stubs. Rejected because the chosen service boundary is REST/HTTP+JSON: it is easier to expose to browsers, generic HTTP tooling, API gateways, and OpenAPI documentation without adding a protobuf toolchain and runtime to the portal boundary.
- **ogen** — contract-first OpenAPI code generation for Go. Rejected because it does not fit the existing Echo v4 server boundary as directly as `oapi-codegen`; adopting it would either bend the service around a different generated server shape or require extra adapter glue before route registration.
- **goa** — Go-centric API design/code workflow with generated transport code and OpenAPI output. Rejected because the contract would be derived from Go design/annotations rather than a hand-authored OpenAPI YAML artifact; that makes Go the source of truth, not the contract file.
- **swaggo** — generates OpenAPI/Swagger from comments and annotations in Go handlers. Rejected because it is code-first: the spec is derived after handlers exist, so it cannot serve as the source of truth for implementation and client expectations.

`oapi-codegen` wins for this workspace because it keeps a hand-authored OpenAPI contract as the source, generates Echo v4 server boundary code that matches the existing `echox` server, and lets generated details stay in `delivery/http` instead of leaking into `app` or `domain`.

## References

- [ADR-0003](0003-service-architecture.md) — service architecture and CQRS/hexagonal boundaries.
- [ADR-0006](0006-zitadel-identity-auth.md) — provider-specific integration kept behind an adapter boundary.
- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md) — precedent for keeping external SDK/provider details out of `app`, `domain`, and most `delivery` code.
- [`services/portal/AGENTS.md`](../../services/portal/AGENTS.md) — portal delivery layout, physical command/query split, and two HTTP binaries.
- [`packages/go/server/echox/echox.go`](../../packages/go/server/echox/echox.go) — `Echox.Echo()` exposes `*echo.Echo` for generated route registration.
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html) — contract format.
- [`oapi-codegen`](https://github.com/oapi-codegen/oapi-codegen) — chosen OpenAPI-to-Go generator with Echo server support.
- [`ogen`](https://github.com/ogen-go/ogen), [`goa`](https://goa.design/), and [`swaggo`](https://github.com/swaggo/swag) — generator alternatives considered.
