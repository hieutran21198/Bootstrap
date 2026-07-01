package main

import (
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"unicode"
	"unicode/utf8"
)

// allowedTypes is the closed set of Conventional Commit types this workspace
// permits (docs/conventions/git/commit-messages.md).
var allowedTypes = []string{
	"feat", "fix", "docs", "style", "refactor", "test", "chore", "perf", "ci", "revert",
}

// headerRe matches "<type>(<scope>)!: <subject>" — scope and ! are optional.
var headerRe = regexp.MustCompile(`^([a-zA-Z]+)(\(([^()]+)\))?(!)?: (.+)$`)

const (
	subjectSoftLimit = 50 // preferred maximum header length
	subjectHardLimit = 72 // enforced maximum header length
)

// commentPrefix is the git comment character; such lines are stripped from a
// commit message before validation (they never reach the final commit).
const commentPrefix = "#"

// skipPrefixes are header prefixes git generates automatically; validating them
// would be noise, so they pass unconditionally.
var skipPrefixes = []string{"Merge ", "fixup! ", "squash! ", "amend! ", `Revert "`}

// cmdCommitMsg validates the commit message stored in the file at rest[0].
func cmdCommitMsg(rest []string) int {
	if len(rest) < 1 {
		fmt.Fprintln(os.Stderr, "git-guard commit-msg: expected a commit-message file path")
		return 2
	}
	raw, err := os.ReadFile(rest[0]) //nolint:gosec // path is the commit-message file supplied by git/CLI, not attacker input
	if err != nil {
		fmt.Fprintf(os.Stderr, "git-guard commit-msg: %v\n", err)
		return 2
	}
	errs, warns := validateCommitMessage(string(raw))
	return report("invalid commit message:", errs, warns)
}

// cmdPRTitle validates a pull-request title, which becomes the squash commit
// subject and so follows the same header rule.
func cmdPRTitle(rest []string) int {
	title := strings.TrimSpace(strings.Join(rest, " "))
	if title == "" {
		fmt.Fprintln(os.Stderr, "git-guard pr-title: expected a title argument")
		return 2
	}
	if strings.ContainsAny(title, "\r\n") {
		return report("invalid PR title:", []string{"title must be a single line"}, nil)
	}
	errs, warns := validateHeader(title)
	return report(fmt.Sprintf("invalid PR title %q:", title), errs, warns)
}

// cmdCommitRange validates the subject of every non-merge commit in base..head.
// It is advisory (CI): squash-merge means only the PR title reaches main, but a
// clean per-commit history is still preferred.
func cmdCommitRange(rest []string) int {
	if len(rest) < 1 {
		fmt.Fprintln(os.Stderr, "git-guard commit-range: expected <base> [head]")
		return 2
	}
	base := rest[0]
	head := "HEAD"
	if len(rest) > 1 {
		head = rest[1]
	}
	out, err := gitOutput("log", "--no-merges", "--format=%s", base+".."+head)
	if err != nil {
		fmt.Fprintf(os.Stderr, "git-guard commit-range: %v\n", err)
		return 2
	}
	code := 0
	for _, subject := range strings.Split(strings.TrimSpace(out), "\n") {
		if subject == "" || shouldSkip(subject) {
			continue
		}
		if errs, warns := validateHeader(subject); report(fmt.Sprintf("invalid commit %q:", subject), errs, warns) != 0 {
			code = 1
		}
	}
	return code
}

// validateCommitMessage checks a full commit message: the header line, the
// blank line separating an optional body, and skip conditions. It returns
// hard errors and soft warnings separately.
func validateCommitMessage(raw string) (errs, warns []string) {
	lines := cleanMessage(raw)
	if len(lines) == 0 {
		return []string{"the commit message is empty"}, nil
	}

	header := lines[0]
	if shouldSkip(header) {
		return nil, nil
	}

	errs, warns = validateHeader(header)

	// A body must be separated from the subject by exactly one blank line.
	if len(lines) > 1 && lines[1] != "" {
		errs = append(errs, "separate the subject from the body with a blank line")
	}
	return errs, warns
}

// validateHeader checks a single header line against the type set, subject
// style, and length rules.
func validateHeader(header string) (errs, warns []string) {
	m := headerRe.FindStringSubmatch(header)
	if m == nil {
		return []string{
			fmt.Sprintf("%q does not match \"<type>(<scope>): <subject>\"", header),
		}, nil
	}

	typ, subject := m[1], m[5]

	if !slices.Contains(allowedTypes, typ) {
		errs = append(errs, fmt.Sprintf("type %q is not allowed; use one of: %s",
			typ, strings.Join(allowedTypes, ", ")))
	}

	if strings.HasSuffix(subject, ".") {
		errs = append(errs, "subject must not end with a period")
	}
	if r, _ := utf8.DecodeRuneInString(subject); unicode.IsUpper(r) {
		errs = append(errs, "subject should start lower-case and use the imperative mood")
	}

	switch n := utf8.RuneCountInString(header); {
	case n > subjectHardLimit:
		errs = append(errs, fmt.Sprintf("header is %d chars; keep it within %d", n, subjectHardLimit))
	case n > subjectSoftLimit:
		warns = append(warns, fmt.Sprintf("header is %d chars; aim for <= %d", n, subjectSoftLimit))
	}
	return errs, warns
}

// cleanMessage strips comment lines and trims surrounding blank lines, mirroring
// git's default cleanup so validation sees the message that will actually land.
func cleanMessage(raw string) []string {
	var out []string
	for _, line := range strings.Split(raw, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), commentPrefix) {
			continue
		}
		out = append(out, strings.TrimRight(line, "\r"))
	}
	// Trim leading and trailing blank lines.
	for len(out) > 0 && strings.TrimSpace(out[0]) == "" {
		out = out[1:]
	}
	for len(out) > 0 && strings.TrimSpace(out[len(out)-1]) == "" {
		out = out[:len(out)-1]
	}
	return out
}

func shouldSkip(header string) bool {
	for _, p := range skipPrefixes {
		if strings.HasPrefix(header, p) {
			return true
		}
	}
	return false
}
