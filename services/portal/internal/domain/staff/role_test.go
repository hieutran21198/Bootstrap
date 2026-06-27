package staff

import (
	"errors"
	"testing"
)

func TestNewRole_Valid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
		want Role
	}{
		{"owner", "owner", RoleOwner},
		{"admin", "admin", RoleAdmin},
		{"member", "member", RoleMember},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := NewRole(tc.raw)
			if err != nil {
				t.Fatalf("NewRole(%q) error: %v", tc.raw, err)
			}
			if got != tc.want {
				t.Errorf("NewRole(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestNewRole_Invalid(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"uppercase", "OWNER"},
		{"unknown", "viewer"},
		{"compound", "superadmin"},
		{"padded", "  admin  "},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := NewRole(tc.raw)
			if !errors.Is(err, ErrInvalidRole) {
				t.Errorf("NewRole(%q) error = %v, want errors.Is(_, ErrInvalidRole)", tc.raw, err)
			}
		})
	}
}

func TestRole_String(t *testing.T) {
	t.Parallel()
	if RoleOwner.String() != "owner" {
		t.Errorf("RoleOwner.String() = %q, want %q", RoleOwner.String(), "owner")
	}
}
