package organization

import (
	"errors"
	"fmt"
	"strings"
)

// Sentinel errors. Wrap with fmt.Errorf("%w: ...", ErrXxx) when adding
// context; callers compare with errors.Is.
var (
	ErrEmptyID            = errors.New("organization: empty id")
	ErrEmptyName          = errors.New("organization: empty name")
	ErrNameTooLong        = errors.New("organization: name too long")
	ErrEmptyOwner         = errors.New("organization: empty owner staff id")
	ErrSameOwner          = errors.New("organization: new owner is current owner")
	ErrAlreadyDeactivated = errors.New("organization: already deactivated")
	ErrDeactivated        = errors.New("organization: deactivated")
)

const maxOrganizationNameLen = 100

// Organization is the aggregate root for a tenant in the portal.
//
// Fields are private; mutation goes through methods that enforce
// invariants. The aggregate's own identifier is the typed [ID] so it
// cannot be confused with foreign IDs at compile time. Cross-aggregate
// references — ownerStaffID — are stored as raw string to avoid the
// circular import that would arise from typing them as staff.ID (see
// id.go for the rationale).
type Organization struct {
	id           ID
	name         string
	slug         Slug
	ownerStaffID string
	deactivated  bool
}

// NewOrganization constructs a valid, active Organization or returns
// an error if any invariant is violated. id is typically produced by
// idgen.NewFor[ID](); slug must already be a validated [Slug] (use
// [NewSlug]).
func NewOrganization(id ID, name string, slug Slug, ownerStaffID string) (*Organization, error) {
	if id == "" {
		return nil, ErrEmptyID
	}

	normalisedName := strings.TrimSpace(name)
	if err := validateOrganizationName(normalisedName); err != nil {
		return nil, err
	}

	if slug == "" {
		return nil, fmt.Errorf("%w: zero-value slug", ErrInvalidSlug)
	}

	if ownerStaffID == "" {
		return nil, ErrEmptyOwner
	}

	return &Organization{
		id:           id,
		name:         normalisedName,
		slug:         slug,
		ownerStaffID: ownerStaffID,
	}, nil
}

// UnmarshalOrganizationFromDatabase rehydrates an Organization from
// persisted state. It bypasses the constructor's invariants so
// historical rows that pre-date today's rules can still be loaded.
// Use ONLY in repository adapters — never in command handlers.
func UnmarshalOrganizationFromDatabase(
	id ID,
	name string,
	slug Slug,
	ownerStaffID string,
	deactivated bool,
) (*Organization, error) {
	if id == "" {
		return nil, ErrEmptyID
	}
	return &Organization{
		id:           id,
		name:         name,
		slug:         slug,
		ownerStaffID: ownerStaffID,
		deactivated:  deactivated,
	}, nil
}

// Getters use value receivers — Organization is small and copying is cheap.

// ID returns the organization's typed identifier.
func (o Organization) ID() ID { return o.id }

// Name returns the organization's display name.
func (o Organization) Name() string { return o.name }

// Slug returns the URL-safe slug.
func (o Organization) Slug() Slug { return o.slug }

// OwnerStaffID returns the ID of the Staff aggregate that owns this
// organization. Returned as a raw string — typed staff.ID is not used
// here to avoid a circular import between sibling domain packages
// (see id.go).
func (o Organization) OwnerStaffID() string { return o.ownerStaffID }

// Deactivated reports whether the organization has been deactivated.
func (o Organization) Deactivated() bool { return o.deactivated }

// Rename changes the display name. Returns ErrDeactivated if the
// organization is deactivated, ErrEmptyName / ErrNameTooLong on bad input.
func (o *Organization) Rename(newName string) error {
	if o.deactivated {
		return ErrDeactivated
	}
	normalised := strings.TrimSpace(newName)
	if err := validateOrganizationName(normalised); err != nil {
		return err
	}
	o.name = normalised
	return nil
}

// TransferOwnership moves ownership to another staff ID. Refuses if
// deactivated, if newOwnerStaffID is empty, or if it equals the
// current owner.
func (o *Organization) TransferOwnership(newOwnerStaffID string) error {
	if o.deactivated {
		return ErrDeactivated
	}
	if newOwnerStaffID == "" {
		return ErrEmptyOwner
	}
	if newOwnerStaffID == o.ownerStaffID {
		return ErrSameOwner
	}
	o.ownerStaffID = newOwnerStaffID
	return nil
}

// Deactivate marks the organization inactive. Idempotent calls are
// rejected: re-deactivating returns ErrAlreadyDeactivated so callers
// can distinguish "no-op" from "first deactivation".
func (o *Organization) Deactivate() error {
	if o.deactivated {
		return ErrAlreadyDeactivated
	}
	o.deactivated = true
	return nil
}

func validateOrganizationName(name string) error {
	if name == "" {
		return ErrEmptyName
	}
	if len(name) > maxOrganizationNameLen {
		return fmt.Errorf("%w: %d > %d", ErrNameTooLong, len(name), maxOrganizationNameLen)
	}
	return nil
}
