package staff

import (
	"context"
	"fmt"
)

// NotFoundError indicates a Staff was not found.
//
// Returned by Reader.ByID and by Writer.Update when no row matches
// the ID. Adapters MUST return this exact type (or a wrapped error
// containing it) so callers can use errors.As.
type NotFoundError struct {
	ID ID
}

func (e NotFoundError) Error() string {
	return fmt.Sprintf("staff %q not found", string(e.ID))
}

// Writer is the write-side persistence port for Staff aggregates.
//
// CQRS keeps writes off the read path: Writer carries no query methods.
// Adapters under internal/infra/ satisfy this interface implicitly via
// Go's structural typing.
//
// Each method has one clear mission and no callback. Read-modify-write
// atomicity is the caller's responsibility, scoped through
// command.UnitOfWork.DoTransaction.
type Writer interface {
	// Create inserts a new Staff member. Returns an error if a row with
	// the same ID already exists (the underlying primary-key constraint
	// is the source of truth).
	Create(ctx context.Context, s *Staff) error

	// Update overwrites the persisted state of an existing Staff with
	// the fields from s. Returns [NotFoundError] when no row matches
	// s.ID(). The aggregate is expected to be the result of a previous
	// load + in-memory mutation; the repo does not load, mutate, or
	// re-validate.
	Update(ctx context.Context, s *Staff) error
}

// Reader is the read-side persistence port for Staff aggregates.
//
// Minimal "load by id" port for simple reads. Complex queries —
// listings, projections, cross-aggregate joins — belong in app/query/
// with their own consumer-defined interfaces returning DTOs.
type Reader interface {
	// ByID returns the staff member or [NotFoundError] when no row matches.
	ByID(ctx context.Context, id ID) (*Staff, error)
}
