// Package sqlite provides a gorm sqlite dialector backed by
// github.com/glebarez/sqlite (which wraps modernc.org/sqlite — pure Go,
// no CGO). Pair the returned Dialector with gormx.New.
// Single-responsibility per packages/go/AGENTS.md.
package sqlite

import (
	gormsqlite "github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

// Config controls the sqlite DSN. Use ":memory:" for an in-process database,
// "file:/abs/path.db?cache=shared" for a shared file-backed one, or any
// modernc.org/sqlite DSN.
type Config struct {
	DSN string
}

// Sqlite holds the constructed gorm.Dialector.
type Sqlite struct {
	cfg       Config
	dialector gorm.Dialector
}

// New constructs the dialector. No I/O occurs here; the file is opened
// later when the dialector is passed to gormx.New.
func New(cfg Config) *Sqlite {
	return &Sqlite{
		cfg:       cfg,
		dialector: gormsqlite.Open(cfg.DSN),
	}
}

// Dialector returns the gorm.Dialector to feed into gormx.Config.
func (s *Sqlite) Dialector() gorm.Dialector { return s.dialector }
