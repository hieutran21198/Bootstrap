# 0001. Adopt templates for single-responsibility Go packages

- **Status**: Accepted
- **Date**: 2026-06-24
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

The bootstrap workspace is a multi-module Go monorepo: [`packages/go/`](../../packages/go/) (shared library), [`services/portal/`](../../services/portal/) (the first service), [`tools/`](../../tools/) (workspace generators), and [`apps/`](../../apps/) (UI scaffolds). The shared library already encodes a strong per-package contract in [`packages/go/AGENTS.md`](../../packages/go/AGENTS.md) — **one `Config`, one target struct, one `New` constructor, ctx-first, errors wrapped** — that presumes a single-responsibility (SRP) package design.

The first instinct was to elevate SRP to a workspace-wide universal rule: every Go package MUST be single-responsibility. That framing is wrong in two ways:

1. **It doesn't fit all packages.** [`packages/go/env/`](../../packages/go/env/) is pure functions with no `Config` and no constructor — the SRP-stateful contract doesn't apply. Service modules under [`services/`](../../services/) are multi-axis by nature (HTTP + DB + auth + business logic). Forcing the same shape on every package is too rigid.
2. **It treats SRP as enforcement when the valuable thing is the *shape*.** A contributor who wants to write a wrapper, client, or server should be handed the canonical scaffold — not asked to recall a rule from memory and replicate it.

The workspace already provisions [`docs/conventions/`](../conventions/) (via `workspace.mandatoryFolders` in [`devenv.nix`](../../devenv.nix)) as the home for standing rules. It needs SRP-shaped templates more than it needs an SRP rule.

## Decision

We adopt **text templates for the single-responsibility category of Go packages**, not a universal SRP rule.

1. **The SRP category is opt-in.** A package is in the category if its responsibility can be named in one or two words. Wrappers, clients, servers, parsers, formatters, codecs qualify; service composition modules do not.
2. **For packages in the category**, the workspace provides text templates at [`docs/conventions/go/templates/`](../conventions/go/templates/):
   - [`stateful.go.tmpl`](../conventions/go/templates/stateful.go.tmpl) — for packages owning state (`Config` + target struct + `New(ctx, cfg) (*T, error)`).
   - [`stateless.go.tmpl`](../conventions/go/templates/stateless.go.tmpl) — for pure-function packages like [`env/`](../../packages/go/env/).
   Templates use `{{ .XXXName }}` placeholders. AI agents and humans substitute them directly — no CLI binary, no build step.
3. **For packages NOT in the category**, the contributor hand-rolls the shape and justifies the design in the package's `AGENTS.md` (or the parent module's).
4. **The pre-creation workflow** at [`docs/conventions/go/creating-new-package.md`](../conventions/go/creating-new-package.md) is the entry point. It classifies the package, points at the right template, and lists the placeholders to fill in.
5. **The existing [`packages/go/AGENTS.md`](../../packages/go/AGENTS.md) governance** is reframed: it documents *the shape the SRP-stateful template produces*, not a rule applied to every package in the module.

## Consequences

- **Positive**:
  - SRP is right-sized: applied where it fits, optional where it doesn't.
  - Templates are concrete and copyable. AI agents substitute placeholders directly; humans `cp` + find-and-replace. No tool to install, version, or wrap via Nix.
  - The "right way" to create a new package is now a tool you reach for, not a rule you have to recall.
  - [`packages/go/env/`](../../packages/go/env/) no longer needs an "exception" — it's an SRP-stateless package matching the stateless template's shape.
- **Negative**:
  - Contributors must judge the category before creating; misclassification is possible.
  - Templates require maintenance — if the governance shape changes, templates need updates in lockstep.
  - Hand-rolled packages still need code review for sanity; no automated catch on shape.
- **Neutral**:
  - Aligns with [Effective Go](https://go.dev/doc/effective_go#package-names) and [Google's Go style guide](https://google.github.io/styleguide/go/decisions#package-design) — both treat package design as a heuristic, not a hard contract.
  - Establishes the [`docs/conventions/go/templates/`](../conventions/go/templates/) precedent. Future topics (Nix module shape, commit messages) may follow the same template-driven pattern.

## Alternatives considered

- **Universal SRP rule** (the previous draft of this ADR). Rejected as documented in Context: too rigid, treats SRP as enforcement rather than tooling, and doesn't accommodate packages like `env/` or service modules.
- **Go CLI binary generator** (e.g. `tools/generators/go-pkg/`). Rejected for now in favour of plain text templates. CLI adds build/wrap/version overhead; the text template is read directly by the AI agent or contributor. A CLI wrapper can be added later if friction warrants — the template format is forward-compatible.
- **Custom linter for SRP** (banning `util`/`common`/`helpers` package names). Rejected as a primary mechanism — SRP is a design judgment, not a syntactic check. Naming heuristics may be added as a tactical `revive` rule later if review fatigue justifies it.

## References

- [`docs/conventions/go/creating-new-package.md`](../conventions/go/creating-new-package.md) — the pre-creation workflow this ADR establishes.
- [`docs/conventions/go/single-responsibility.md`](../conventions/go/single-responsibility.md) — what counts as the SRP category, with examples.
- [`docs/conventions/go/templates/`](../conventions/go/templates/) — the templates this ADR introduces.
- [`packages/go/AGENTS.md`](../../packages/go/AGENTS.md) — the governance the SRP-stateful template produces.
- [Effective Go — Package names](https://go.dev/doc/effective_go#package-names)
- [Google Go Style Guide — Package design](https://google.github.io/styleguide/go/decisions#package-design)
- [Dave Cheney, *Practical Go: Real world advice for writing maintainable Go programs* — Package design](https://dave.cheney.net/practical-go/presentations/qcon-china.html#_package_design)
