package repo

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	"bootstrap/services/portal/internal/domain/staff"
)

// staffRow is the GORM row model for the Staff aggregate. Internal to
// this file; callers always work with the aggregate.
type staffRow struct {
	ID             string `gorm:"primaryKey"`
	OrganizationID string `gorm:"index;not null"`
	Email          string `gorm:"index;not null"`
	FirstName      string `gorm:"not null"`
	LastName       string `gorm:"not null"`
	Role           string `gorm:"not null"`
	Deactivated    bool   `gorm:"not null;default:false"`
}

// TableName fixes the table name to "staff" — singular collective noun,
// not the plural "staffs" GORM would generate.
func (staffRow) TableName() string {
	return "staff"
}

// StaffWriter is the postgres-backed [staff.Writer].
//
// The *gorm.DB passed to NewStaffWriter decides whether writes are
// auto-commit (root DB) or part of an open transaction (tx-scoped DB
// supplied by uow.UnitOfWork.DoTransaction).
type StaffWriter struct {
	db *gorm.DB
}

// NewStaffWriter returns a writer bound to db.
func NewStaffWriter(db *gorm.DB) *StaffWriter {
	return &StaffWriter{db: db}
}

// Create inserts a new Staff member. The primary-key constraint
// rejects duplicates; the error from gorm propagates back.
func (w *StaffWriter) Create(ctx context.Context, s *staff.Staff) error {
	if s == nil {
		return errors.New("repo: create staff: nil aggregate")
	}
	row := staffToRow(s)
	if err := w.db.WithContext(ctx).Create(&row).Error; err != nil {
		return fmt.Errorf("repo: create staff %q: %w", string(s.ID()), err)
	}
	return nil
}

// Update overwrites the persisted state of an existing Staff member
// with the fields from s. Returns [staff.NotFoundError] when no row
// matches s.ID().
//
// Select("*") forces every column to be written — including zero values
// like Deactivated=false — so the row exactly mirrors the in-memory
// aggregate. Read-modify-write atomicity is the caller's job.
func (w *StaffWriter) Update(ctx context.Context, s *staff.Staff) error {
	if s == nil {
		return errors.New("repo: update staff: nil aggregate")
	}
	row := staffToRow(s)
	result := w.db.WithContext(ctx).
		Model(&staffRow{}).
		Where("id = ?", row.ID).
		Select("*").
		Updates(&row)
	if result.Error != nil {
		return fmt.Errorf("repo: update staff %q: %w", row.ID, result.Error)
	}
	if result.RowsAffected == 0 {
		return staff.NotFoundError{ID: s.ID()}
	}
	return nil
}

var _ staff.Writer = (*StaffWriter)(nil)

func staffToRow(s *staff.Staff) staffRow {
	return staffRow{
		ID:             string(s.ID()),
		OrganizationID: s.OrganizationID(),
		Email:          string(s.Email()),
		FirstName:      s.FirstName(),
		LastName:       s.LastName(),
		Role:           string(s.Role()),
		Deactivated:    s.Deactivated(),
	}
}

func rowToStaff(row staffRow) (*staff.Staff, error) {
	return staff.UnmarshalStaffFromDatabase(
		staff.ID(row.ID),
		row.OrganizationID,
		staff.Email(row.Email),
		row.FirstName,
		row.LastName,
		staff.Role(row.Role),
		row.Deactivated,
	)
}

// StaffReader is the postgres-backed [staff.Reader].
//
// The *gorm.DB passed to NewStaffReader is typically the root DB
// supplied by readstore.ReadStore. Reads are stateless and do not
// participate in transactions, so no tx-scoped variant is needed.
type StaffReader struct {
	db *gorm.DB
}

// NewStaffReader returns a reader bound to db.
func NewStaffReader(db *gorm.DB) *StaffReader {
	return &StaffReader{db: db}
}

// ByID returns the staff member with the given ID. Returns
// [staff.NotFoundError] when no row matches.
func (r *StaffReader) ByID(ctx context.Context, id staff.ID) (*staff.Staff, error) {
	var row staffRow
	if err := r.db.WithContext(ctx).First(&row, "id = ?", string(id)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, staff.NotFoundError{ID: id}
		}
		return nil, fmt.Errorf("repo: get staff %q: %w", string(id), err)
	}
	return rowToStaff(row)
}

var _ staff.Reader = (*StaffReader)(nil)
