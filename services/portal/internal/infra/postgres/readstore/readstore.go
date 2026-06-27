// Package readstore is the postgres-backed implementation of
// [query.ReadStore]. It bundles per-aggregate Reader ports behind a
// single accessor surface, so query handlers can load aggregates
// without ever holding a *gorm.DB.
//
// Reads do not require transactional boundaries, so the implementation
// is a single struct bound to the root db — there is no dual-mode
// design here, unlike [uow.UnitOfWork] on the write side.
package readstore

import (
	"bootstrap/services/portal/internal/app/query"
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
	"bootstrap/services/portal/internal/infra/postgres/repo"

	"gorm.io/gorm"
)

// ReadStore is the postgres-backed [query.ReadStore].
//
// Each accessor method constructs a fresh reader against the held
// *gorm.DB. Because reads are stateless and idempotent, there is no
// need for a transaction-scoped variant — the same db serves every
// call.
type ReadStore struct {
	db *gorm.DB
}

// Organizations implements [query.ReadStore].
func (r *ReadStore) Organizations() organization.Reader {
	return repo.NewOrganizationReader(r.db)
}

// Staffs implements [query.ReadStore].
func (r *ReadStore) Staffs() staff.Reader {
	return repo.NewStaffReader(r.db)
}

var _ query.ReadStore = (*ReadStore)(nil)

// New creates a new [query.ReadStore].
func New(db *gorm.DB) *ReadStore {
	return &ReadStore{
		db: db,
	}
}
