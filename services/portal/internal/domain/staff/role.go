package staff

import (
	"errors"
	"fmt"
)

// ErrInvalidRole is returned when a Role value is not one of the
// canonical roles defined in this package.
var ErrInvalidRole = errors.New("invalid role")

// Role is a typed string representing a staff member's role within
// their organization. The zero value is invalid; always construct with NewRole.
type Role string

// Canonical role set. Add new roles here; NewRole's switch will reject
// anything not listed below.
const (
	RoleOwner  Role = "owner"
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
)

// NewRole validates raw against the canonical role set. Comparison is
// case-sensitive — callers must normalise display strings before
// passing them in.
func NewRole(raw string) (Role, error) {
	r := Role(raw)
	switch r {
	case RoleOwner, RoleAdmin, RoleMember:
		return r, nil
	default:
		return "", fmt.Errorf("%w: %q", ErrInvalidRole, raw)
	}
}

// String implements fmt.Stringer.
func (r Role) String() string { return string(r) }
