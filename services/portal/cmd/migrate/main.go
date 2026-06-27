// Package main implements the portal service migration CLI. It wraps
// the shared [migrate] package and the portal's embedded migrations
// behind a small command interface: up, down, status.
//
// The CLI reads structural connection parameters from environment
// variables (set by the shared postgres devenv module):
//
//	POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DATABASE,
//	POSTGRES_ADMIN_USER, POSTGRES_ADMIN_PASSWORD
//
// Usage:
//
//	go run ./cmd/migrate up
package main

import (
	"context"
	"database/sql"
	"fmt"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"

	"bootstrap/packages/go/migrate"
	"bootstrap/services/portal/internal/infra/postgres"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "migrate: %v\n", err)
		os.Exit(1)
	}
}

// pgConfig holds the structural connection parameters read from env vars.
type pgConfig struct {
	Host     string
	Port     string
	Database string
	User     string
	Password string
}

// dsn builds a PostgreSQL connection string from structural parameters.
func (c pgConfig) dsn() string {
	return fmt.Sprintf(
		"postgresql://%s:%s@%s:%s/%s?sslmode=disable",
		c.User, c.Password, c.Host, c.Port, c.Database,
	)
}

// loadPgConfig reads structural connection env vars, applying defaults
// for local development when they are unset.
func loadPgConfig() pgConfig {
	cfg := pgConfig{
		Host:     envOr("POSTGRES_HOST", "localhost"),
		Port:     envOr("POSTGRES_PORT", "5432"),
		Database: envOr("POSTGRES_DATABASE", "portal"),
		User:     envOr("POSTGRES_ADMIN_USER", "admin"),
		Password: envOr("POSTGRES_ADMIN_PASSWORD", "admin"),
	}
	return cfg
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func run(args []string) error {
	cfg := loadPgConfig()

	db, err := sql.Open("pgx", cfg.dsn())
	if err != nil {
		return fmt.Errorf("open database: %w", err)
	}
	defer func() { _ = db.Close() }()

	pingErr := db.Ping()
	if pingErr != nil {
		return fmt.Errorf("ping database: %w", pingErr)
	}

	m, err := postgres.NewMigrator(context.Background(), db)
	if err != nil {
		return fmt.Errorf("new migrator: %w", err)
	}
	defer func() { _ = m.Close() }()

	cmd := "status"
	if len(args) > 0 {
		cmd = args[0]
	}

	ctx := context.Background()
	return execCommand(ctx, m, cmd)
}

func execCommand(ctx context.Context, m *migrate.Migrator, cmd string) error {
	switch cmd {
	case "up":
		return migrateUp(ctx, m)
	case "down":
		return migrateDown(ctx, m)
	case "status":
		return migrateStatus(ctx, m)
	default:
		return fmt.Errorf("unknown command %q: usage: migrate [up|down|status]", cmd)
	}
}

func migrateUp(ctx context.Context, m *migrate.Migrator) error {
	results, err := m.Up(ctx)
	if err != nil {
		return fmt.Errorf("up: %w", err)
	}
	if len(results) == 0 {
		fmt.Println("No pending migrations.")
		return nil
	}
	for _, r := range results {
		fmt.Printf("Applied: %s\n", r.Source.Path)
	}
	return nil
}

func migrateDown(ctx context.Context, m *migrate.Migrator) error {
	result, err := m.Down(ctx)
	if err != nil {
		return fmt.Errorf("down: %w", err)
	}
	if result != nil {
		fmt.Printf("Rolled back: %s\n", result.Source.Path)
	}
	return nil
}

func migrateStatus(ctx context.Context, m *migrate.Migrator) error {
	statuses, err := m.Status(ctx)
	if err != nil {
		return fmt.Errorf("status: %w", err)
	}
	if len(statuses) == 0 {
		fmt.Println("No migrations found.")
		return nil
	}
	fmt.Printf("%-40s  %-10s  %s\n", "MIGRATION", "STATE", "APPLIED AT")
	for _, s := range statuses {
		applied := "-"
		if !s.AppliedAt.IsZero() {
			applied = s.AppliedAt.Format("2006-01-02 15:04:05")
		}
		fmt.Printf("%-40s  %-10s  %s\n", s.Source.Path, s.State, applied)
	}
	return nil
}
