package staff

import (
	"errors"
	"strings"
	"testing"
)

const (
	testStaffID ID     = "staff-1"
	testOrgID   string = "org-1"
)

func validStaff(t *testing.T) *Staff {
	t.Helper()
	email, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	s, err := Hire(testStaffID, testOrgID, email, "Alice", "Smith", RoleMember)
	if err != nil {
		t.Fatalf("Hire: %v", err)
	}
	return s
}

func TestHire_Valid(t *testing.T) {
	t.Parallel()
	email, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	s, err := Hire(testStaffID, testOrgID, email, "  Alice  ", "  Smith  ", RoleMember)
	if err != nil {
		t.Fatalf("Hire: %v", err)
	}
	if s.ID() != testStaffID {
		t.Errorf("ID = %q, want %q", s.ID(), testStaffID)
	}
	if s.OrganizationID() != testOrgID {
		t.Errorf("OrganizationID = %q, want %q", s.OrganizationID(), testOrgID)
	}
	if s.Email() != email {
		t.Errorf("Email = %q, want %q", s.Email(), email)
	}
	if s.FirstName() != "Alice" {
		t.Errorf("FirstName = %q, want %q (trimmed)", s.FirstName(), "Alice")
	}
	if s.LastName() != "Smith" {
		t.Errorf("LastName = %q, want %q (trimmed)", s.LastName(), "Smith")
	}
	if s.Role() != RoleMember {
		t.Errorf("Role = %q, want %q", s.Role(), RoleMember)
	}
	if s.Deactivated() {
		t.Errorf("Deactivated = true, want false on fresh staff")
	}
}

func TestHire_Invariants(t *testing.T) {
	t.Parallel()
	email, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}

	cases := []struct {
		name           string
		id             ID
		organizationID string
		email          Email
		first          string
		last           string
		role           Role
		wantErr        error
	}{
		{"empty-id", "", testOrgID, email, "Alice", "Smith", RoleMember, ErrEmptyID},
		{"empty-org", testStaffID, "", email, "Alice", "Smith", RoleMember, ErrEmptyOrganization},
		{"zero-email", testStaffID, testOrgID, "", "Alice", "Smith", RoleMember, ErrInvalidEmail},
		{"zero-role", testStaffID, testOrgID, email, "Alice", "Smith", "", ErrInvalidRole},
		{"empty-first", testStaffID, testOrgID, email, "   ", "Smith", RoleMember, ErrEmptyFirstName},
		{"empty-last", testStaffID, testOrgID, email, "Alice", "   ", RoleMember, ErrEmptyLastName},
		{"too-long-first", testStaffID, testOrgID, email, strings.Repeat("a", maxNameLen+1), "Smith", RoleMember, ErrNameTooLong},
		{"too-long-last", testStaffID, testOrgID, email, "Alice", strings.Repeat("a", maxNameLen+1), RoleMember, ErrNameTooLong},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := Hire(tc.id, tc.organizationID, tc.email, tc.first, tc.last, tc.role)
			if !errors.Is(err, tc.wantErr) {
				t.Errorf("err = %v, want errors.Is(_, %v)", err, tc.wantErr)
			}
		})
	}
}

func TestStaff_ChangeRole(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.ChangeRole(RoleAdmin); err != nil {
		t.Fatalf("ChangeRole: %v", err)
	}
	if s.Role() != RoleAdmin {
		t.Errorf("Role = %q, want %q", s.Role(), RoleAdmin)
	}
}

func TestStaff_ChangeRole_RejectsZero(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.ChangeRole(""); !errors.Is(err, ErrInvalidRole) {
		t.Errorf("err = %v, want errors.Is(_, ErrInvalidRole)", err)
	}
}

func TestStaff_ChangeRole_RejectsAfterDeactivate(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if err := s.ChangeRole(RoleAdmin); !errors.Is(err, ErrDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrDeactivated)", err)
	}
}

func TestStaff_ChangeEmail(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	newEmail, err := NewEmail("bob@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	if err := s.ChangeEmail(newEmail); err != nil {
		t.Fatalf("ChangeEmail: %v", err)
	}
	if s.Email() != newEmail {
		t.Errorf("Email = %q, want %q", s.Email(), newEmail)
	}
}

func TestStaff_ChangeEmail_RejectsZero(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.ChangeEmail(""); !errors.Is(err, ErrInvalidEmail) {
		t.Errorf("err = %v, want errors.Is(_, ErrInvalidEmail)", err)
	}
}

func TestStaff_ChangeEmail_RejectsAfterDeactivate(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	newEmail, err := NewEmail("bob@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	if err := s.ChangeEmail(newEmail); !errors.Is(err, ErrDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrDeactivated)", err)
	}
}

func TestStaff_TransferToOrganization(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.TransferToOrganization("org-2"); err != nil {
		t.Fatalf("TransferToOrganization: %v", err)
	}
	if s.OrganizationID() != "org-2" {
		t.Errorf("OrganizationID = %q, want %q", s.OrganizationID(), "org-2")
	}
}

func TestStaff_TransferToOrganization_Rejections(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		newOrg  string
		wantErr error
	}{
		{"empty", "", ErrEmptyOrganization},
		{"same-org", testOrgID, ErrSameOrganization},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			s := validStaff(t)
			if err := s.TransferToOrganization(tc.newOrg); !errors.Is(err, tc.wantErr) {
				t.Errorf("err = %v, want errors.Is(_, %v)", err, tc.wantErr)
			}
		})
	}
}

func TestStaff_TransferToOrganization_RejectsAfterDeactivate(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if err := s.TransferToOrganization("org-2"); !errors.Is(err, ErrDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrDeactivated)", err)
	}
}

func TestStaff_Deactivate(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if !s.Deactivated() {
		t.Errorf("Deactivated() = false after Deactivate")
	}
}

func TestStaff_Deactivate_Twice(t *testing.T) {
	t.Parallel()
	s := validStaff(t)
	if err := s.Deactivate(); err != nil {
		t.Fatalf("first Deactivate: %v", err)
	}
	if err := s.Deactivate(); !errors.Is(err, ErrAlreadyDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrAlreadyDeactivated)", err)
	}
}

func TestUnmarshalStaffFromDatabase(t *testing.T) {
	t.Parallel()
	email, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	// Unmarshal bypasses validation: empty first/last name survive.
	s, err := UnmarshalStaffFromDatabase(testStaffID, testOrgID, email, "", "", RoleMember, true)
	if err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if s.FirstName() != "" {
		t.Errorf("FirstName = %q, want empty (unmarshal bypasses validation)", s.FirstName())
	}
	if !s.Deactivated() {
		t.Errorf("Deactivated = false, want true")
	}
}

func TestUnmarshalStaffFromDatabase_RequiresID(t *testing.T) {
	t.Parallel()
	email, err := NewEmail("alice@example.com")
	if err != nil {
		t.Fatalf("NewEmail: %v", err)
	}
	if _, err := UnmarshalStaffFromDatabase("", testOrgID, email, "Alice", "Smith", RoleMember, false); !errors.Is(err, ErrEmptyID) {
		t.Errorf("err = %v, want errors.Is(_, ErrEmptyID)", err)
	}
}

func TestNotFoundError(t *testing.T) {
	t.Parallel()
	var err error = NotFoundError{ID: testStaffID}
	want := `staff "staff-1" not found`
	if err.Error() != want {
		t.Errorf("Error() = %q, want %q", err.Error(), want)
	}

	var nfe NotFoundError
	if !errors.As(err, &nfe) {
		t.Errorf("errors.As did not match NotFoundError")
	}
	if nfe.ID != testStaffID {
		t.Errorf("ID = %q, want %q", nfe.ID, testStaffID)
	}
}
