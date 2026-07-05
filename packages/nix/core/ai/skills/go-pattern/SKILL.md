---
name: go-pattern
description: Idiomatic Go plus this workspace's load-bearing Go conventions (modern Go 1.26 idioms, SRP package shapes, DDD/CQRS, typed IDs, stdlib testing). Use when writing, reviewing, or refactoring Go in packages/go, services/portal, or tools.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Go Patterns

Write Go that is boring in the best way — predictable, consistent, easy to delete.
This skill covers the rules a reviewer would flag that the **linter cannot**, plus
the modern-Go defaults and the structural conventions this workspace depends on.

`golangci-lint` already enforces the mechanical layer — don't spend review on it (see
[§ Already enforced](#already-enforced-do-not-re-teach)). Spend it on the rules below.

## When this applies

- Adding or changing Go in `packages/go/`, `services/portal/`, or `tools/`.
- Reviewing a Go diff, or scaffolding a new package / aggregate / handler / repo.
- Deciding an API shape, an error, an interface boundary, or a test layout.

All modules pin **Go 1.26.3** (`go.work`), so every modern idiom below is available and
expected. Legacy workarounds written for Go ≤ 1.21 are a smell here.

## Modern Go 1.26 baseline (use these by default)

1. **`any`, never `interface{}`.** Alias since 1.18; `interface{}` in new code is stale.
2. **Loop variables are per-iteration (1.22).** Never write `v := v` / `i, v := i, v` to
   "capture" for a closure or goroutine — it does nothing now and signals pre-1.22 code.
3. **`slices` / `maps` / `cmp` over hand-rolled loops.** `slices.Contains`, `slices.Sort`,
   `slices.IndexFunc`, `slices.Clone`, `maps.Clone`, `slices.Sorted(maps.Keys(m))`,
   `cmp.Or(a, b)` for first-non-zero, `min`/`max`/`clear` builtins (1.21).
4. **`log/slog` for structured logging** (already the house logger — see `echox.go`). Use
   typed attrs (`slog.Int`, `slog.Duration`); `slog.LogAttrs` on hot paths; `InfoContext`
   when a `ctx` is in scope. Bridge once with `slog.SetDefault` in `main`.
5. **Errors: `%w` wrap, `errors.Is`/`errors.As` match, `errors.Join` to combine.** Prefer
   the generic `perr, ok := errors.AsType[*T](err)` (1.26) over the `var perr *T; errors.As`
   dance. Never string-match `err.Error()`.
6. **`math/rand/v2`** for non-crypto randomness; **`crypto/rand`** (and `crypto/rand.Text`)
   for anything security-bearing — never `math/rand` for tokens/keys.
7. **Concurrency helpers:** `sync.WaitGroup.Go(fn)` (1.25) over the `Add`/`go`/`Done` trio;
   `sync.OnceValue`/`OnceFunc` over `sync.Once` boilerplate; range-over-func iterators
   (`iter.Seq[T]`, expose as an `All()` method) only when a container truly needs iteration.
8. **Testing (1.24+):** `for b.Loop()` not `for i := 0; i < b.N; i++`; `t.Context()` for a
   test-scoped context; `testing/synctest` for time-dependent concurrency instead of
   `time.Sleep`.

## Universal rules the linter won't catch

- **Accept interfaces, return concrete types.** Define the interface in the **consumer**
  package (where it's used), never a producer-side `ports/` package. The bigger the
  interface, the weaker the abstraction.
- **`context.Context` is the first parameter** of any function that does I/O or crosses a
  boundary — never a struct field. Check `ctx.Err()` first in a constructor that will do I/O.
- **Make the zero value useful**, or document why it isn't.
- **Every goroutine has an obvious, documented stop.** No fire-and-forget; pass a `ctx` or
  a done channel and let the caller wait. Prefer synchronous funcs — callers add concurrency.
- **Receiver names:** one consistent 1–2 letter abbreviation per type; never `me`/`this`/`self`.
  Pick pointer *or* value receivers per type and don't mix.
- **No `util` / `common` / `helpers` / `base` packages.** Name a package for what it provides.
  Don't stutter (`widget.New`, not `widget.NewWidget`).

## Package shapes (SRP — ADR-0001)

Two canonical shapes. Classify the package first (see `docs/conventions/go/creating-new-package.md`).

**Stateful** (`gormx`, `migrate`, `server/echox`) exposes exactly three things:

```go
type Config struct{ /* passed by value; zero values valid */ }
type Echox  struct{ /* exported name mirrors the package concept */ }

// New is the ONE constructor. ctx first; ctx.Err() checked before I/O.
func New(ctx context.Context, cfg Config) (*Echox, error) { ... }
```

- `applyDefaults(cfg)` is a private helper called from `New`; never mutate `cfg` after `New`.
- One `New` per package — no `NewFromEnv` / `NewWithLogger` siblings (the `ssmx.NewFromEnv`
  one-liner is the only sanctioned exception, and only as a thin wrapper over `New`).
- Required field missing → `var ErrXxxRequired = errors.New("<pkg>: Xxx is required")`.
- The `revive` stutter check is *disabled* precisely so `echox.Echox` / `gormx.Gormx` are OK.

**Stateless** (`idgen`, `env`, `gormx/postgres`) is pure funcs, often generic:

```go
type StringID interface{ ~string }

// NewFor returns the TYPED id, not a raw string. Panic is documented & accepted
// (a failed OS RNG is unrecoverable — ADR-0004), so callers get no error to handle.
func NewFor[T StringID]() T      { return T(uuid.Must(uuid.NewV7()).String()) }
func Validate[T StringID](id T) error { ... } // call at boundaries only
```

## Files, interfaces, assertions

- **No-stutter filenames:** `organization.go`, not `organization_repo.go`; `port.go`, not
  `ports.go`; one concept per file. (Lint can't catch this yet — reviewers must.)
- **Compile-time interface assertion at the bottom of every adapter file:**
  ```go
  var _ organization.Writer = (*OrganizationWriter)(nil)
  ```
  It fails the build the instant a method signature drifts.
- **Prove conformance without importing the port** (structural typing, the `ssmx` trick):
  ```go
  var _ interface {
      Load(context.Context) (map[string]string, error)
  } = (*Loader)(nil)
  ```

## Domain: aggregates, value objects, typed IDs (ADR-0003, ADR-0004)

- **Typed ID per aggregate** in `id.go`: `type ID string` + `String()`; no constructor —
  minted with `idgen.NewFor[ID]()`. Use `id` (not `uuid`) in messages; format is internal.
- **Cross-aggregate references are raw `string`** whose name bakes in the foreign aggregate
  (`ownerStaffID string`, `organizationID string`) — the known compromise; cast at the
  boundary (`staff.ID(cmd.StaffID)`).
- **Aggregate:** all fields private; `NewXxx(...) (*T, error)` validates every invariant and
  **never panics**; `UnmarshalXxxFromDatabase(...)` is the only validation bypass (still
  rejects an empty PK). Getters use value receivers; mutators use pointer receivers and
  return `error`; idempotent ops reject the redo (`ErrAlreadyDeactivated`).
- **Value object** (`Email`, `Slug`): typed primitive, `NewXxx(raw) (Xxx, error)` normalizes
  + validates, zero value is invalid, `String()` implements `fmt.Stringer`, one per file.

## Ports, Unit of Work, repositories

- **CQRS split (ADR-0005):** `Writer` has only `Create`/`Update`; `Reader` has only reads
  (`ByID`). Separate interfaces, no callback `Update`, no `Save`/upsert. `Update` overwrites
  a row keyed on `T.ID()` and returns a typed `NotFoundError` on no match.
- **Unit of Work (ADR-0008)** is the write chokepoint — a two-struct pattern. Every write
  runs inside it, even single-aggregate ones; there is **no scope-less write path**:
  ```go
  return u.db.Transaction(func(tx *gorm.DB) error {
      if err := idgen.Validate(id); err != nil { return organization.ErrEmptyID }
      if err := bindOrganizationRLS(ctx, tx, id); err != nil { return err } // set_config(..., true)
      return handler(ctx, newTxUnitOfWork(tx))
  })
  ```
  (RLS binding lives in the `rls-patterns` skill — bind per-transaction, `is_local=true`.)
- **Repository** (`repo/<aggregate>.go`): a **private** `xxxRow` struct owns the `gorm` tags
  (never put tags on the aggregate); `TableName()` overrides the plural default; take a
  `*gorm.DB` so the caller decides auto-commit vs tx-scoped; `Select("*").Updates(&row)` so
  zero values persist; `RowsAffected == 0` → `NotFoundError`; `errors.Is(err,
  gorm.ErrRecordNotFound)` on reads; `toRow`/`fromRow` helpers cast `string ↔ ID` at the SQL
  boundary.
- **OIDC is a neutral port too (ADR-0006).** The identity provider is an adapter: a **slim**
  `Authenticator` interface (+ a neutral `Principal`) lives beside `UnitOfWork`/`ReadStore` in
  `app/{command,query}/port.go`; `infra/zitadel` is the **only** package that imports
  `zitadel-go`. Never import the SDK — or a `urn:zitadel:…` claim key — in `app`/`domain`/`delivery`;
  keep token strategy (JWT vs introspection) behind the port. See
  `docs/conventions/auth/oidc-provider-integration.md`.

## Errors

- **Sentinel:** `var ErrXxx = errors.New("<pkg>: <reason>")` — lowercase, package-prefixed,
  no trailing punctuation. Wrap with context: `fmt.Errorf("<pkg>: <op>: %w", err)` or
  `fmt.Errorf("%w: <detail>", ErrXxx)`.
- **Typed error when callers need fields:** a **value-receiver** struct so both `T{}` and
  `*T` satisfy `error` and work with `errors.As`:
  ```go
  type NotFoundError struct{ ID ID }
  func (e NotFoundError) Error() string { return fmt.Sprintf("organization %q not found", string(e.ID)) }
  ```
- Handle each error once: match-and-branch, wrap-and-return, or log-and-degrade — never both.

## Testing (stdlib only)

- **stdlib `testing` only** — no `testify`, `gomock`, or `mockery` (testify is transitive
  only; keep it that way). Fakes are hand-written structs satisfying the interface.
- **`t.Parallel()` as the first line** of every test and every `t.Run` subtest.
- **Table-driven:** `cases := []struct{ name string; ...; wantErr error }` iterated with
  `t.Run(tc.name, func(t *testing.T){ t.Parallel(); ... })`; `t.Helper()` on builders;
  `t.Fatalf` for setup, `t.Errorf` for assertions; failures read `Foo(%q) = %v; want %v`.
- **Package choice:** white-box `package foo` for invariant tests; black-box `package
  foo_test` for cross-package/API tests. Integration tests (`TestRLS…`) live under
  `infra/postgres/` and `t.Skipf` when their env vars are absent.
- **Pin a generic return type at compile time** (fails to build if the API widens to `string`):
  ```go
  func requireTestID(id testID) testID { return id }
  // ... got := requireTestID(idgen.NewFor[testID]())
  ```

## Already enforced — do not re-teach

`golangci-lint` (see `packages/nix/core/toolchains/go/golangci-lint/`) already runs
`errcheck`, `errorlint` (`%w` + `errors.Is/As`), `govet` (+`shadow`), `staticcheck`,
`ineffassign`, `unused`, `bodyclose`, `gocritic`, `gocyclo`, `gosec`, `nakedret`, `nilerr`,
`prealloc`, `revive` (exported docs), `unconvert`, `unparam`, `usestdlibvars`, `misspell`.
Don't spend review comments on those — trust `lint-go`. Focus on the structural and
modern-idiom rules above, which no linter can see.

## References

- ADRs: 0001 (SRP packages) · 0003 (DDD/CQRS/Hexagonal) · 0004 (typed UUIDv7 IDs) ·
  0005 (collection repos) · 0008 (tenant-scoped UoW + RLS) — `docs/adrs/`
- Conventions: `docs/conventions/go/{code-style,service-architecture,single-responsibility,creating-new-package}.md`
  + `docs/conventions/go/templates/{stateful,stateless}.go.tmpl`
  + cross-topic: `docs/conventions/auth/oidc-provider-integration.md` (neutral OIDC port),
  `docs/conventions/database/role-and-scope-contract.md` (RLS roles + scope GUCs)
- Canonical code: `packages/go/{idgen,env,gormx,migrate,server/echox}` ·
  `services/portal/internal/{domain,app/command,infra/postgres}`
- Related skill: `rls-patterns` (row-level security, the UoW binding chokepoint)
- Upstream: Go Code Review Comments <https://go.dev/wiki/CodeReviewComments> ·
  Google Go Style Guide <https://google.github.io/styleguide/go/> · Go Proverbs
