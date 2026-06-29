# Database conventions

Workspace-wide rules for the relational database — the roles applications connect as, and the request context they bind so Row-Level Security can enforce tenant isolation. Each rule below is a standalone file; this README is the index.

> **Scope**: every service that connects to the workspace Postgres database (`services/**`) and the shared DB helpers in `packages/go/**` (`gormx`, `migrate`).
> **Status**: Active
> **Decided by**: [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md)
> **Last reviewed**: 2026-06-29

## Index

| #   | Document                                                     | One-liner                                                                                          |
| --- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1   | [Role and scope contract](role-and-scope-contract.md)       | Which role to connect as (`admin`/`writer`/`reader`) and which GUCs to bind (`app.scope`, `app.organization_id`). |

## See also

- [ADR-0008](../../adrs/0008-tenant-scoped-unit-of-work-rls.md) — the decision that established RLS as the tenant-isolation authority and the two named scopes.
- [`rls-patterns` skill](../../../tools/ai/skills/rls-patterns/SKILL.md) — the operational how-to for authoring policies and migrations against this contract.
- [Service architecture § Unit of Work](../go/service-architecture.md#unit-of-work) — the Go-side UoW / Read Store pattern that binds the scope.
- [Workspace conventions index](../README.md) — sibling topics.
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
