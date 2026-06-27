// Package organization is the pure-domain layer for the Organization
// aggregate. It depends only on the Go standard library; no SQL, no
// HTTP, no Zitadel SDK calls live here.
package organization

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
)

// ErrInvalidSlug is returned when a slug fails validation. Wrapped
// with %w so callers can use errors.Is.
var ErrInvalidSlug = errors.New("invalid organization slug")

const (
	minSlugLen = 3
	maxSlugLen = 50
)

// slugPattern: lowercase alphanumerics with single-dash separators,
// no leading/trailing dashes, no consecutive dashes.
var slugPattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)

// Slug is a URL-safe organization identifier. The zero value is invalid;
// always construct with NewSlug.
type Slug string

// NewSlug validates and normalises raw. Surrounding whitespace is
// trimmed and the result is lowercased before validation, so callers
// may pass user input directly.
func NewSlug(raw string) (Slug, error) {
	normalised := strings.ToLower(strings.TrimSpace(raw))
	if len(normalised) < minSlugLen || len(normalised) > maxSlugLen {
		return "", fmt.Errorf("%w: length %d not in [%d,%d]: %q",
			ErrInvalidSlug, len(normalised), minSlugLen, maxSlugLen, raw)
	}
	if !slugPattern.MatchString(normalised) {
		return "", fmt.Errorf("%w: %q does not match %s",
			ErrInvalidSlug, raw, slugPattern.String())
	}
	return Slug(normalised), nil
}

// String implements fmt.Stringer.
func (s Slug) String() string { return string(s) }
