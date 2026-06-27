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

CREATE INDEX IF NOT EXISTS idx_staff_email
    ON staff (email);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS organizations;
-- +goose StatementEnd
