// Package staff is the pure-domain layer for the Staff aggregate. It
// depends only on the Go standard library; no SQL, no HTTP, no Zitadel
// SDK calls live here.
package staff

import (
	"errors"
	"fmt"
	"net/mail"
	"strings"
)

// ErrInvalidEmail is returned when an email address fails validation.
var ErrInvalidEmail = errors.New("invalid email")

// Email is a normalised email address. The zero value is invalid;
// always construct with NewEmail.
type Email string

// NewEmail validates raw using net/mail.ParseAddress (RFC 5322). It
// extracts the address part of an addr-spec or name-addr ("Alice
// <alice@example.com>" → "alice@example.com") and lowercases the result.
func NewEmail(raw string) (Email, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", fmt.Errorf("%w: empty", ErrInvalidEmail)
	}
	addr, err := mail.ParseAddress(trimmed)
	if err != nil {
		return "", fmt.Errorf("%w: %q: %w", ErrInvalidEmail, trimmed, err)
	}
	return Email(strings.ToLower(addr.Address)), nil
}

// String implements fmt.Stringer.
func (e Email) String() string { return string(e) }
