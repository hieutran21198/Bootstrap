{
  config,
  lib,
  ...
}:
{
  options.core.ai.skills.dbRLSPatterns =
    let
      inherit (config.core) utils;
    in
    {
      enable = lib.mkEnableOption "Row Level Security patterns for database operation.";
      statements = {
        whenInvocation = utils.makeListOption {
          ofType = with lib.types; str;
          default = [
            "Creating or modifying API routes that access the database"
            "Accessing admin-only tables (disputes, webhook_events)"
          ];
        };
      };
    };
  config =
    let
      aiOpts = config.core.ai;
      opts = aiOpts.skills.dbRLSPatterns;
      skillName = "rls-patterns";
      whenList = lib.concatMapStringsSep "\n" (s: "- ${s}") opts.statements.whenInvocation;
      skillContent = ''
        ---
        name: ${skillName}
        description: Row Level Security patterns for database operations. Use when writing database code or creating API routes that access data.
        user-invocable: false
        allowed-tools: Read, Grep, Glob
        ---

        # Database RLS Patterns

        ## Purpose

        Enforce Row Level Security (RLS) patterns for all database operations.
        This skill ensures data isolation and prevents cross-user data access
        at the database level.

        ## When This Skill Applies

        Invoke this skill when:

        ${whenList}

        ## Critical Rules

        1. **Connect the app as a non-owner, NOBYPASSRLS role.** This workspace
           provisions three Postgres roles: `admin`, `writer`, `reader`. `admin`
           is `SUPERUSER` and owns the tables, so it **always bypasses RLS** — use
           it only for goose migrations, never for request traffic. Application
           command handlers must connect as `writer` and query handlers as
           `reader` (both plain login roles, `NOBYPASSRLS`). Verify the live
           connection is actually constrained:
           `SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user`
           must return `false`. A superuser DSN makes every policy silently a no-op.

        2. **`ENABLE` is not enough — add `FORCE`.** `ALTER TABLE t ENABLE ROW
           LEVEL SECURITY` does not apply policies to the table owner. Always pair
           it with `ALTER TABLE t FORCE ROW LEVEL SECURITY` so a role that happens
           to own the table is still filtered. (Superusers like `admin` bypass
           regardless; `FORCE` is the safety net for the app role.)

        3. **Enabling RLS without a policy denies everything.** RLS is fail-closed:
           an enabled table with no matching policy returns zero rows and rejects
           every write. Never ship the `ENABLE` migration without its `CREATE POLICY`
           in the same migration.

        4. **Set tenant context per transaction, never per session.** Inject the
           org id as the FIRST statement inside the transaction with
           `SELECT set_config('app.current_org', ?, true)`. The third arg
           `is_local = true` scopes the GUC to the transaction so it reverts on
           COMMIT/ROLLBACK. A bare `SET` (session scope) leaks the previous
           request's org to the next checkout of the same pooled connection — a
           silent cross-tenant data leak.

        5. **Always parameterize the org id (`?` / `$1`).** Never build the
           `set_config` value with string formatting; the id originates from an
           auth token and must be bound, not interpolated.

        6. **Make policies fail-closed with the `missing_ok` flag.** Policy
           expressions read `current_setting('app.current_org', true)`. The `true`
           returns `NULL` when the GUC is unset instead of raising, and
           `organization_id = NULL` evaluates to unknown → the row is denied. Drop
           the `true` and an unmapped request 500s instead of returning no rows.

        7. **Set both `USING` and `WITH CHECK`.** `USING` filters which existing
           rows are visible (SELECT/UPDATE/DELETE); `WITH CHECK` validates new rows
           (INSERT/UPDATE). Omitting `WITH CHECK` defaults it to `USING`, but state
           it explicitly so a `writer` cannot forge a row for another org.

        8. **Never mark a policy helper function `IMMUTABLE` if it reads
           `current_setting()`.** Use `STABLE`. pgx caches prepared plans; an
           `IMMUTABLE` helper pins the first request's org for the life of the
           connection.

        9. **RLS is the authority; app-side org filtering is defense-in-depth
           only.** Do not rely on `WHERE organization_id = ?` in Go in place of a
           policy — add it on top of one.

        ## Protected Tables

        A table needs an RLS policy when ALL hold: (a) it carries a tenant
        discriminator — `organization_id` (see `staff`) — non-null on every row;
        (b) it is reached by `writer`/`reader` (not just `admin`); (c) the tenant
        boundary is a stable, indexable predicate.

        **Needs RLS**
        - `staff` and every future org-scoped aggregate table (`organization_id`).
        - Per-org configuration, integration credentials, feature flags.
        - Outbox / event / read-model tables when the rows are org-scoped
          (`WITH CHECK` stops a writer forging events for another org).
        - Soft-delete / archive siblings — policies do NOT propagate; each table
          enables and policies independently.

        **Does NOT need RLS**
        - `organizations` (the tenant root). RLS here is chicken-and-egg — the
          policy would need the current org to filter the org table. Gate it with
          column-scoped `GRANT`s instead.
        - Cross-tenant lookup/reference data with no tenant column (currencies,
          time zones).
        - Tables only ever touched by `admin` (migrations, ops). `admin` bypasses
          RLS anyway, so a policy adds nothing.

        ## Common Patterns

        ### 1. Enable RLS + tenant policy (goose migration, run as `admin`)

        IDs are `TEXT` UUIDv7 strings (see ADR-0004), so compare as text — no
        `::uuid` cast. Create with `migrate-new <name>`:

        ```sql
        -- +goose Up
        -- +goose StatementBegin
        ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
        ALTER TABLE staff FORCE ROW LEVEL SECURITY;

        CREATE POLICY tenant_isolation_staff ON staff
            AS PERMISSIVE
            FOR ALL
            TO writer, reader
            USING      (organization_id = current_setting('app.current_org', true))
            WITH CHECK (organization_id = current_setting('app.current_org', true));
        -- +goose StatementEnd

        -- +goose Down
        -- +goose StatementBegin
        DROP POLICY IF EXISTS tenant_isolation_staff ON staff;
        ALTER TABLE staff NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE staff DISABLE ROW LEVEL SECURITY;
        -- +goose StatementEnd
        ```

        ### 2. Split read/write policies (optional, finer than `FOR ALL`)

        ```sql
        CREATE POLICY staff_tenant_read ON staff
            AS PERMISSIVE FOR SELECT TO reader
            USING (organization_id = current_setting('app.current_org', true));

        CREATE POLICY staff_tenant_write ON staff
            AS PERMISSIVE FOR ALL TO writer
            USING      (organization_id = current_setting('app.current_org', true))
            WITH CHECK (organization_id = current_setting('app.current_org', true));
        ```

        ### 3. Inject the org GUC in the UnitOfWork (gormx + GORM `?`)

        The single chokepoint is `UnitOfWork.DoTransaction` in
        `services/portal/internal/infra/postgres/uow/uow.go`. Make the GUC the
        first statement of every transaction:

        ```go
        func (u *UnitOfWork) DoTransaction(
            ctx context.Context,
            orgID string, // from the auth token; or pull from ctx via a typed key
            handler func(ctx context.Context, utx command.TransactionalUnitOfWork) error,
        ) error {
            return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
                // transaction-local: reverts on COMMIT/ROLLBACK, pool-safe.
                if err := tx.Exec(
                    "SELECT set_config('app.current_org', ?, true)", orgID,
                ).Error; err != nil {
                    return fmt.Errorf("set app.current_org: %w", err)
                }
                return handler(ctx, newTxUnitOfWork(tx))
            })
        }
        ```

        The reader/query side wraps `SELECT`s in the same `set_config`-first
        transaction. gormx connects with the `writer` (command) or `reader`
        (query) DSN — never `admin`.

        ### 4. Index the tenant column

        Policy predicates filter on `organization_id`, so it must be indexed.
        `staff` already ships `idx_staff_organization_id`; every new RLS table
        needs the equivalent. Confirm with `EXPLAIN (ANALYZE, BUFFERS)` that the
        policy filter uses the index.

        ### 5. Isolation test (connect as `writer`, prove cross-org returns 0)

        ```go
        // requireRLSEnforced: skip if the connected role bypasses RLS.
        var bypass bool
        require.NoError(t, db.Raw(
            "SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user",
        ).Scan(&bypass).Error)
        require.False(t, bypass, "connected role bypasses RLS; check DSN/GRANTs")

        // org A inserts a row; org B must see zero.
        var seenByB int64
        require.NoError(t, uow.DoTransaction(ctx, orgB, func(ctx context.Context, _ command.TransactionalUnitOfWork) error {
            return db.Raw("SELECT count(*) FROM staff").Scan(&seenByB).Error
        }))
        assert.Equal(t, int64(0), seenByB)
        ```

        Cover: per-org SELECT scoping, unset-GUC fails closed (0 rows),
        `WITH CHECK` rejecting a foreign-org INSERT, cross-org UPDATE/DELETE
        affecting 0 rows, and `FORCE` applying to the owner.

        ## Authoritative References

        **PostgreSQL docs (current)**
        - Row Security Policies — <https://www.postgresql.org/docs/current/ddl-rowsecurity.html>
        - `CREATE POLICY` (USING vs WITH CHECK, PERMISSIVE/RESTRICTIVE) — <https://www.postgresql.org/docs/current/sql-createpolicy.html>
        - `ALTER TABLE` (ENABLE / FORCE ROW LEVEL SECURITY) — <https://www.postgresql.org/docs/current/sql-altertable.html>
        - `CREATE ROLE` (BYPASSRLS attribute) — <https://www.postgresql.org/docs/current/sql-createrole.html>
        - `SET` / `SET LOCAL` semantics — <https://www.postgresql.org/docs/current/sql-set.html>
        - `current_setting` / `set_config` — <https://www.postgresql.org/docs/current/functions-admin.html>
        - `row_security` GUC (pg_dump escape hatch) — <https://www.postgresql.org/docs/current/runtime-config-client.html>

        **Reference Go implementations**
        - pgx UnitOfWork with `set_config(..., true)` — <https://github.com/c2siorg/genie/blob/main/pkg/storage/postgres/tenant.go>
        - GORM RLS wrapper + full isolation test suite — <https://github.com/micasa-dev/micasa/blob/main/internal/relay/rlsdb/rlsdb.go>, <https://github.com/micasa-dev/micasa/blob/main/internal/relay/rls_test.go>
        - `IMMUTABLE` policy fn + pgx prepared-statement cache footgun — <https://github.com/jackc/pgx/issues/2007>

        **This workspace**
        - Postgres roles (`admin`/`writer`/`reader`) — `packages/nix/core/services/postgres/default.nix`
        - Transaction chokepoint — `services/portal/internal/infra/postgres/uow/uow.go`
        - Migration format + role — `services/portal/internal/infra/postgres/migrations/`, run as `admin` via `migrate-up`
        - Typed UUIDv7 IDs (`TEXT` columns) — `docs/adrs/0004-typed-aggregate-ids-uuidv7.md`
      '';
    in
    lib.mkIf opts.enable {
      # Materialize the skill as a project-level SKILL.md per enabled agent.
      # devenv `files."<path>".text` writes a gitignored Nix-store symlink at
      # that path; `lib.optionalAttrs` keeps the entry absent (no empty file)
      # when the corresponding agent is disabled.
      #   - Claude Code scans `.claude/skills/<name>/SKILL.md` (plural only).
      #   - opencode scans `.opencode/skills/<name>/SKILL.md` (plural).
      files =
        (lib.optionalAttrs aiOpts.claude.enable {
          ".claude/skills/${skillName}/SKILL.md".text = skillContent;
        })
        // (lib.optionalAttrs aiOpts.opencode.enable {
          ".opencode/skills/${skillName}/SKILL.md".text = skillContent;
        });
    };
}
