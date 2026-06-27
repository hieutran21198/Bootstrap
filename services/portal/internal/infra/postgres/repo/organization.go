// Package repo contains GORM-backed implementations of the domain
// repository ports. Each writer or reader is constructed with a
// *gorm.DB which may be the root DB (auto-commit mode) or a
// transaction-scoped DB (provided by uow.UnitOfWork.DoTransaction).
package repo

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	"bootstrap/services/portal/internal/domain/organization"
)

// organizationRow is the GORM row model. It mirrors the Organization
// aggregate's fields without leaking any ORM tag into the domain. The
// row type is internal to this file; callers always work with the
// aggregate.
type organizationRow struct {
	ID           string `gorm:"primaryKey"`
	Name         string `gorm:"not null"`
	Slug         string `gorm:"uniqueIndex;not null"`
	OwnerStaffID string `gorm:"index;not null"`
	Deactivated  bool   `gorm:"not null;default:false"`
}

// TableName overrides GORM's default plural conversion so the table
// name is stable even if the unexported struct name changes later.
func (organizationRow) TableName() string {
	return "organizations"
}

// OrganizationWriter is the postgres-backed [organization.Writer].
//
// The *gorm.DB passed to NewOrganizationWriter decides whether writes
// are auto-commit (root DB) or part of an open transaction
// (tx-scoped DB supplied by uow.UnitOfWork.DoTransaction). The struct
// itself is unaware of which mode it is in.
type OrganizationWriter struct {
	db *gorm.DB
}

// NewOrganizationWriter returns a writer bound to db.
func NewOrganizationWriter(db *gorm.DB) *OrganizationWriter {
	return &OrganizationWriter{db: db}
}

// Create inserts a new Organization. The primary-key constraint
// rejects duplicates; the error from gorm propagates back.
func (w *OrganizationWriter) Create(ctx context.Context, o *organization.Organization) error {
	if o == nil {
		return errors.New("repo: create organization: nil aggregate")
	}
	row := organizationToRow(o)
	if err := w.db.WithContext(ctx).Create(&row).Error; err != nil {
		return fmt.Errorf("repo: create organization %q: %w", string(o.ID()), err)
	}
	return nil
}

// Update overwrites the persisted state of an existing Organization
// with the fields from o. Returns [organization.NotFoundError] when no
// row matches o.ID().
//
// Select("*") forces every column to be written — including zero values
// like Deactivated=false — so the row exactly mirrors the in-memory
// aggregate. Read-modify-write atomicity is the caller's job; the repo
// performs a single UPDATE statement.
func (w *OrganizationWriter) Update(ctx context.Context, o *organization.Organization) error {
	if o == nil {
		return errors.New("repo: update organization: nil aggregate")
	}
	row := organizationToRow(o)
	result := w.db.WithContext(ctx).
		Model(&organizationRow{}).
		Where("id = ?", row.ID).
		Select("*").
		Updates(&row)
	if result.Error != nil {
		return fmt.Errorf("repo: update organization %q: %w", row.ID, result.Error)
	}
	if result.RowsAffected == 0 {
		return organization.NotFoundError{ID: o.ID()}
	}
	return nil
}

var _ organization.Writer = (*OrganizationWriter)(nil)

func organizationToRow(o *organization.Organization) organizationRow {
	return organizationRow{
		ID:           string(o.ID()),
		Name:         o.Name(),
		Slug:         string(o.Slug()),
		OwnerStaffID: o.OwnerStaffID(),
		Deactivated:  o.Deactivated(),
	}
}

func rowToOrganization(row organizationRow) (*organization.Organization, error) {
	return organization.UnmarshalOrganizationFromDatabase(
		organization.ID(row.ID),
		row.Name,
		organization.Slug(row.Slug),
		row.OwnerStaffID,
		row.Deactivated,
	)
}

// OrganizationReader is the postgres-backed [organization.Reader].
//
// The *gorm.DB passed to NewOrganizationReader is typically the root
// DB supplied by readstore.ReadStore. Reads are stateless and do not
// participate in transactions, so no tx-scoped variant is needed.
type OrganizationReader struct {
	db *gorm.DB
}

// NewOrganizationReader returns a reader bound to db.
func NewOrganizationReader(db *gorm.DB) *OrganizationReader {
	return &OrganizationReader{db: db}
}

// ByID returns the organization with the given ID. Returns
// [organization.NotFoundError] when no row matches.
func (r *OrganizationReader) ByID(ctx context.Context, id organization.ID) (*organization.Organization, error) {
	var row organizationRow
	if err := r.db.WithContext(ctx).First(&row, "id = ?", string(id)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, organization.NotFoundError{ID: id}
		}
		return nil, fmt.Errorf("repo: get organization %q: %w", string(id), err)
	}
	return rowToOrganization(row)
}

var _ organization.Reader = (*OrganizationReader)(nil)
