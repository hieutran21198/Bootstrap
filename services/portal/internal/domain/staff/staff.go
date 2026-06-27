package staff

import (
	"errors"
	"fmt"
	"strings"
)

// Sentinel errors. Wrap with fmt.Errorf("%w: ...", ErrXxx) when adding
// context; callers compare with errors.Is.
var (
	ErrEmptyID            = errors.New("staff: empty id")
	ErrEmptyOrganization  = errors.New("staff: empty organization id")
	ErrEmptyFirstName     = errors.New("staff: empty first name")
	ErrEmptyLastName      = errors.New("staff: empty last name")
	ErrNameTooLong        = errors.New("staff: name too long")
	ErrSameOrganization   = errors.New("staff: already in this organization")
	ErrAlreadyDeactivated = errors.New("staff: already deactivated")
	ErrDeactivated        = errors.New("staff: deactivated")
)

const maxNameLen = 100

// Staff is the aggregate root for an employed person inside an
// Organization. Fields are private; mutation goes through methods that
// enforce invariants. The aggregate's own identifier is the typed
// [ID]; cross-aggregate references — organizationID — are stored as
// raw string to avoid the circular import that would arise from
// typing them as organization.ID (see id.go for the rationale).
type Staff struct {
	id             ID
	organizationID string
	email          Email
	firstName      string
	lastName       string
	role           Role
	deactivated    bool
}

// Hire constructs a new active Staff member. The factory enforces all
// invariants; id is typically produced by idgen.NewFor[ID]().
//
// email and role MUST already be validated value objects (use
// [NewEmail] and [NewRole]). Passing their zero values returns an
// error wrapping ErrInvalidEmail / ErrInvalidRole.
func Hire(
	id ID,
	organizationID string,
	email Email,
	firstName, lastName string,
	role Role,
) (*Staff, error) {
	if id == "" {
		return nil, ErrEmptyID
	}
	if organizationID == "" {
		return nil, ErrEmptyOrganization
	}
	if email == "" {
		return nil, fmt.Errorf("%w: zero-value email", ErrInvalidEmail)
	}
	if role == "" {
		return nil, fmt.Errorf("%w: zero-value role", ErrInvalidRole)
	}

	first := strings.TrimSpace(firstName)
	if err := validatePersonalName(first, ErrEmptyFirstName); err != nil {
		return nil, err
	}
	last := strings.TrimSpace(lastName)
	if err := validatePersonalName(last, ErrEmptyLastName); err != nil {
		return nil, err
	}

	return &Staff{
		id:             id,
		organizationID: organizationID,
		email:          email,
		firstName:      first,
		lastName:       last,
		role:           role,
	}, nil
}

// UnmarshalStaffFromDatabase rehydrates a Staff from persisted state.
// It bypasses the constructor's invariants so historical rows that
// pre-date today's rules can still be loaded. Use ONLY in repository
// adapters — never in command handlers.
func UnmarshalStaffFromDatabase(
	id ID,
	organizationID string,
	email Email,
	firstName, lastName string,
	role Role,
	deactivated bool,
) (*Staff, error) {
	if id == "" {
		return nil, ErrEmptyID
	}
	return &Staff{
		id:             id,
		organizationID: organizationID,
		email:          email,
		firstName:      firstName,
		lastName:       lastName,
		role:           role,
		deactivated:    deactivated,
	}, nil
}

// Getters use value receivers — Staff is small and copying is cheap.

// ID returns the staff member's typed identifier.
func (s Staff) ID() ID { return s.id }

// OrganizationID returns the ID of the Organization the staff member
// belongs to. Returned as a raw string — typed organization.ID is not
// used here to avoid a circular import between sibling domain
// packages (see id.go).
func (s Staff) OrganizationID() string { return s.organizationID }

// Email returns the validated email.
func (s Staff) Email() Email { return s.email }

// FirstName returns the staff member's first name.
func (s Staff) FirstName() string { return s.firstName }

// LastName returns the staff member's last name.
func (s Staff) LastName() string { return s.lastName }

// Role returns the staff member's role.
func (s Staff) Role() Role { return s.role }

// Deactivated reports whether the staff member has been deactivated.
func (s Staff) Deactivated() bool { return s.deactivated }

// ChangeRole sets a new role. Rejects zero-value role and deactivated staff.
func (s *Staff) ChangeRole(newRole Role) error {
	if s.deactivated {
		return ErrDeactivated
	}
	if newRole == "" {
		return fmt.Errorf("%w: zero-value role", ErrInvalidRole)
	}
	s.role = newRole
	return nil
}

// ChangeEmail sets a new email. Rejects zero-value email and deactivated staff.
func (s *Staff) ChangeEmail(newEmail Email) error {
	if s.deactivated {
		return ErrDeactivated
	}
	if newEmail == "" {
		return fmt.Errorf("%w: zero-value email", ErrInvalidEmail)
	}
	s.email = newEmail
	return nil
}

// TransferToOrganization moves the staff member to another organization.
// Rejects empty ID, same-organization transfer, and deactivated staff.
func (s *Staff) TransferToOrganization(newOrganizationID string) error {
	if s.deactivated {
		return ErrDeactivated
	}
	if newOrganizationID == "" {
		return ErrEmptyOrganization
	}
	if newOrganizationID == s.organizationID {
		return ErrSameOrganization
	}
	s.organizationID = newOrganizationID
	return nil
}

// Deactivate marks the staff member inactive. Idempotent calls are
// rejected: re-deactivating returns ErrAlreadyDeactivated so callers
// can distinguish "no-op" from "first deactivation".
func (s *Staff) Deactivate() error {
	if s.deactivated {
		return ErrAlreadyDeactivated
	}
	s.deactivated = true
	return nil
}

func validatePersonalName(name string, ifEmpty error) error {
	if name == "" {
		return ifEmpty
	}
	if len(name) > maxNameLen {
		return fmt.Errorf("%w: %d > %d", ErrNameTooLong, len(name), maxNameLen)
	}
	return nil
}
