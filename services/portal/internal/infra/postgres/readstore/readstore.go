// Package readstore is the postgres-backed implementation of
// [query.ReadStore]. It bundles per-aggregate Reader ports behind a
// single accessor surface, so query handlers can load aggregates
// without ever holding a *gorm.DB.
//
// Every read runs inside a tenant-scoped transaction opened by
// DoOrganizationQuery: the organization id is validated and bound to
// the connection via Row-Level Security
// (set_config('app.organization_id', …, true)) before the caller's
// closure runs, so each reader is automatically filtered to that one
// organization. This mirrors [uow.UnitOfWork] on the write side — an
// unbound read fails closed (zero rows) against a FORCEd policy.
package readstore

import (
	"bootstrap/packages/go/idgen"
	"bootstrap/services/portal/internal/app/query"
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
	"bootstrap/services/portal/internal/infra/postgres/repo"
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

// txReadStore is the accessor surface bound to a single *gorm.DB. The
// handle is the tenant-scoped, RLS-bound transaction passed in by
// DoOrganizationQuery; the root-db instance embedded in [ReadStore]
// exists only to satisfy the accessor surface at construction. All
// accessor methods construct fresh readers against db.
type txReadStore struct {
	db *gorm.DB
}

// Organizations implements [query.TransactionalReadStore].
func (t *txReadStore) Organizations() organization.Reader {
	return repo.NewOrganizationReader(t.db)
}

// Staffs implements [query.TransactionalReadStore].
func (t *txReadStore) Staffs() staff.Reader {
	return repo.NewStaffReader(t.db)
}

var _ query.TransactionalReadStore = (*txReadStore)(nil)

// newTxReadStore wraps db so accessor methods resolve readers against
// it. Used twice: once at construction with the root db (embedded into
// [ReadStore] so the struct satisfies the accessor surface) and once
// inside DoOrganizationQuery's gorm callback with the tx-scoped,
// RLS-bound db that handlers actually use.
func newTxReadStore(db *gorm.DB) *txReadStore {
	return &txReadStore{
		db: db,
	}
}

// ReadStore is the postgres-backed [query.ReadStore].
//
// All reads go through DoOrganizationQuery, which opens a transaction,
// validates the organization id, binds it to the connection via
// Row-Level Security, wraps a fresh *txReadStore around the tx-scoped
// *gorm.DB, and hands it to the caller's closure. Every accessor inside
// the closure resolves against that RLS-bound tx.
//
// The embedded *txReadStore (bound to the root db) exists only so the
// struct satisfies the accessor surface at construction; handlers never
// reach it directly — they receive a tenant-scoped *txReadStore from the
// query callback instead. There is no org-less read path: RLS requires
// every read to be organization-scoped.
type ReadStore struct {
	db *gorm.DB
	*txReadStore
}

// ErrOrganizationRLSCannotBeBound indicates the organization could not
// be bound to the transaction's Row-Level Security scope (the
// set_config call failed). The wrapped cause carries the driver error.
var ErrOrganizationRLSCannotBeBound = errors.New("organization RLS scope cannot be bound")

// DoOrganizationQuery implements [query.ReadStore].
func (r *ReadStore) DoOrganizationQuery(ctx context.Context, id organization.ID, handler query.TransactionalReadStoreHandler) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := idgen.Validate(id); err != nil {
			return organization.ErrEmptyID
		}
		if err := bindOrganizationRLS(ctx, tx, id); err != nil {
			return err
		}
		return handler(ctx, newTxReadStore(tx))
	})
}

// bindOrganizationRLS binds an organization to the given transaction.
func bindOrganizationRLS(ctx context.Context, tx *gorm.DB, id organization.ID) error {
	if err := tx.WithContext(ctx).Exec(`select set_config('app.organization_id', ?, true)`, id.String()).Error; err != nil {
		return fmt.Errorf("%w: %w", ErrOrganizationRLSCannotBeBound, err)
	}

	return nil
}

var _ query.ReadStore = (*ReadStore)(nil)

// New creates a new [query.ReadStore].
func New(db *gorm.DB) *ReadStore {
	return &ReadStore{
		db,
		newTxReadStore(db),
	}
}
