package organization

import (
	"errors"
	"strings"
	"testing"
)

const (
	testOrgID        ID     = "org-1"
	testOwnerStaffID string = "staff-1"
)

func validOrg(t *testing.T) *Organization {
	t.Helper()
	slug, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}
	o, err := NewOrganization(testOrgID, "Acme Corp", slug, testOwnerStaffID)
	if err != nil {
		t.Fatalf("NewOrganization: %v", err)
	}
	return o
}

func TestNewOrganization_Valid(t *testing.T) {
	t.Parallel()
	slug, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}
	o, err := NewOrganization(testOrgID, "  Acme Corp  ", slug, testOwnerStaffID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if o.ID() != testOrgID {
		t.Errorf("ID = %q, want %q", o.ID(), testOrgID)
	}
	if o.Name() != "Acme Corp" {
		t.Errorf("Name = %q, want %q (trimmed)", o.Name(), "Acme Corp")
	}
	if o.Slug() != slug {
		t.Errorf("Slug = %q, want %q", o.Slug(), slug)
	}
	if o.OwnerStaffID() != testOwnerStaffID {
		t.Errorf("OwnerStaffID = %q, want %q", o.OwnerStaffID(), testOwnerStaffID)
	}
	if o.Deactivated() {
		t.Errorf("Deactivated = true, want false on fresh org")
	}
}

func TestNewOrganization_Invariants(t *testing.T) {
	t.Parallel()
	slug, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}

	cases := []struct {
		name         string
		id           ID
		orgName      string
		ownerStaffID string
		wantErr      error
	}{
		{"empty-id", "", "Acme", testOwnerStaffID, ErrEmptyID},
		{"empty-name", testOrgID, "   ", testOwnerStaffID, ErrEmptyName},
		{"too-long-name", testOrgID, strings.Repeat("a", maxOrganizationNameLen+1), testOwnerStaffID, ErrNameTooLong},
		{"empty-owner", testOrgID, "Acme", "", ErrEmptyOwner},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := NewOrganization(tc.id, tc.orgName, slug, tc.ownerStaffID)
			if !errors.Is(err, tc.wantErr) {
				t.Errorf("err = %v, want errors.Is(_, %v)", err, tc.wantErr)
			}
		})
	}
}

func TestNewOrganization_RejectsZeroSlug(t *testing.T) {
	t.Parallel()
	_, err := NewOrganization(testOrgID, "Acme", Slug(""), testOwnerStaffID)
	if !errors.Is(err, ErrInvalidSlug) {
		t.Errorf("err = %v, want errors.Is(_, ErrInvalidSlug)", err)
	}
}

func TestOrganization_Rename(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	if err := o.Rename("  New Name  "); err != nil {
		t.Fatalf("Rename: %v", err)
	}
	if o.Name() != "New Name" {
		t.Errorf("Name = %q, want %q (trimmed)", o.Name(), "New Name")
	}
}

func TestOrganization_Rename_Rejections(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		newName string
		wantErr error
	}{
		{"empty", "   ", ErrEmptyName},
		{"too-long", strings.Repeat("a", maxOrganizationNameLen+1), ErrNameTooLong},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			o := validOrg(t)
			if err := o.Rename(tc.newName); !errors.Is(err, tc.wantErr) {
				t.Errorf("err = %v, want errors.Is(_, %v)", err, tc.wantErr)
			}
		})
	}
}

func TestOrganization_Rename_RejectsAfterDeactivate(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	if err := o.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if err := o.Rename("New Name"); !errors.Is(err, ErrDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrDeactivated)", err)
	}
}

func TestOrganization_TransferOwnership(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	const newOwner = "staff-2"
	if err := o.TransferOwnership(newOwner); err != nil {
		t.Fatalf("TransferOwnership: %v", err)
	}
	if o.OwnerStaffID() != newOwner {
		t.Errorf("OwnerStaffID = %q, want %q", o.OwnerStaffID(), newOwner)
	}
}

func TestOrganization_TransferOwnership_Rejections(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name     string
		newOwner string
		wantErr  error
	}{
		{"empty", "", ErrEmptyOwner},
		{"same-owner", testOwnerStaffID, ErrSameOwner},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			o := validOrg(t)
			if err := o.TransferOwnership(tc.newOwner); !errors.Is(err, tc.wantErr) {
				t.Errorf("err = %v, want errors.Is(_, %v)", err, tc.wantErr)
			}
		})
	}
}

func TestOrganization_TransferOwnership_RejectsAfterDeactivate(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	if err := o.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if err := o.TransferOwnership("staff-2"); !errors.Is(err, ErrDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrDeactivated)", err)
	}
}

func TestOrganization_Deactivate(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	if err := o.Deactivate(); err != nil {
		t.Fatalf("Deactivate: %v", err)
	}
	if !o.Deactivated() {
		t.Errorf("Deactivated() = false after Deactivate")
	}
}

func TestOrganization_Deactivate_Twice(t *testing.T) {
	t.Parallel()
	o := validOrg(t)
	if err := o.Deactivate(); err != nil {
		t.Fatalf("first Deactivate: %v", err)
	}
	if err := o.Deactivate(); !errors.Is(err, ErrAlreadyDeactivated) {
		t.Errorf("err = %v, want errors.Is(_, ErrAlreadyDeactivated)", err)
	}
}

func TestUnmarshalOrganizationFromDatabase(t *testing.T) {
	t.Parallel()
	slug, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}
	// Unmarshal bypasses validation: empty name + owner survive.
	o, err := UnmarshalOrganizationFromDatabase(testOrgID, "", slug, "", true)
	if err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if o.Name() != "" {
		t.Errorf("Name = %q, want empty (unmarshal bypasses validation)", o.Name())
	}
	if !o.Deactivated() {
		t.Errorf("Deactivated = false, want true")
	}
}

func TestUnmarshalOrganizationFromDatabase_RequiresID(t *testing.T) {
	t.Parallel()
	slug, err := NewSlug("acme-corp")
	if err != nil {
		t.Fatalf("NewSlug: %v", err)
	}
	if _, err := UnmarshalOrganizationFromDatabase("", "Acme", slug, testOwnerStaffID, false); !errors.Is(err, ErrEmptyID) {
		t.Errorf("err = %v, want errors.Is(_, ErrEmptyID)", err)
	}
}

func TestNotFoundError(t *testing.T) {
	t.Parallel()
	var err error = NotFoundError{ID: testOrgID}
	want := `organization "org-1" not found`
	if err.Error() != want {
		t.Errorf("Error() = %q, want %q", err.Error(), want)
	}

	var nfe NotFoundError
	if !errors.As(err, &nfe) {
		t.Errorf("errors.As did not match NotFoundError")
	}
	if nfe.ID != testOrgID {
		t.Errorf("ID = %q, want %q", nfe.ID, testOrgID)
	}
}
