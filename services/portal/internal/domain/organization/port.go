package organization

import (
	"context"
	"fmt"
)

// NotFoundError indicates an organization was not found.
//
// Returned by Reader.ByID and by Writer.Update when no row matches
// the ID. Adapters MUST return this exact type (or a wrapped error
// containing it) so callers can use errors.As.
type NotFoundError struct {
	ID ID
}

func (e NotFoundError) Error() string {
	return fmt.Sprintf("organization %q not found", string(e.ID))
}

// Writer is the write-side persistence port for Organization aggregates.
//
// CQRS keeps writes off the read path: Writer carries no query methods.
// Adapters under internal/infra/ satisfy this interface implicitly via
// Go's structural typing — no explicit declaration needed on the
// implementer side.
//
// Each method has one clear mission and no callback. Read-modify-write
// atomicity is the caller's responsibility, scoped through
// command.UnitOfWork.DoTransaction.
type Writer interface {
	// Create inserts a new Organization. Returns an error if a row with
	// the same ID already exists (the underlying primary-key constraint
	// is the source of truth).
	Create(ctx context.Context, o *Organization) error

	// Update overwrites the persisted state of an existing Organization
	// with the fields from o. Returns [NotFoundError] when no row
	// matches o.ID(). The aggregate is expected to be the result of a
	// previous load + in-memory mutation; the repo does not load,
	// mutate, or re-validate.
	Update(ctx context.Context, o *Organization) error
}

// Reader is the read-side persistence port for Organization aggregates.
//
// This is a minimal "load by id" port for simple reads that happen to
// need the aggregate shape. Complex read models — joins, projections,
// list views — belong in app/query/ where the consumer declares its
// own narrower interface returning a DTO.
type Reader interface {
	// ByID returns the organization or [NotFoundError] when no row matches.
	ByID(ctx context.Context, id ID) (*Organization, error)
}
