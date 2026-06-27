package organization

import (
	"errors"
	"strings"
	"testing"
)

func TestNewSlug_Valid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
		want Slug
	}{
		{"plain", "acme", "acme"},
		{"dashed", "acme-corp", "acme-corp"},
		{"with-numbers", "team-42", "team-42"},
		{"trim-and-lower", "  Acme-Corp  ", "acme-corp"},
		{"minimum-length", "abc", "abc"},
		{"maximum-length", strings.Repeat("a", maxSlugLen), Slug(strings.Repeat("a", maxSlugLen))},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := NewSlug(tc.raw)
			if err != nil {
				t.Fatalf("NewSlug(%q) returned error: %v", tc.raw, err)
			}
			if got != tc.want {
				t.Errorf("NewSlug(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestNewSlug_Invalid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"too-short", "ab"},
		{"too-long", strings.Repeat("a", maxSlugLen+1)},
		{"leading-dash", "-acme"},
		{"trailing-dash", "acme-"},
		{"double-dash", "acme--corp"},
		{"space-inside", "acme corp"},
		{"underscore", "acme_corp"},
		{"slash", "acme/corp"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := NewSlug(tc.raw)
			if !errors.Is(err, ErrInvalidSlug) {
				t.Errorf("NewSlug(%q) error = %v, want errors.Is(_, ErrInvalidSlug)", tc.raw, err)
			}
		})
	}
}

func TestSlug_String(t *testing.T) {
	t.Parallel()
	s, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}
	if s.String() != "acme-corp" {
		t.Errorf("String() = %q, want %q", s.String(), "acme-corp")
	}
}
