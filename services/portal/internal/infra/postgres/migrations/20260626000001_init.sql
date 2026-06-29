-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS organizations (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    owner_staff_id  TEXT NOT NULL,
    deactivated     BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_organizations_owner_staff_id
    ON organizations (owner_staff_id);

CREATE TABLE IF NOT EXISTS staff (
    id              TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    email           TEXT NOT NULL,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    role            TEXT NOT NULL,
    deactivated     BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_staff_organization_id
    ON staff (organization_id);

-- One ACTIVE staff member per email per organization. Scoped to the
-- tenant (organization_id) because the same person may legitimately work
-- for more than one organization; partial (WHERE NOT deactivated) so an
-- email frees up once its holder is deactivated and can be re-hired.
CREATE UNIQUE INDEX IF NOT EXISTS uq_staff_active_org_email
    ON staff (organization_id, email)
    WHERE NOT deactivated;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS organizations;
-- +goose StatementEnd
