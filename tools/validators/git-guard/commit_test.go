package main

import (
	"strings"
	"testing"
)

func TestValidateHeader(t *testing.T) {
	tests := []struct {
		name    string
		header  string
		wantErr bool
	}{
		{"valid feat", "feat(portal): add tenant invite flow", false},
		{"valid no scope", "fix: prevent racing of requests", false},
		{"valid breaking", "feat(api)!: drop node 6 support", false},
		{"valid revert", "revert: undo the noodle change", false},
		{"unknown type", "feature(portal): add invites", true},
		{"build not allowed", "build: bump deps", true},
		{"uppercase subject", "feat: Add invites", true},
		{"trailing period", "fix: correct the bug.", true},
		{"missing colon", "feat add invites", true},
		{"empty subject after colon", "feat: ", true},
		{"too long", "feat: " + strings.Repeat("x", 80), true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			errs, _ := validateHeader(tt.header)
			if got := len(errs) > 0; got != tt.wantErr {
				t.Fatalf("validateHeader(%q) errs=%v, wantErr=%v", tt.header, errs, tt.wantErr)
			}
		})
	}
}

func TestValidateHeaderSoftLimitWarns(t *testing.T) {
	header := "feat: " + strings.Repeat("x", 55) // 61 chars: over soft, under hard
	errs, warns := validateHeader(header)
	if len(errs) != 0 {
		t.Fatalf("expected no hard errors, got %v", errs)
	}
	if len(warns) == 0 {
		t.Fatalf("expected a soft-limit warning for a %d-char header", len(header))
	}
}

func TestValidateCommitMessage(t *testing.T) {
	tests := []struct {
		name    string
		msg     string
		wantErr bool
	}{
		{"header only", "feat(portal): add invites", false},
		{"with body", "feat(portal): add invites\n\nInvitations expire after 72h.", false},
		{"missing blank line", "feat(portal): add invites\nno blank line above", true},
		{"empty", "\n\n  \n", true},
		{"comments stripped", "# a comment\nfeat: add invites\n# trailing\n", false},
		{"merge skipped", "Merge branch 'main' into feature/x", false},
		{"fixup skipped", "fixup! feat: add invites", false},
		{"git revert skipped", "Revert \"feat: add invites\"", false},
		{"bad type fails", "nope: do a thing", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			errs, _ := validateCommitMessage(tt.msg)
			if got := len(errs) > 0; got != tt.wantErr {
				t.Fatalf("validateCommitMessage(%q) errs=%v, wantErr=%v", tt.msg, errs, tt.wantErr)
			}
		})
	}
}
