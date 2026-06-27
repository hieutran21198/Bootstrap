// Package postgres contains the portal service's postgres infrastructure:
// migration embedding, repository implementations, unit-of-work, and
// read store. This file owns the migration embedding and migrator
// constructor; the subpackages (repo, uow, readstore) own the rest.
package postgres

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"

	"github.com/pressly/goose/v3"

	"bootstrap/packages/go/migrate"
)

// migrationFS embeds all .sql migration files in the migrations
// directory. The embed directive is relative to this file, so the
// migrations subdirectory must sit alongside migrate.go.
//
//go:embed migrations/*.sql
var migrationFS embed.FS

// NewMigrator creates a [migrate.Migrator] for the portal service
// database. The caller owns the *sql.DB and is responsible for
// closing it after the migrator is no longer needed.
func NewMigrator(ctx context.Context, db *sql.DB) (*migrate.Migrator, error) {
	fsys, err := fs.Sub(migrationFS, "migrations")
	if err != nil {
		return nil, fmt.Errorf("postgres: new migrator: %w", err)
	}
	return migrate.New(ctx, migrate.Config{
		DB:      db,
		Dialect: goose.DialectPostgres,
		FS:      fsys,
	})
}
