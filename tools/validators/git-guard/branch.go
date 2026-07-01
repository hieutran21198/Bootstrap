package main

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

// workBranchRe matches an allowed working-branch name: a type prefix followed by
// a kebab/slug description (docs/conventions/git/workflow.md).
var workBranchRe = regexp.MustCompile(
	`^(feature|fix|hotfix|docs|chore|refactor|ci|perf|style|test)/[a-z0-9][a-z0-9._/-]*$`)

// releaseBranchRe matches a release branch, e.g. release/1.4.0 or release/s12-1.4.0.
var releaseBranchRe = regexp.MustCompile(`^release/[a-z0-9][a-z0-9._/-]*$`)

// allowedPrefixes is the human-readable list surfaced in error messages.
const allowedPrefixes = "feature, fix, hotfix, docs, chore, refactor, ci, perf, style, test"

// cmdBranchName validates a branch name (rest[0], or the current branch).
func cmdBranchName(rest []string) int {
	name := branchArg(rest)
	if isDetached(name) {
		return 0 // detached HEAD (e.g. mid-rebase) — nothing to check
	}
	if errs := validateBranchName(name); len(errs) > 0 {
		return report(fmt.Sprintf("invalid branch name %q:", name), errs, nil)
	}
	return 0
}

// cmdBranchProtect fails when a commit is being made directly on a protected
// branch (main, release/*), enforcing the "always land via PR" rule locally.
func cmdBranchProtect(rest []string) int {
	name := branchArg(rest)
	if isDetached(name) {
		return 0
	}
	if isProtected(name) {
		return report(fmt.Sprintf("%q is a protected branch:", name), []string{
			"do not commit here directly — branch off with feature/… or fix/… and open a PR",
		}, nil)
	}
	return 0
}

func validateBranchName(name string) []string {
	switch {
	case name == "main", releaseBranchRe.MatchString(name), workBranchRe.MatchString(name):
		return nil
	default:
		return []string{fmt.Sprintf(
			"use <prefix>/<kebab-description> (prefixes: %s) or release/<version>",
			allowedPrefixes)}
	}
}

func isProtected(name string) bool {
	return name == "main" || releaseBranchRe.MatchString(name)
}

func isDetached(name string) bool {
	return name == "" || name == "HEAD"
}

// branchArg returns the explicit branch argument, or the current branch when
// none is given.
func branchArg(rest []string) string {
	if len(rest) > 0 && strings.TrimSpace(rest[0]) != "" {
		return strings.TrimSpace(rest[0])
	}
	name, err := gitOutput("rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(name)
}

// gitOutput runs git with the given args and returns its stdout.
func gitOutput(args ...string) (string, error) {
	cmd := exec.Command("git", args...) //nolint:gosec // fixed, internal git subcommands — no user-controlled binary
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %w", strings.Join(args, " "), err)
	}
	return string(out), nil
}
