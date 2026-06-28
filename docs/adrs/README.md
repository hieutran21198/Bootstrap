# Architecture Decision Records

ADRs capture **decisions** - not designs, not specs, not status updates. An ADR explains why we chose X over Y, with enough context that a future contributor (or future-you) can revisit it.

## Template

[TEMPLATE.md](TEMPLATE.md) is a hybrid of two canonical ADR formats:

- **Structure** (`Context` / `Decision` / `Consequences` / `Alternatives considered` / `References`) follows Michael Nygard's [original ADR proposal](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (Cognitect, 2011).
- **Metadata header** (`Status`, `Date`, `Deciders`, `Supersedes`, `Superseded by`) follows the [MADR](https://github.com/adr/madr) (Markdown Any Decision Records) convention.

For a curated catalog of every ADR template variant and the reasoning behind each, see [joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record).

## Naming

```
docs/adr/NNNN-kebab-case-title.md
```

- `NNNN`: four-digit sequence, padded with zeros (`0001`, `0002`, ...).
- Title is short, decisive, and reads as a result, not a question. "use-go-workspaces" beats "should-we-use-go-workspaces".

## Lifecycle

ADRs are **append-only**. To change a decision:

1. Write a new ADR with a higher number.
2. Set `Status: Accepted` on the new one.
3. Set `Status: Superseded by ADR-NNNN` on the old one. Leave the body intact.

`Status` transitions:

- `Proposed` - under discussion in a PR
- `Accepted` - merged, in effect
- `Superseded by ADR-NNNN` - replaced
- `Deprecated` - no longer in effect, no replacement

## Writing a new ADR

```bash
NEXT=$(printf "%04d" $(( $(ls docs/adr | grep -E '^[0-9]{4}' | wc -l) + 1 )))
TITLE="my-decision-title"
cp docs/adr/TEMPLATE.md "docs/adr/${NEXT}-${TITLE}.md"
$EDITOR "docs/adr/${NEXT}-${TITLE}.md"
```

## Index

| #    | Title                                                                              | Status   |
| ---- | ---------------------------------------------------------------------------------- | -------- |
| 0001 | [Single responsibility for Go packages](0001-single-responsibility-go-packages.md) | Accepted |
| 0002 | [Workspace-wide Go code style rules](0002-go-code-style.md)                        | Accepted |
| 0003 | [DDD + CQRS + Hexagonal architecture for services](0003-service-architecture.md)   | Accepted |
| 0004 | [Typed aggregate IDs with UUIDv7](0004-typed-aggregate-ids-uuidv7.md)              | Accepted |
| 0005 | [Collection-style repositories](0005-collection-style-repositories.md)             | Accepted |
| 0006 | [Zitadel as the identity and auth provider](0006-zitadel-identity-auth.md)         | Proposed |
| 0007 | [Manage the developer environment with Nix + devenv](0007-nix-devenv-developer-environment.md) | Accepted |
| 0008 | [RLS tenant isolation with organization and system scopes](0008-tenant-scoped-unit-of-work-rls.md) | Accepted |
