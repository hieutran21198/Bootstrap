package main

import "testing"

func TestValidateBranchName(t *testing.T) {
	tests := []struct {
		name    string
		branch  string
		wantErr bool
	}{
		{"feature", "feature/tenant-invite", false},
		{"fix with issue", "fix/1234-null-scope", false},
		{"hotfix", "hotfix/expired-token", false},
		{"nested desc", "feature/portal/invite-flow", false},
		{"main allowed", "main", false},
		{"release semver", "release/1.4.0", false},
		{"release sprint", "release/s12-1.4.0", false},
		{"no prefix", "tenant-invite", true},
		{"unknown prefix", "wip/tenant-invite", true},
		{"uppercase prefix", "Feature/tenant-invite", true},
		{"uppercase desc start", "feature/Tenant", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			errs := validateBranchName(tt.branch)
			if got := len(errs) > 0; got != tt.wantErr {
				t.Fatalf("validateBranchName(%q) errs=%v, wantErr=%v", tt.branch, errs, tt.wantErr)
			}
		})
	}
}

func TestIsProtected(t *testing.T) {
	tests := []struct {
		branch string
		want   bool
	}{
		{"main", true},
		{"release/1.4.0", true},
		{"feature/x", false},
		{"fix/y", false},
	}
	for _, tt := range tests {
		if got := isProtected(tt.branch); got != tt.want {
			t.Errorf("isProtected(%q) = %v, want %v", tt.branch, got, tt.want)
		}
	}
}
