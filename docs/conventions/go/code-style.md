# Go code style

> **Scope**: every `*.go` file in this workspace — `packages/go/**`, `services/**`, `tools/**`, `apps/**`.
> **Status**: Active
> **Decided by**: [ADR-0002](../../adrs/0002-go-code-style.md)
> **Last reviewed**: 2026-06-26

Workspace-wide rules for per-file Go style. The [single-responsibility convention](single-responsibility.md) covers package SHAPE; this document covers per-file STYLE. Both apply.

Service-layer architecture patterns (DDD, CQRS, UoW, port shape) live in [service-architecture.md](service-architecture.md). This document is purely about style — naming, comments, errors, imports, interfaces.

---

## 1. File naming — no package-name stutter

### Rule

Name a Go file for the type or concept it contains. Do **not** duplicate the package name as a suffix.

### Rationale

Inside `package X`, identifiers are accessed as `X.Identifier`. A file `Y_X.go` in `package X` creates filesystem stutter that mirrors the type-level stutter Go's anti-stutter idiom warns against (`X.YX` is bad; same logic for files).

### Apply

When creating a new `.go` file:
1. Identify the primary type or concept the file contains.
2. Name it `<concept>.go`. Lowercase, underscores only for compound concepts with no single-word name.
3. Confirm the file name does not end in `_<package>.go`.

### Examples

#### ✓ Good

```
packages/go/env/env.go                                          # contains Loader, FileLoader, OSLoader, Parse
packages/go/gormx/postgres/postgres.go                          # contains Config, Postgres, New
packages/go/server/echox/echox.go                               # contains Config, Echox, New
services/portal/internal/infra/postgres/uow/uow.go              # contains UnitOfWork, txUnitOfWork, New
services/portal/internal/infra/postgres/repo/organization.go    # contains OrganizationWriter, organizationRow
services/portal/internal/infra/postgres/repo/staff.go           # contains StaffWriter, staffRow
services/portal/internal/domain/organization/organization.go    # contains the Organization aggregate
services/portal/internal/domain/organization/port.go            # contains Writer, Reader, NotFoundError
services/portal/internal/domain/staff/email.go                  # contains the Email value object
```

#### ✗ Bad

```
packages/go/env/env_loader.go                                   # _loader stutter
services/portal/internal/infra/postgres/repo/organization_repo.go  # _repo duplicates package name
services/portal/internal/infra/postgres/repo/staff_repo.go         # same
services/portal/internal/infra/postgres/uow/uow_unit_of_work.go    # full-stutter form
```

### Enforcement

- Manual review.
- Future: a custom `revive` or `golangci-lint` rule that flags files matching `*_<dir>.go` where `<dir>` is the package directory name.

---

## 2. Doc comments on every exported identifier

### Rule

Every exported package, type, function, constant, and variable has a doc comment that begins with the identifier's name.

### Rationale

`revive`'s `exported` rule enforces this; the resulting godoc is consumable by IDE hovers, `go doc`, and pkg.go.dev. Doc comments that name the identifier render correctly in every tool.

### Apply

1. Add a `// Identifier ...` comment immediately above every exported declaration.
2. For packages, add a `// Package name ...` block above the `package` keyword in exactly one file in the package (conventionally `doc.go` or the main file).
3. For cross-references between types, use godoc link syntax: `[pkg.Name]` or `[Name]` (Go 1.19+).

### Examples

#### ✓ Good

```go
// Package uow is the postgres-backed implementation of
// [command.UnitOfWork]. It bundles per-aggregate Writer ports behind a
// single accessor surface...
package uow

// UnitOfWork is the postgres-backed [command.UnitOfWork].
//
// One accessor surface, two modes: ...
type UnitOfWork struct {
    db *gorm.DB
    *txUnitOfWork
}

// New constructs a [command.UnitOfWork] bound to db.
func New(db *gorm.DB) *UnitOfWork { ... }
```

#### ✗ Bad

```go
// the unit of work             ← does NOT start with identifier name
type UnitOfWork struct { ... }

type UnitOfWork struct { ... }  ← no doc comment at all (revive fails)

// New creates one.             ← starts with identifier but body is empty
func New(db *gorm.DB) *UnitOfWork { ... }
```

### Enforcement

`revive` rule `exported` configured in `.golangci.yml`. `lint-go` flags violations.

---

## 3. Error handling

### Rule

- Define sentinel errors with `errors.New("<pkg>: <reason>")` at package scope.
- Wrap with `%w` when adding context: `fmt.Errorf("<pkg>: <op>: %w", err)`.
- Compare with `errors.Is` (sentinels) or `errors.As` (typed errors). **Never compare by string.**
- For errors callers need to inspect (e.g., a UUID), define a struct with a value receiver `Error() string`.

### Rationale

- `errors.Is/As` are the only future-safe comparison APIs.
- `%w` preserves the error chain for `Is/As`.
- `errorlint` flags both unwrap-correctness and use of `==` / string matching on errors.
- Prefixing sentinels with the package name keeps log messages unambiguous when errors bubble across layers.

### Apply

**Sentinel error**:
```go
var ErrInvalidEmail = errors.New("invalid email")
```

**Wrapping with context**:
```go
return "", fmt.Errorf("%w: %q", ErrInvalidEmail, raw)
```

**Caller comparison**:
```go
if errors.Is(err, ErrInvalidEmail) { ... }
```

**Typed error for inspection**:
```go
type NotFoundError struct{ UUID string }
func (e NotFoundError) Error() string { return fmt.Sprintf("organization %q not found", e.UUID) }

// caller:
var nfe organization.NotFoundError
if errors.As(err, &nfe) {
    log.Warn("missing", "uuid", nfe.UUID)
}
```

### Examples

#### ✓ Good

```go
var ErrEmptyName = errors.New("organization: empty name")

if name == "" {
    return ErrEmptyName
}
if len(name) > maxLen {
    return fmt.Errorf("%w: %d > %d", ErrNameTooLong, len(name), maxLen)
}
```

#### ✗ Bad

```go
if name == "" {
    return errors.New("empty name")                       // no sentinel, no Is-comparable
}

if strings.Contains(err.Error(), "empty name") { ... }    // string match
if err == ErrEmptyName { ... }                            // wrap-unaware comparison
return fmt.Errorf("name validation failed: %s", err)      // %s instead of %w
```

### Enforcement

- `errorlint` in `.golangci.yml`: catches `%s`/`%v` on errors, `==` comparisons, missing `%w`.
- `revive`'s `error-naming` rule: requires `ErrXxx` form for sentinels.

---

## 4. Import grouping

### Rule

Group imports in three blocks, separated by blank lines:
1. Standard library
2. Third-party (any non-stdlib, non-bootstrap)
3. Local (`bootstrap/...`)

### Rationale

`goimports -local bootstrap/` is the project-configured formatter; this grouping is its output. Consistent grouping makes per-block scanning fast and conflict-resolution mechanical.

### Apply

Run `goimports -local bootstrap/ -w <file>` after writing imports manually. `lint-go --fix` does this for every Go file.

### Examples

#### ✓ Good

```go
import (
    "context"
    "errors"
    "fmt"

    "gorm.io/gorm"

    "bootstrap/services/portal/internal/domain/staff"
)
```

#### ✗ Bad

```go
import (
    "bootstrap/services/portal/internal/domain/staff"
    "context"
    "errors"

    "gorm.io/gorm"
)
```

```go
import (
    "context"
    "gorm.io/gorm"
    "bootstrap/services/portal/internal/domain/staff"
)
// no blank-line groups
```

### Enforcement

`goimports -local bootstrap/` and `gofumpt` configured as formatters in the Nix toolchain. Run via `lint-go --fix`.

---

## 5. Interface placement — at the consumer

### Rule

Define interfaces in the package that USES them (the consumer). Do not create a separate `ports/` package whose only purpose is to hold interface declarations.

### Rationale

Go interfaces are not declared-satisfaction (no `implements` keyword); any type with the right method set satisfies them implicitly. The consumer can therefore declare exactly the methods it needs, no more. Putting interfaces in a shared `ports/` package prematurely binds implementations to a wider contract than necessary and inverts who owns the contract.

### Apply

- An interface that ONE handler uses → declare in the handler's file.
- An interface that several handlers in the same package use → declare in that package (e.g., `app/command/port.go`).
- An interface that multiple consumer packages need (e.g., a driven-port like `Writer` consumed by both command handlers and UoW) → declare in the domain package's `port.go` until enough consumers exist to justify per-consumer narrower interfaces.

### Examples

#### ✓ Good

```go
// app/command/port.go — consumed by handlers in this package
type UnitOfWork interface {
    DoTransaction(...)
    TransactionalUnitOfWork
}

// app/command/hire_staff.go — handler-local narrower interface
type staffSaver interface {
    Save(ctx context.Context, s *staff.Staff) error
}

type HireStaffHandler struct {
    saver staffSaver  // only needs Save, not full Writer
}

// domain/organization/port.go — shared driven-port (until narrower consumer interfaces emerge)
type Writer interface { Save(...); Update(...) }
type Reader interface { ByUUID(...) }
```

#### ✗ Bad

```go
// internal/ports/ports.go — central interface dump
type OrganizationRepository interface { ... }
type StaffRepository interface { ... }
type EmailSender interface { ... }
type Logger interface { ... }
// every adapter imports this file; every handler imports this file;
// any change ripples everywhere
```

### Enforcement

- Manual review during PR.
- Architectural test (future): forbid `internal/ports/` directory at the linter level.

---

## See also

- [single-responsibility.md](single-responsibility.md) — package SHAPE for SRP packages (packages/go).
- [creating-new-package.md](creating-new-package.md) — pre-creation decision tree.
- [service-architecture.md](service-architecture.md) — service-layer patterns (DDD, CQRS, UoW).
- [packages/go/AGENTS.md](../../../packages/go/AGENTS.md) — SRP-stateful governance.
- [services/portal/AGENTS.md](../../../services/portal/AGENTS.md) — portal-specific layout.
- [Effective Go](https://go.dev/doc/effective_go)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
