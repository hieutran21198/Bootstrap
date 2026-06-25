# Go conventions

Workspace-wide rules for Go code. Each rule below is a standalone file; this README is the index.

> **Scope**: every `*.go` file in this workspace — `packages/go/**`, `services/**`, `tools/**`, `apps/**`.
> **Status**: Active
> **Decided by**: [ADR-0001](../../adrs/0001-single-responsibility-go-packages.md)
> **Last reviewed**: 2026-06-24

## Index

| #    | Document                                                          | One-liner                                                                |
| ---- | ----------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 1    | [Creating a new Go package](creating-new-package.md)              | Pre-creation decision tree: classify, then template or hand-roll.        |
| 2    | [Single-responsibility category](single-responsibility.md)        | What counts as SRP. Points at the templates that produce the shape.      |

Templates referenced by document 1: [`templates/`](templates/) (`stateful.go.tmpl`, `stateless.go.tmpl`).

## See also

- [packages/go/AGENTS.md](../../../packages/go/AGENTS.md) — package-level governance for the shared library (`1 Config / 1 target / 1 New / ctx-first`) is the shape the stateful template produces.
- [Workspace conventions index](../README.md) — sibling topics (when they appear).
- [Effective Go](https://go.dev/doc/effective_go)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
