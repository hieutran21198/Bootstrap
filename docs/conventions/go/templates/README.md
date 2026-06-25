# Go package templates

Text templates for single-responsibility Go packages. Pick the matching template, copy it, and substitute the `{{ .XXX }}` placeholders. No CLI to install, no build step — the templates are the artifact.

> **Scope**: Go packages in the SRP-stateful and SRP-stateless categories. See [`../creating-new-package.md`](../creating-new-package.md) to classify.
> **Status**: Active
> **Decided by**: [ADR-0001](../../../adrs/0001-single-responsibility-go-packages.md)
> **Last reviewed**: 2026-06-24

## Contents

| Template                                 | Use for                                            | Required placeholders                                                            |
| ---------------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------- |
| [`stateful.go.tmpl`](stateful.go.tmpl)   | Packages owning state (server, client, connection) | `PackageName`, `TargetName`, `PackagePurpose`, `TargetPurpose`                   |
| [`stateless.go.tmpl`](stateless.go.tmpl) | Pure-function packages (parser, formatter, codec)  | `PackageName`, `PackagePurpose`                                                   |

## Placeholder reference

| Placeholder             | Type   | Meaning                                                                                                | Example                                                                                |
| ----------------------- | ------ | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `{{ .PackageName }}`    | string | Package directory name. Matches the `package X` declaration. Lowercase, no separators.                  | `echox`                                                                                  |
| `{{ .TargetName }}`     | string | Exported target struct name. By convention, `PackageName` with the first letter uppercased.             | `Echox`                                                                                  |
| `{{ .PackagePurpose }}` | string | One clause completing "Package X ...". No leading article. No trailing period (the template adds it).   | `wraps Echo v4 with sensible timeouts and slog request logging`                          |
| `{{ .TargetPurpose }}`  | string | One clause completing "T is ...". Same style as above.                                                  | `the configured Echo server instance with middleware and timeouts applied`               |

## How an AI agent uses these

1. Read [`../creating-new-package.md`](../creating-new-package.md) — confirm the package belongs in the SRP-stateful or SRP-stateless category.
2. Pick the matching template from the **Contents** table above.
3. Substitute every `{{ .XXX }}` placeholder using the values for THIS specific package. The **Placeholder reference** table tells you the type and shape of each value.
4. Write the result to `<segment>/<PackageName>/<PackageName>.go`.
5. Run `go mod tidy` in the parent Go module, then `lint-go` to verify the new package passes the workspace lint set.
6. If the package owns state (stateful template), the resulting shape already matches the governance in [`packages/go/AGENTS.md`](../../../../packages/go/AGENTS.md). No further governance check needed.

## How a human uses these

`cp` the template into place, run a find-and-replace for each placeholder, save. Example with `sed`:

```bash
PKG=echox
TARGET=Echox
SEGMENT=packages/go/server

mkdir -p "${SEGMENT}/${PKG}"
cp docs/conventions/go/templates/stateful.go.tmpl "${SEGMENT}/${PKG}/${PKG}.go"

sed -i \
  -e "s|{{ .PackageName }}|${PKG}|g" \
  -e "s|{{ .TargetName }}|${TARGET}|g" \
  -e "s|{{ .PackagePurpose }}|wraps Echo v4 with sensible timeouts|g" \
  -e "s|{{ .TargetPurpose }}|the configured Echo server instance|g" \
  "${SEGMENT}/${PKG}/${PKG}.go"

# Then fill in the TODOs.
```

## Notes on the template syntax

Templates use Go's [`text/template`](https://pkg.go.dev/text/template) double-brace syntax (`{{ .Name }}`) so they remain forward-compatible with a CLI wrapper if one is added later. For now they are read and substituted directly — the template files are themselves the artifact, no generator binary required.

The file extension is `.go.tmpl` so editors and tooling do not parse the unrendered file as Go (the placeholders are not valid Go expressions).

## See also

- [Creating a new Go package](../creating-new-package.md) — the workflow that uses these templates.
- [Single-responsibility category](../single-responsibility.md) — what counts as SRP.
- [packages/go/AGENTS.md](../../../../packages/go/AGENTS.md) — the governance the stateful template produces.
- [ADR-0001 — Adopt templates for single-responsibility Go packages](../../../adrs/0001-single-responsibility-go-packages.md)
