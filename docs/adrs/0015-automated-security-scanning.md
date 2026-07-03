# 0015. Automated Go security scanning

- **Status**: Accepted
- **Date**: 2026-07-03
- **Deciders**: workspace maintainer
- **Supersedes**: -
- **Superseded by**: -

## Context

The workspace already treats the Go toolchain as Nix/devenv-owned state. [ADR-0007](0007-nix-devenv-developer-environment.md) established `packages/nix/core/toolchains/go/` as the place to provide Go tooling and generate tool configuration, and [ADR-0012](0012-git-workflow-and-conventions.md) established pull-request-gated trunk flow with local hooks for fast checks. The existing generated `.golangci.yml` already enables `gosec` through `packages/nix/core/toolchains/go/golangci-lint/default.nix`, excludes `G104`, and excludes `gosec` in `_test.go` files.

That gives the workspace SAST coverage through the normal `lint-go` path, but it does not check whether Go dependencies or standard-library call paths are affected by known vulnerabilities. `golangci-lint` and `gosec` are source analyzers; dependency-vulnerability reachability belongs to `govulncheck`, which uses Go's vulnerability database and call-graph analysis. Because `govulncheck` reaches out to `vuln.go.dev` and can be slower than local lint, it is a poor fit for a per-commit hook but a good fit for an explicit local command and a pull-request gate.

There is no existing `.github/workflows/` tree. Introducing the first GitHub Actions workflow is in scope for this decision because dependency vulnerability scanning is most valuable when every PR receives the same required check, not only when a contributor remembers to run it locally.

## Decision

**We will add automated Go dependency-vulnerability scanning with `govulncheck`, and keep Go SAST scanning as the existing `gosec` linter inside generated `golangci-lint` configuration.** `govulncheck` becomes a local devenv command and the first GitHub Actions PR gate; `gosec` remains unchanged inside `.golangci.yml` and will not be duplicated as standalone `securego/gosec`.

The implementer will add a `core.toolchains.go.govulncheck` Nix module that provides the tool and registers a local command such as `govuln-scan`. The command runs `govulncheck` per module:

```bash
for d in $(go list -m -f '{{.Dir}}' all); do
  (cd "$d" && govulncheck ./...)
done
```

The implementer will also add `.github/workflows/vulncheck.yml` using `golang/govulncheck-action@v1` with `go-version-file: go.work` and `go-package: ./...`. `govulncheck` will not be added to pre-commit: the network dependency on `vuln.go.dev` and the expected latency make it a PR gate and explicit local command, not a per-commit hook.

### Correction (2026-07-03): GitHub Actions invocation

The CI mechanic originally planned above — `golang/govulncheck-action@v1` with `go-version-file: go.work` and `go-package: ./...` — did not fit the shipped repository shape. This workspace has no root `go.mod`, and root `go.work` is Nix-generated from `core.toolchains.go.go-work.mods` and gitignored, so the whole-repo action path fails in CI before scanning.

The shipped `.github/workflows/vulncheck.yml` instead uses `actions/setup-go` with `go-version-file: services/portal/go.mod`, reconstructs `go.work` in the runner, and scans each discovered workspace module:

```bash
go work init
for gomod in $(find . -name go.mod -not -path '*/vendor/*' -not -path '*/testdata/*'); do
  go work use "$(dirname "$gomod")"
done

for dir in $(go list -m -f '{{.Dir}}'); do
  (cd "$dir" && govulncheck ./...)
done
```

This preserves the decision's intent — a PR-gated, reachability-aware `govulncheck` scan across all real Go modules while keeping `go.work` Nix-owned and uncommitted. The first sound run caught reachable standard-library vulnerabilities `GO-2026-5037` (`crypto/x509`) and `GO-2026-5039` (`net/textproto`), remediated by bumping Go `1.26.3` to `1.26.4`; see [the finding](../findings/2026-07-03-govulncheck-go-stdlib-vulns.md).

For SAST, the decision is to leave the current `gosec` integration alone. `packages/nix/core/toolchains/go/golangci-lint/default.nix` remains the single configuration and suppression surface for Go lint/SAST; standalone `securego/gosec` is deferred unless the workspace later adopts GitHub code scanning/SARIF as a separate decision.

## Consequences

- **Positive**:
  - Dependency vulnerability scanning becomes reproducible locally through devenv and automatic on PRs through GitHub Actions.
  - The workspace gains reachability-aware vulnerability checks from the Go vulnerability database instead of only source-pattern SAST.
  - SAST remains on the existing `lint-go` path, with one generated `.golangci.yml`, one suppression grammar, and one version surface.
  - Automated scanning complements [ADR-0014](0014-security-reviewer-agent.md): machines catch known dependency and source-pattern issues; the Security Reviewer remains the human/agent gate for RLS and authorization design.
- **Negative**:
  - This introduces the repo's first `.github/workflows/` CI workflow, so GitHub Actions becomes part of the enforcement surface and branch-protection follow-up must treat `vulncheck` as a required check if we want it to gate merges.
  - `govulncheck` has no in-source suppression mechanism (tracked by golang/go#61211). If a finding is accepted as noise or low risk, remediation is still upgrade, replace, or wait for upstream metadata/tooling; it cannot be silenced next to the code.
  - `govulncheck` makes network calls to `vuln.go.dev`, adding latency and a network-availability failure mode to the PR check. The privacy posture is acceptable for this workspace: the tool sends module paths/request metadata, not source code.
  - Conservative call-graph analysis can produce occasional false positives or inaccurate call stacks, so findings still require review before remediation work is scoped.
  - The `gosec` version bundled with `golangci-lint` may trail standalone `securego/gosec` by a release or two; we accept that lag to keep one config and suppression surface.
- **Neutral**:
  - Pre-commit remains fast and local: `lint-go` continues to run `golangci-lint`/`gosec`, while `govulncheck` is opt-in locally and enforced in PRs.
  - The Go toolchain gains one more optional submodule under `packages/nix/core/toolchains/go/`, following the same Nix-owned tooling model as the existing linter module.

## Alternatives considered

- **Standalone `securego/gosec` alongside golangci-lint.** Rejected because `gosec` is already enabled in the generated `.golangci.yml`; a standalone runner would create a second config surface, second suppression grammar, and second version to bump.
- **Run `govulncheck` as a pre-commit hook.** Rejected because it depends on `vuln.go.dev` and can be slow. Slow network gates belong in PR/CI and explicit local commands, not every commit attempt.
- **Local-only `govulncheck`, no CI workflow.** Rejected because there would be no PR gate and no shared enforcement. `govulncheck` is most valuable when it runs consistently before merge.

## References

- [ADR-0007: Manage the developer environment with Nix + devenv](0007-nix-devenv-developer-environment.md) — Nix/devenv ownership of toolchains and generated config.
- [ADR-0012: Git workflow, commit, and pull-request conventions](0012-git-workflow-and-conventions.md) — PR-gated trunk flow and hook boundaries.
- [ADR-0014: Add a Security Reviewer agent](0014-security-reviewer-agent.md) — human/agent security review counterpart to automated scanning.
- [`govulncheck` command documentation](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) — source scanning, vulnerability database calls, exit codes, limitations, and no-suppression caveat.
- [`golang/govulncheck-action`](https://github.com/golang/govulncheck-action) — GitHub Action inputs including `go-version-file` and `go-package`.
- [golangci-lint `gosec` linter settings](https://golangci-lint.run/docs/linters/configuration/#gosec) — bundled SAST linter configuration surface.
- [golang/go#61211](https://github.com/golang/go/issues/61211) — tracking issue for silencing `govulncheck` findings.
- [Go Vulnerability Database privacy policy](https://vuln.go.dev/privacy) — data logged by `vuln.go.dev` requests.
