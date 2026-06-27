// Package idgen generates typed string IDs using UUIDv7.
//
// UUIDv7 IDs are k-sortable and embed the creation timestamp, which
// makes them suitable as database primary keys. The generic type
// parameter returns a domain-specific typed ID rather than a raw
// string, preventing accidental cross-aggregate ID swaps at compile
// time: a value generated for organization.ID cannot be passed to a
// function expecting staff.ID.
//
// This is a stateless package: its API is pure functions and types,
// not a constructable target. See
// docs/conventions/go/single-responsibility.md for the category
// description.
package idgen

import (
	"fmt"

	"github.com/google/uuid"
)

// StringID is the type constraint for typed string IDs. Any named
// string type qualifies — typically declared per-aggregate as
// `type ID string`.
type StringID interface {
	~string
}

// NewFor generates a UUIDv7-backed typed ID.
//
// Example:
//
//	orgID := idgen.NewFor[organization.ID]()
//	staffID := idgen.NewFor[staff.ID]()
//
// Panics if the OS random source fails — a condition that indicates
// system-level failure and cannot be meaningfully recovered from.
func NewFor[T StringID]() T {
	return T(uuid.Must(uuid.NewV7()).String())
}

// Validate checks that id is a well-formed UUIDv7 string produced by
// this package.
//
// Returns nil for a valid ID. Returns a non-nil error when the string
// is not a parseable UUID, or when it parses to a UUID of any version
// other than 7.
//
// Use at system boundaries (HTTP handlers, queue consumers, CLI args)
// to reject malformed IDs before they reach domain logic. Inside the
// domain layer, trust the typed ID — it has already crossed this gate.
//
// Example:
//
//	if err := idgen.Validate(staff.ID(raw)); err != nil {
//	    return fmt.Errorf("invalid staff id: %w", err)
//	}
func Validate[T StringID](id T) error {
	parsed, err := uuid.Parse(string(id))
	if err != nil {
		return fmt.Errorf("idgen: validate: %w", err)
	}
	if parsed.Version() != 7 {
		return fmt.Errorf("idgen: validate: UUID v%d, want v7", parsed.Version())
	}
	return nil
}
