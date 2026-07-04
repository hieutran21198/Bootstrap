# API conventions

Workspace-wide rules for how services author REST API contracts and generate HTTP delivery code. Each rule below is a standalone file; this README is the index.

> **Scope**: every REST API contract under `services/*/api/*.yaml`, generated Go HTTP delivery code under `services/*/internal/delivery/http/...`, and hand-written delivery adapters that mount generated routes.
> **Status**: Active
> **Decided by**: [ADR-0018](../../adrs/0018-contract-first-rest-api.md)
> **Last reviewed**: 2026-07-04

## Index

| #   | Document                                                  | One-liner                                                                                                                                        |
| --- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | [Contract-first OpenAPI](contract-first-openapi.md)       | Hand-authored OpenAPI is the REST API source of truth; Go delivery code is generated with `oapi-codegen` (Echo v4) at `internal/delivery/http/...`. |

## See also

- [Workspace conventions index](../README.md) — sibling topics.
- [ADR-0018](../../adrs/0018-contract-first-rest-api.md) — contract-first REST with OpenAPI and `oapi-codegen`.
- [OIDC provider integration](../auth/oidc-provider-integration.md) — boundary precedent for keeping generated/provider details out of inner layers.
