# Portal specifications

Design contracts for portal features and subsystems — the **how** of building something in this service. The **decision** to build it lives in [adrs/](../adrs/) (portal) or [`docs/adrs/`](../../../../docs/adrs/) (workspace); the rules that apply once it ships live in [`docs/conventions/`](../../../../docs/conventions/) (workspace-wide, never duplicated here).

> **Format, naming (`<feature>.md`, kebab-case, no numbering), and lifecycle are authoritative in the workspace track** — see [`docs/specs/README.md`](../../../../docs/specs/README.md). Heavy evidence patterns and status transitions are identical.

Start a new spec by copying [TEMPLATE.md](TEMPLATE.md). Cross-link: the spec's `Tracks` field points at the ADR (portal or workspace) that authorised the work.

## Index

| Spec | Status | Tracks |
| ---- | ------ | ------ |
| [database-schema.md](database-schema.md) | Implemented | [ADR-0003](../../../../docs/adrs/0003-service-architecture.md), [ADR-0008](../../../../docs/adrs/0008-tenant-scoped-unit-of-work-rls.md) |
