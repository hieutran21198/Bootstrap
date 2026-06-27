# 0002. Adopt workspace-wide Go code style rules

- **Status**: Accepted
- **Date**: 2026-06-26
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

[ADR-0001](0001-single-responsibility-go-packages.md) covers package SHAPE for the single-responsibility category. It does not cover **per-file Go style** — file naming, doc comments, error handling, import grouping, interface placement. Those gaps surfaced during the first service build (portal) as concrete defects:

- A repository file named `organization_repo.go` lived inside `package repo`, creating a filesystem stutter that mirrors Go's anti-stutter idiom against type-level names (`repo.OrganizationRepo`). The smell wasn't caught by lint; it surfaced during code review.
- Exported types declared without doc comments slipped through review until `revive`'s `exported` rule flagged them after the fact — only because the lint runner happened to be invoked at that point.
- Error-handling style varied between packages: some files used `fmt.Errorf` with `%s`, others with `%w`; some callers used `==` comparison, others `strings.Contains(err.Error(), "...")`. Inconsistent surface for `errors.Is` / `errors.As`.
- A premature draft had a separate `internal/ports/` package collecting all interface declarations — fixed at review time, but with no written rule a contributor could point at, the design pressure to re-introduce it kept resurfacing.

These are stable per-file decisions that should not be re-litigated per service or per package. They need to be written down once, in one place, with concrete `✓ Good / ✗ Bad` examples drawn from the actual workspace.

## Decision

We adopt the rules documented in [`docs/conventions/go/code-style.md`](../conventions/go/code-style.md). They apply to every `*.go` file in this workspace (`packages/go/**`, `services/**`, `tools/**`, `apps/**`):

1. **File naming — no package-name stutter.** A file in `package X` is named for its concept, not `<concept>_X.go`. The package name already qualifies the type at call sites; the filename should not repeat it.
2. **Doc comments on every exported identifier.** Each comment begins with the identifier's name (`// UnitOfWork is ...`). `revive`'s `exported` rule enforces this.
3. **Error handling.** Sentinel errors via `errors.New("<pkg>: <reason>")`; wrap with `%w`; compare with `errors.Is` / `errors.As`. Never string-match. `errorlint` enforces.
4. **Import grouping.** Three blocks separated by blank lines: stdlib → third-party → local (`bootstrap/`). `goimports -local bootstrap/` is the project's formatter.
5. **Interface placement — at the consumer.** Define interfaces in the package that uses them; rely on Go's structural typing for implicit satisfaction. No separate `ports/` package whose only purpose is to hold interface declarations.

Each rule in the convention has a `Rule / Rationale / Apply / Examples (✓ Good / ✗ Bad) / Enforcement` block drawn from real workspace code (e.g., the `uow.go` / `organization.go` / `port.go` files in the portal service).

## Consequences

- **Positive**:
  - Skill authors and custom-lint authors have one place to read for rule definitions plus concrete artifacts to test against.
  - `revive` and `errorlint` already enforce rules 2 and 3 — `lint-go` catches violations before they merge.
  - Rule 1 (file naming) prevented a recurring smell during the portal service build; the renamed files (`organization.go` instead of `organization_repo.go`) are now the canonical reference.
  - Rule 5 (interface placement) eliminates a whole class of "premature `ports/` package" design errors by giving a contributor a written rule to invoke at review time.
- **Negative**:
  - Rule 1 (file naming) is not auto-enforced yet; relies on manual review or a future custom lint rule. The convention notes this as a follow-up.
  - Rule 5 (interface placement) is a judgment call near the boundary — when does a shared interface belong in a domain `port.go` vs a handler-local declaration? The convention documents the heuristic but cannot mechanise it.
- **Neutral**:
  - Aligns with [Effective Go](https://go.dev/doc/effective_go) and the [Google Go Style Guide](https://google.github.io/styleguide/go/) without copy-pasting either. Where the workspace is stricter (e.g., `errors.Is` is *required*, not *suggested*), the convention says so explicitly.
  - Builds on the existing `.golangci.yml` (revive + errorlint + gofumpt + goimports). No new toolchain.

## Alternatives considered

- **No workspace-wide rules; rely on per-package AGENTS.md.** Rejected because per-file style needs consistency across packages — a contributor reading three packages in the portal service should not see three different error-handling styles. AGENTS.md is the right home for package-specific rules, not for cross-cutting style.
- **Adopt Google's full Go style guide verbatim.** Rejected because some Google rules are weaker than what the workspace already enforces (e.g., `errors.Is` / `errors.As` is suggested but not required by Google; here it is required by `errorlint`). Picking the subset that fits avoids overclaim and keeps the rule count manageable.
- **Write a custom golangci-lint plugin for every rule immediately.** Rejected because the rules are still new — we want lived experience with them in one or two services before locking them into tooling. The convention doc is the iteration surface; custom lint can follow once the rules stabilise.
- **Per-rule ADRs (one for file-naming, one for doc-comments, etc.).** Rejected as over-decomposition. These five rules are tightly coupled to "how a single `.go` file looks" and were decided together in one design pass. One ADR is the right grain; the convention doc internally separates per-rule sections.

## References

- [`docs/conventions/go/code-style.md`](../conventions/go/code-style.md) — the convention this ADR establishes.
- [ADR-0001](0001-single-responsibility-go-packages.md) — package SHAPE for the SRP category. Code style applies regardless of category.
- [ADR-0003](0003-service-architecture.md) — the service architecture convention; it depends on rule 5 (interface placement at consumer) being workspace-wide.
- [Effective Go — Package names](https://go.dev/doc/effective_go#package-names)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [revive](https://github.com/mgechev/revive) — the linter enforcing rule 2.
- [errorlint](https://github.com/polyfloyd/go-errorlint) — the linter enforcing rule 3.
- [goimports](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) — the formatter producing rule 4.
