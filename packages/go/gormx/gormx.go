// Package gormx wraps *gorm.DB with connection-pool tuning and a
// context-checked ping at construction. Single-responsibility per
// packages/go/AGENTS.md: one Config, one target (Gormx), one constructor
// (New).
package gormx

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// ErrDialectorRequired is returned when Config.Dialector is nil.
var ErrDialectorRequired = errors.New("gormx: Dialector is required")

// Config holds gorm initialization options and database/sql pool settings.
// The Dialector is mandatory; the rest receive defaults in New.
type Config struct {
	Dialector       gorm.Dialector // required; obtain from gormx/postgres or gormx/sqlite
	GormConfig      *gorm.Config   // optional gorm.Config; default &gorm.Config{}
	MaxOpenConns    int            // default 25
	MaxIdleConns    int            // default 5
	ConnMaxLifetime time.Duration  // default 30m
	ConnMaxIdleTime time.Duration  // default 5m
}

// Gormx owns the gorm.DB and the underlying *sql.DB lifecycle.
type Gormx struct {
	cfg Config
	db  *gorm.DB
}

// New opens the connection through the configured dialector, applies
// the pool settings, and verifies reachability with ctx-checked Ping.
func New(ctx context.Context, cfg Config) (*Gormx, error) {
	if cfg.Dialector == nil {
		return nil, ErrDialectorRequired
	}
	cfg = applyDefaults(cfg)

	db, err := gorm.Open(cfg.Dialector, cfg.GormConfig)
	if err != nil {
		return nil, fmt.Errorf("gormx: open: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("gormx: get *sql.DB: %w", err)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(cfg.ConnMaxLifetime)
	sqlDB.SetConnMaxIdleTime(cfg.ConnMaxIdleTime)

	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("gormx: ping: %w", err)
	}

	return &Gormx{cfg: cfg, db: db}, nil
}

// DB returns the underlying *gorm.DB. Callers should derive ctx-bound handles
// with `g.DB().WithContext(ctx)` for query-scoped cancellation.
func (g *Gormx) DB() *gorm.DB { return g.db }

// Close releases the underlying *sql.DB connection pool.
func (g *Gormx) Close() error {
	sqlDB, err := g.db.DB()
	if err != nil {
		return fmt.Errorf("gormx: close: %w", err)
	}
	return sqlDB.Close()
}

func applyDefaults(cfg Config) Config {
	if cfg.GormConfig == nil {
		cfg.GormConfig = &gorm.Config{}
	}
	if cfg.MaxOpenConns == 0 {
		cfg.MaxOpenConns = 25
	}
	if cfg.MaxIdleConns == 0 {
		cfg.MaxIdleConns = 5
	}
	if cfg.ConnMaxLifetime == 0 {
		cfg.ConnMaxLifetime = 30 * time.Minute
	}
	if cfg.ConnMaxIdleTime == 0 {
		cfg.ConnMaxIdleTime = 5 * time.Minute
	}
	return cfg
}
