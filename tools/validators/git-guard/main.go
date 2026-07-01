// Command git-guard validates this workspace's Git conventions
// (docs/conventions/git/). It is the single source of truth shared by the
// local pre-commit hooks (core.git) and the PR-validation CI workflow, so the
// rules cannot drift between the two.
//
// Subcommands:
//
//	commit-msg <file>        validate a commit message file (commit-msg hook)
//	commit-range <base> [head]  validate every non-merge commit subject in a range (CI)
//	pr-title <title>...      validate a pull-request title (CI)
//	branch-name [name]       validate a branch name; defaults to the current branch
//	branch-protect [name]    fail if committing directly to a protected branch
//
// Exit codes: 0 = ok, 1 = a convention was violated, 2 = usage error.
package main

import (
	"fmt"
	"os"
)

const docsRef = "see docs/conventions/git/"

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) == 0 {
		usage()
		return 2
	}

	cmd, rest := args[0], args[1:]
	switch cmd {
	case "commit-msg":
		return cmdCommitMsg(rest)
	case "commit-range":
		return cmdCommitRange(rest)
	case "pr-title":
		return cmdPRTitle(rest)
	case "branch-name":
		return cmdBranchName(rest)
	case "branch-protect":
		return cmdBranchProtect(rest)
	case "-h", "--help", "help":
		usage()
		return 0
	default:
		fmt.Fprintf(os.Stderr, "git-guard: unknown command %q\n\n", cmd)
		usage()
		return 2
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `git-guard — validate this workspace's Git conventions (`+docsRef+`)

usage:
  git-guard commit-msg <file>            validate a commit message file
  git-guard commit-range <base> [head]   validate commit subjects in base..head (default head: HEAD)
  git-guard pr-title <title>...          validate a pull-request title
  git-guard branch-name [name]           validate a branch name (default: current branch)
  git-guard branch-protect [name]        fail if the branch is protected (main, release/*)
`)
}

// report prints validation problems for a subject and returns the process exit
// code (0 when there are none). warns are printed but never fail the check.
func report(subject string, errs, warns []string) int {
	for _, w := range warns {
		fmt.Fprintf(os.Stderr, "git-guard: warning: %s\n", w)
	}
	if len(errs) == 0 {
		return 0
	}
	fmt.Fprintf(os.Stderr, "git-guard: %s\n", subject)
	for _, e := range errs {
		fmt.Fprintf(os.Stderr, "  ✗ %s\n", e)
	}
	fmt.Fprintf(os.Stderr, "  (%s)\n", docsRef)
	return 1
}
