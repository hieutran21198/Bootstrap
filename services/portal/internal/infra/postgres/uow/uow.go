// Package uow is the postgres-backed implementation of
// [command.UnitOfWork]. It bundles per-aggregate Writer ports behind a
// single accessor surface, so command handlers can mutate one
// aggregate (auto-commit) or several atomically (transaction) without
// ever holding a *gorm.DB or *sql.Tx.
//
// The dual-mode design — auto-commit through an inner wrapper bound to
// the root db, atomic through DoTransaction — is documented on
// [UnitOfWork].
package uow

import (
	"bootstrap/services/portal/internal/app/command"
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
	"bootstrap/services/portal/internal/infra/postgres/repo"
	"context"

	"gorm.io/gorm"
)

// txUnitOfWork is the accessor surface bound to a single *gorm.DB.
// The handle may be the root database (auto-commit) or a
// transaction-scoped one passed in by gorm.DB.Transaction. All
// accessor methods construct fresh writers against db; calling them
// inside or outside a transaction differs only in which db is held.
type txUnitOfWork struct {
	db *gorm.DB
}

// Organizations implements [command.TransactionalUnitOfWork].
func (t *txUnitOfWork) Organizations() organization.Writer {
	return repo.NewOrganizationWriter(t.db)
}

// Staffs implements [command.TransactionalUnitOfWork].
func (t *txUnitOfWork) Staffs() staff.Writer {
	return repo.NewStaffWriter(t.db)
}

var _ command.TransactionalUnitOfWork = (*txUnitOfWork)(nil)

// newTxUnitOfWork wraps db so accessor methods resolve writers against
// it. Used twice: once at construction with the root db (embedded
// into [UnitOfWork] for auto-commit calls) and once inside
// DoTransaction's gorm callback with the tx-scoped db.
func newTxUnitOfWork(db *gorm.DB) *txUnitOfWork {
	return &txUnitOfWork{
		db: db,
	}
}

// UnitOfWork is the postgres-backed [command.UnitOfWork].
//
// One accessor surface, two modes:
//
//   - Auto-commit. The embedded *txUnitOfWork is bound to the root db,
//     so uow.Organizations().Save(ctx, o) executes as a single
//     auto-committed statement.
//   - Atomic multi-aggregate. DoTransaction opens a transaction, wraps
//     a fresh *txUnitOfWork around the tx-scoped *gorm.DB, and hands
//     it to the caller's closure. Every accessor inside the closure
//     resolves against the tx; the whole closure commits or rolls
//     back as one unit.
//
// Handlers can declare exactly which mode they require by choosing
// their dependency type: [command.UnitOfWork] gives them both,
// [command.TransactionalUnitOfWork] restricts them to running inside
// an open transaction.
type UnitOfWork struct {
	db *gorm.DB
	*txUnitOfWork
}

// DoTransaction implements [command.UnitOfWork].
func (u *UnitOfWork) DoTransaction(ctx context.Context, handler func(ctx context.Context, utx command.TransactionalUnitOfWork) error) error {
	return u.db.Transaction(func(tx *gorm.DB) error {
		return handler(ctx, newTxUnitOfWork(tx))
	})
}

var _ command.UnitOfWork = (*UnitOfWork)(nil)

// New creates a new [command.UnitOfWork].
func New(db *gorm.DB) *UnitOfWork {
	return &UnitOfWork{
		db,
		newTxUnitOfWork(db),
	}
}
