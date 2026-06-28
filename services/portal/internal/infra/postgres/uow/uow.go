// Package uow is the postgres-backed implementation of
// [command.UnitOfWork]. It bundles per-aggregate Writer ports behind a
// single accessor surface, so command handlers can mutate one or
// several aggregates atomically without ever holding a *gorm.DB or
// *sql.Tx.
//
// Every write runs inside a tenant-scoped transaction opened by
// DoOrganizationTransaction: the organization id is validated and bound
// to the connection via Row-Level Security
// (set_config('app.organization_id', …, true)) before the caller's
// closure runs, so each writer is automatically filtered to that one
// organization. The design is documented on [UnitOfWork].
package uow

import (
	"bootstrap/packages/go/idgen"
	"bootstrap/services/portal/internal/app/command"
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
	"bootstrap/services/portal/internal/infra/postgres/repo"
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

// txUnitOfWork is the accessor surface bound to a single *gorm.DB.
// The handle is normally the tenant-scoped, RLS-bound transaction
// passed in by DoOrganizationTransaction; the root-db instance embedded
// in [UnitOfWork] exists only to satisfy the accessor surface at
// construction. All accessor methods construct fresh writers against db.
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
// it. Used twice: once at construction with the root db (embedded into
// [UnitOfWork] so the struct satisfies the accessor surface) and once
// inside DoOrganizationTransaction's gorm callback with the tx-scoped,
// RLS-bound db that handlers actually use.
func newTxUnitOfWork(db *gorm.DB) *txUnitOfWork {
	return &txUnitOfWork{
		db: db,
	}
}

// UnitOfWork is the postgres-backed [command.UnitOfWork].
//
// All writes go through DoOrganizationTransaction, which opens a
// transaction, validates the organization id, binds it to the
// connection via Row-Level Security, wraps a fresh *txUnitOfWork around
// the tx-scoped *gorm.DB, and hands it to the caller's closure. Every
// accessor inside the closure resolves against that RLS-bound tx; the
// whole closure commits or rolls back as one unit.
//
// The embedded *txUnitOfWork (bound to the root db) exists only so the
// struct satisfies the accessor surface at construction; handlers never
// reach it directly — they receive a tenant-scoped *txUnitOfWork from
// the transaction callback instead. There is no org-less auto-commit
// path: RLS requires every write to be organization-scoped (the
// org-less DoTransaction below is commented out for non-multi-tenant
// systems only).
type UnitOfWork struct {
	db *gorm.DB
	*txUnitOfWork
}

// ErrOrganizationRLSCannotBeBound indicates the organization could not
// be bound to the transaction's Row-Level Security scope (the
// set_config call failed). The wrapped cause carries the driver error.
var ErrOrganizationRLSCannotBeBound = errors.New("organization RLS scope cannot be bound")

// DoOrganizationTransaction implements [command.UnitOfWork].
func (u *UnitOfWork) DoOrganizationTransaction(ctx context.Context, id organization.ID, handler command.TransactionalUnitOfWorkHandler) error {
	return u.db.Transaction(func(tx *gorm.DB) error {
		if err := idgen.Validate(id); err != nil {
			return organization.ErrEmptyID
		}
		if err := bindOrganizationRLS(ctx, tx, id); err != nil {
			return err
		}
		return handler(ctx, newTxUnitOfWork(tx))
	})
}

// bindOrganizationRLS binds an organization to the given transaction.
func bindOrganizationRLS(ctx context.Context, tx *gorm.DB, id organization.ID) error {
	if err := tx.WithContext(ctx).Exec(`select set_config('app.organization_id', ?, true)`, id.String()).Error; err != nil {
		return fmt.Errorf("%w: %w", ErrOrganizationRLSCannotBeBound, err)
	}

	return nil
}

// WARN: Enable DoTransaction if our system is not a multi-tenants platform;
// not required RLS.
//
// DoTransaction implements [command.UnitOfWork].
// func (u *UnitOfWork) DoTransaction(ctx context.Context, handler func(ctx context.Context, utx command.TransactionalUnitOfWork) error) error {
// 	return u.db.Transaction(func(tx *gorm.DB) error {
// 		return handler(ctx, newTxUnitOfWork(tx))
// 	})
// }

var _ command.UnitOfWork = (*UnitOfWork)(nil)

// New creates a new [command.UnitOfWork].
func New(db *gorm.DB) *UnitOfWork {
	return &UnitOfWork{
		db,
		newTxUnitOfWork(db),
	}
}
