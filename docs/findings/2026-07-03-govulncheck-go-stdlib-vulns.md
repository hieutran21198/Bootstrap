# govulncheck flags reachable Go 1.26.3 stdlib vulnerabilities

> **Status**: Resolved
> **Authors**: workspace maintainer
> **Investigated**: 2026-07-03
> **Tracks**: [ADR-0015](../adrs/0015-automated-security-scanning.md)

## Symptom

The first successful run of the new `vulncheck` GitHub Actions workflow — the
pull-request gate introduced by [ADR-0015](../adrs/0015-automated-security-scanning.md)
— failed. `govulncheck` reported reachable vulnerabilities in two of the three
workspace `go.work` modules (`packages/go` and `services/portal`); `tools` came
back clean. The workflow's very first green plumbing run was therefore a red
scan result.

## Reproduction

The `vulncheck` workflow on branch `fix/vulncheck-go-work-modules` (PR #7) runs
`govulncheck ./...` per module across the `go.work` modules on Go 1.26.3.

```text
# per-module, across the go.work modules, on Go 1.26.3
cd packages/go     && govulncheck ./...
cd services/portal && govulncheck ./...
cd tools           && govulncheck ./...
```

## Hypotheses considered

- **H1: This is a CI config/plumbing error, not a real vulnerability.**
  Partially true *earlier* and for a *separate* reason — `go.work` was not
  present in CI, so `services/portal` cross-module symbol resolution was
  incomplete and the scan could not produce trustworthy call graphs. That
  plumbing gap was fixed by reconstructing `go.work` in the workflow. Once
  scanning was sound, the findings did not disappear — so the plumbing issue was
  real but **distinct from** the vulnerability. Disproved as an explanation for
  the failing scan.
- **H2: These are false positives from conservative call-graph analysis.**
  Rejected. `govulncheck` emitted *symbol-level* findings with concrete call
  traces from workspace code into the vulnerable stdlib functions, not
  module-level "vulnerability present in the graph" warnings. Reachable, not
  advisory.
- **H3: These are real, reachable standard-library vulnerabilities.** Confirmed
  — see Root cause. Two stdlib advisories reachable through the shared echox
  server and the ssmx loader.

## Investigation

Once the workflow correctly reconstructed `go.work` and scanned each module,
`govulncheck` produced symbol-level traces:

### `packages/go`

- **GO-2026-5039** (`net/textproto` — arbitrary inputs left unescaped in
  returned errors), reachable via
  `server/echox/echox.go:110` `echox.Start` → echo `StartServer` →
  `textproto.Reader.ReadMIMEHeader`.
- **GO-2026-5037** (`crypto/x509` — inefficient candidate hostname parsing),
  reachable via `echox.Start` **and** via
  `aws/ssmx/ssm.go:70` `ssmx.Loader.Load` → ssm `GetParametersByPath` →
  `x509`.

### `services/portal`

- **GO-2026-5037** (`crypto/x509`), reachable via
  `cmd/migrate/main.go:22` `migrate.init` → `x509` **and** via
  `internal/domain/staff/port.go:18` `staff.NotFoundError.Error` →
  `fmt.Sprintf` → `x509.HostnameError.Error`.

### `tools`

- No reachable vulnerabilities.

## Root cause

The workspace pinned Go 1.26.3, whose standard library contains GO-2026-5037
(`crypto/x509`) and GO-2026-5039 (`net/textproto`); both are reachable from
workspace code through the shared echox server and the ssmx loader. Both
advisories are marked "Fixed in go1.26.4" — the vulnerability is in the pinned
toolchain's stdlib, not in any workspace or third-party dependency code.

## Resolution

- **PR #7** — bumped the nixpkgs pin (`3e41b24…` → `e1c1b84…`, moving `go_1_26`
  from 1.26.3 to 1.26.4), the Nix toolchain version, and all three `go.mod` `go`
  directives to 1.26.4. Re-running the `vulncheck` workflow reported
  "No vulnerabilities found" for all three modules.

## References

- https://pkg.go.dev/vuln/GO-2026-5037 (`crypto/x509`, fixed in go1.26.4)
- https://pkg.go.dev/vuln/GO-2026-5039 (`net/textproto`, fixed in go1.26.4)
- [ADR-0015](../adrs/0015-automated-security-scanning.md) — Automated Go security scanning (introduced the `vulncheck` gate)
- [ADR-0014](../adrs/0014-security-reviewer-agent.md) — Add a Security Reviewer agent
- PR #7 (`fix/vulncheck-go-work-modules`) — the go.work plumbing fix and the Go 1.26.4 bump
