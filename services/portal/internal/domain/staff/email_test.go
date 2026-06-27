package staff

import (
	"errors"
	"testing"
)

func TestNewEmail_Valid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
		want Email
	}{
		{"lowercase", "alice@example.com", "alice@example.com"},
		{"uppercase-normalised", "ALICE@EXAMPLE.COM", "alice@example.com"},
		{"mixed-case-normalised", "Alice@Example.Com", "alice@example.com"},
		{"trims-whitespace", "  alice@example.com  ", "alice@example.com"},
		{"name-addr-form", "Alice <alice@example.com>", "alice@example.com"},
		{"with-subdomain", "alice@mail.example.com", "alice@mail.example.com"},
		{"plus-tag", "alice+work@example.com", "alice+work@example.com"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := NewEmail(tc.raw)
			if err != nil {
				t.Fatalf("NewEmail(%q) error: %v", tc.raw, err)
			}
			if got != tc.want {
				t.Errorf("NewEmail(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestNewEmail_Invalid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"whitespace-only", "   "},
		{"no-at", "alice.example.com"},
		{"no-local-part", "@example.com"},
		{"no-domain", "alice@"},
		{"bare-word", "alice"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := NewEmail(tc.raw)
			if !errors.Is(err, ErrInvalidEmail) {
				t.Errorf("NewEmail(%q) error = %v, want errors.Is(_, ErrInvalidEmail)", tc.raw, err)
			}
		})
	}
}

func TestEmail_String(t *testing.T) {
	t.Parallel()
	e, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	if e.String() != "alice@example.com" {
		t.Errorf("String() = %q, want %q", e.String(), "alice@example.com")
	}
}
