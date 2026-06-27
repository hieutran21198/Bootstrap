// Package migrate wraps the goose migration library in an SRP-stateful
// package. It exposes a single Migrator type that runs embedded SQL
// migrations against a *sql.DB connection.
//
// Services embed their own migration files and pass the fs.FS to
// [migrate.New]. The Migrator is typically constructed at service
// startup and used to apply pending migrations before the service
// begins serving traffic.
package migrate

import (
	"context"
	"database/sql"
	"fmt"
	"io/fs"

	"github.com/pressly/goose/v3"
)

// Config holds all configuration for Migrator.
//
// DB and FS are required. Dialect selects the database driver and must
// match the underlying *sql.DB. TableName overrides the default goose
// version-tracking table ("goose_db_version"); use a per-service name
// when multiple services share a database. Verbose enables goose's
// progress logging.
type Config struct {
	DB        *sql.DB
	Dialect   goose.Dialect
	FS        fs.FS
	TableName string
	Verbose   bool
}

// Migrator runs database migrations via the goose Provider API. The
// underlying *sql.DB is not owned by Migrator — the caller is
// responsible for closing it.
type Migrator struct {
	provider *goose.Provider
}

// New constructs a Migrator from cfg. It validates the migration files
// in cfg.FS but does not perform any I/O against the database; the
// first call to Up, Down, or Status opens the version-tracking table.
func New(ctx context.Context, cfg Config) (*Migrator, error) {
	if err := ctx.Err(); err != nil {
		return nil, fmt.Errorf("migrate: new: %w", err)
	}
	if cfg.DB == nil {
		return nil, fmt.Errorf("migrate: new: DB is required")
	}
	if cfg.FS == nil {
		return nil, fmt.Errorf("migrate: new: FS is required")
	}

	opts := []goose.ProviderOption{}
	if cfg.TableName != "" {
		opts = append(opts, goose.WithTableName(cfg.TableName))
	}
	if cfg.Verbose {
		opts = append(opts, goose.WithVerbose(true))
	}

	provider, err := goose.NewProvider(cfg.Dialect, cfg.DB, cfg.FS, opts...)
	if err != nil {
		return nil, fmt.Errorf("migrate: new: %w", err)
	}
	return &Migrator{provider: provider}, nil
}

// Up applies all pending migrations. Returns the result of each
// applied migration in order.
func (m *Migrator) Up(ctx context.Context) ([]*goose.MigrationResult, error) {
	results, err := m.provider.Up(ctx)
	if err != nil {
		return nil, fmt.Errorf("migrate: up: %w", err)
	}
	return results, nil
}

// Down rolls back the most recently applied migration.
func (m *Migrator) Down(ctx context.Context) (*goose.MigrationResult, error) {
	result, err := m.provider.Down(ctx)
	if err != nil {
		return nil, fmt.Errorf("migrate: down: %w", err)
	}
	return result, nil
}

// Status returns the status of every migration known to the provider.
func (m *Migrator) Status(ctx context.Context) ([]*goose.MigrationStatus, error) {
	status, err := m.provider.Status(ctx)
	if err != nil {
		return nil, fmt.Errorf("migrate: status: %w", err)
	}
	return status, nil
}

// Close releases resources held by the underlying goose provider.
// The *sql.DB is not closed — the caller owns it.
func (m *Migrator) Close() error {
	if err := m.provider.Close(); err != nil {
		return fmt.Errorf("migrate: close: %w", err)
	}
	return nil
}
