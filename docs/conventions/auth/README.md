# Auth conventions

Workspace-wide rules for how services authenticate callers and integrate with the identity provider. Each rule below is a standalone file; this README is the index.

> **Scope**: every service that authenticates callers against the workspace identity provider — the slim OIDC port in `services/*/internal/app/{command,query}/port.go`, the auth middleware in `services/*/internal/delivery/`, and the provider adapter in `services/*/internal/infra/<provider>/`.
> **Status**: Active
> **Decided by**: [ADR-0006](../../adrs/0006-zitadel-identity-auth.md)
> **Last reviewed**: 2026-07-01

## Index

| #   | Document                                                  | One-liner                                                                                              |
| --- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| 1   | [OIDC provider integration](oidc-provider-integration.md) | Slim provider-neutral OIDC port in `app/{command,query}/port.go`; the `zitadel-go` SDK confined to `infra/zitadel`. |

## See also

- [Workspace conventions index](../README.md) — sibling topics.
- [ADR-0006](../../adrs/0006-zitadel-identity-auth.md) — ZITADEL as the identity and auth provider.
- [Service architecture](../go/service-architecture.md) — the layer/dependency rules these conventions specialize.
