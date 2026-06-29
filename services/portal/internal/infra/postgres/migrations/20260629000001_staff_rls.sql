-- +goose Up
-- +goose StatementBegin
-- Row-Level Security for the staff aggregate.
--
-- staff is org-scoped (organization_id NOT NULL), so RLS is the authority
-- for tenant isolation (ADR-0008). Two scopes share one axis:
--   - organization: tenant-facing writer/reader, bound app.organization_id.
--   - system:       cross-tenant system_reader, bound app.scope='system' plus
--                   an org allowlist (ADR-0009). system widens visibility via
--                   a SEPARATE role + SEPARATE policy — it never reuses the
--                   writer/reader policy and never bypasses RLS.
--
-- FORCE applies the policy even to the table owner; ENABLE alone exempts it.
-- An unbound transaction matches no policy branch and fails closed (0 rows).
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff FORCE ROW LEVEL SECURITY;

-- organization scope: tenant-facing writer/reader see exactly one org's rows.
-- The predicate reads app.organization_id (missing_ok=true → NULL when unset →
-- organization_id = NULL is unknown → row denied, i.e. fail closed). Both USING
-- (visibility) and WITH CHECK (writes) are stated so a writer cannot forge a
-- row for another org.
CREATE POLICY tenant_isolation_staff ON staff
    AS PERMISSIVE
    FOR ALL
    TO writer, reader
    USING      (organization_id = current_setting('app.organization_id', true))
    WITH CHECK (organization_id = current_setting('app.organization_id', true));

-- system scope (read-only, ADR-0009): the dedicated system_reader role sees
-- across organizations, but still NOBYPASSRLS and still bounded — by an
-- explicit org allowlist GUC. app.organization_allowlist is either '*'
-- (all orgs, an explicit choice) or a comma-separated list of organization
-- ids. A MISSING allowlist returns NULL → neither branch matches → 0 rows
-- (fail closed; "all tenants" is never an implicit default). The tenant-facing
-- writer/reader roles deliberately have NO system policy branch, so setting
-- app.scope='system' on a tenant connection matches nothing and fails closed.
CREATE POLICY system_read_staff ON staff
    AS PERMISSIVE
    FOR SELECT
    TO system_reader
    USING (
        current_setting('app.scope', true) = 'system'
        AND (
            current_setting('app.organization_allowlist', true) = '*'
            OR organization_id = ANY (
                string_to_array(current_setting('app.organization_allowlist', true), ',')
            )
        )
    );
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP POLICY IF EXISTS system_read_staff ON staff;
DROP POLICY IF EXISTS tenant_isolation_staff ON staff;
ALTER TABLE staff NO FORCE ROW LEVEL SECURITY;
ALTER TABLE staff DISABLE ROW LEVEL SECURITY;
-- +goose StatementEnd
