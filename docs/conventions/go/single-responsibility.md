# Single-responsibility category

> **Scope**: a _category_ of Go packages, not all of them. A package is in this category if its responsibility can be named in one or two words.
> **Status**: Active
> **Decided by**: [ADR-0001](../../adrs/0001-single-responsibility-go-packages.md)
> **Last reviewed**: 2026-06-24

**What this is.** "Single-responsibility" (SRP) is a _category_ of Go packages in this workspace — those whose purpose can be stated in one sentence with one noun: `env` = environment variables; `echox` = Echo HTTP server; `gormx` = GORM wrapper. For packages in this category, the workspace provides ready-made templates at [`templates/`](templates/) that capture the canonical shape.

**It is not a universal rule.** Not every Go package in this workspace must be SRP. Service modules under [`services/`](../../../services/) are multi-axis by design (HTTP + DB + auth + business logic); `apps/` may host UI code that doesn't fit. For those cases, see [`creating-new-package.md`](creating-new-package.md) — step 5 (hand-roll) is a first-class outcome.

## How to recognize the category

✓ Examples from this workspace — in the SRP category:

```
packages/go/env/                # environment-variable loading           (stateless)
packages/go/server/echox/       # Echo HTTP server with timeouts + slog  (stateful)
packages/go/gormx/              # GORM wrapper                            (stateful)
packages/go/gormx/postgres/     # Postgres dialector                      (stateless)
packages/go/gormx/sqlite/       # SQLite dialector                        (stateless)
tools/generators/ws-tree/       # tree(1) wrapper                          (CLI tool)
```

Each name is one noun, one responsibility.

✗ Examples NOT in the SRP category — hand-roll instead:

```
services/portal/    # multi-axis service module (handlers + DB + auth + business logic)
```

✗ Examples that should NOT exist regardless of category — dumping grounds by name:

```
packages/go/util/      # "util" is not a responsibility
packages/go/common/    # ditto
packages/go/helpers/   # ditto
packages/go/misc/      # by definition, multi-responsibility
packages/go/shared/    # shared between what?
```

If you can describe the package using 2+ unrelated nouns (e.g. `authbilling/`), it is not in this category — split into focused packages or hand-roll. The workspace will not block you, but the reviewer will ask.

## Stateful vs stateless

The SRP category has two sub-shapes, each with its own template:

- **SRP-stateful** — the package owns state. It has a lifecycle (you call `New(ctx, cfg)` once and use the returned `*T`). Wrappers, clients, servers, connections, caches. Template: [`templates/stateful.go.tmpl`](templates/stateful.go.tmpl).
- **SRP-stateless** — the package is pure functions over input. No setup. Parsers, formatters, loaders, codecs, dialectors. Template: [`templates/stateless.go.tmpl`](templates/stateless.go.tmpl).

If you're unsure: stateful packages are _constructed_ and then _used_; stateless packages are _called directly_ (`env.Parse(...)`, `postgres.New(...)` where `New` returns a value, not an instance with lifecycle).

## What the category guarantees

When a package IS in this category, the workspace provides:

- **A text template** that produces the canonical shape via `{{ .XXX }}` placeholder substitution. See [`templates/README.md`](templates/README.md) for the placeholder reference.
- **A predictable contract**, for stateful packages: the **`1 Config / 1 target / 1 New / ctx-first / errs wrapped`** governance documented in [`packages/go/AGENTS.md`](../../../packages/go/AGENTS.md).
- **A predictable layout**: `<name>.go` (+ optional `<name>_test.go`), one file per concept.

These are the **output of choosing the template**, not a rule that gets applied to every Go file in the workspace.

## How to use this category

Start at [`creating-new-package.md`](creating-new-package.md) — the pre-creation decision tree. It classifies your new package, points at the right template (or to "hand-roll"), and lists the placeholders to fill.

## See also

- [Creating a new Go package](creating-new-package.md) — the workflow.
- [templates/](templates/) — the templates this category prescribes (`stateful.go.tmpl`, `stateless.go.tmpl`).
- [Go conventions index](README.md)
- [ADR-0001 — Adopt templates for single-responsibility Go packages](../../adrs/0001-single-responsibility-go-packages.md)
- [packages/go/AGENTS.md](../../../packages/go/AGENTS.md) — the package-level governance the SRP-stateful template produces.
- [Effective Go — Package names](https://go.dev/doc/effective_go#package-names)
- [Google Go Style Guide — Package design](https://google.github.io/styleguide/go/decisions#package-design)
