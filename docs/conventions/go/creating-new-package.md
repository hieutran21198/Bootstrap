# Creating a new Go package

Before creating any new Go package, work through these steps. The outcome is either (a) you use one of the templates in [`templates/`](templates/), or (b) you hand-roll the package with a justification in the parent's `AGENTS.md`.

> **Scope**: any new Go package in `packages/`, `services/`, `tools/`, or `apps/`.
> **Status**: Active
> **Decided by**: [ADR-0001](../../adrs/0001-single-responsibility-go-packages.md)
> **Last reviewed**: 2026-06-24

## 1. Name the responsibility in one sentence

Write down what the package does, in one sentence. If you need more than one sentence — or two unrelated nouns — you're describing two packages. Go to step 5 (split or stop).

## 2. Pick the segment

Where does the package belong?

| Segment              | When                                                                |
| -------------------- | ------------------------------------------------------------------- |
| `packages/go/`       | Reusable shared library code — used by 2+ services or by tools.     |
| `services/<name>/`   | Code that lives inside a single deployable service.                 |
| `tools/generators/`  | A workspace CLI tool, compiled and installed in the dev shell.      |
| `apps/`              | UI app code.                                                        |

## 3. Classify the shape

| Shape                                     | Signals                                                                                     | Outcome                                                                  |
| ----------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **SRP-stateful**                          | Owns state. Has a lifecycle (start/stop, open/close). Wrapper, client, server, connection.  | Use [`templates/stateful.go.tmpl`](templates/stateful.go.tmpl).            |
| **SRP-stateless**                         | Pure functions over input. No setup. Parser, formatter, loader, codec, dialector.            | Use [`templates/stateless.go.tmpl`](templates/stateless.go.tmpl).          |
| **Service composition**                   | HTTP handlers + DB + auth + business logic. Multi-axis by design.                            | Hand-roll. Apply Clean Architecture (see [`services/portal/`](../../../services/portal/)). |
| **Looks like `util`/`common`/`helpers`**  | 2+ unrelated nouns describe it, OR the name is a generic catchall.                          | **STOP**. Split into focused packages. Re-run step 1 for each piece.     |

If you're unsure between SRP-stateful and SRP-stateless: stateful packages are *constructed* (`New(ctx, cfg)` once, then use the returned `*T`); stateless packages are *called directly* (`env.Parse(...)`, no instance with state).

## 4. Use the template (SRP cases)

If you landed on SRP-stateful or SRP-stateless:

```bash
# Pick a name and a target segment.
PKG=echox
TARGET=Echox
SEGMENT=packages/go/server

# Copy the template (an AI agent or you handles placeholder substitution).
mkdir -p "${SEGMENT}/${PKG}"
cp docs/conventions/go/templates/stateful.go.tmpl "${SEGMENT}/${PKG}/${PKG}.go"

# Fill in {{ .PackageName }}, {{ .TargetName }}, {{ .PackagePurpose }}, {{ .TargetPurpose }}.
# Full reference: docs/conventions/go/templates/README.md
$EDITOR "${SEGMENT}/${PKG}/${PKG}.go"

# Tidy and verify.
( cd "${SEGMENT}/${PKG}" && go mod tidy )
lint-go
```

## 5. Hand-roll (everything else)

If you landed on "Service composition" or "STOP/split":

- **Service composition** — write the package without a template. Apply the relevant architecture for the segment (Clean Architecture for `services/portal/`, etc.). The package's `AGENTS.md` (or the parent module's) must justify the shape — for example: *"This package is hand-rolled because it is a multi-axis service module; see `docs/conventions/go/creating-new-package.md` step 5."*
- **STOP/split** — go back to step 1 for each piece. Don't proceed until each piece passes step 3 cleanly.

Hand-rolled packages still go through code review. The reviewer's job is to confirm step 5 was the right step, not to apply the SRP-stateful contract.

## See also

- [Single-responsibility category](single-responsibility.md) — what counts as SRP, with examples.
- [templates/](templates/) — the actual template files + placeholder reference.
- [packages/go/AGENTS.md](../../../packages/go/AGENTS.md) — package-level governance (the shape the SRP-stateful template produces).
- [ADR-0001 — Adopt templates for single-responsibility Go packages](../../adrs/0001-single-responsibility-go-packages.md)
