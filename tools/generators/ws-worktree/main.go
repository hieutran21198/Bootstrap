package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

const (
	markerFileName = ".worktree-offset"
	portStride     = 10
	postgresBase   = 5432
	docsBase       = 3000
)

type mode int

const (
	modeCreate mode = iota
	modeRef
	modePR
	modeList
	modeRemove
	modeHelp
)

type options struct {
	mode   mode
	branch string
	ref    string
	pr     string
	remove string
	force  bool
}

type worktree struct {
	path   string
	branch string
}

type commandRunner interface {
	Run(name string, args ...string) (string, error)
}

type execRunner struct{}

func (execRunner) Run(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...) //nolint:gosec // command names are fixed workspace tools; args come from CLI by design.
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return stdout.String(), fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return stdout.String(), nil
}

func main() {
	if err := run(os.Args[1:], execRunner{}); err != nil {
		fmt.Fprintf(os.Stderr, "ws-worktree: %v\n", err)
		os.Exit(1)
	}
}

func run(args []string, runner commandRunner) error {
	opts, err := parseArgs(args)
	if err != nil {
		return err
	}
	if opts.mode == modeHelp {
		usage(os.Stdout)
		return nil
	}
	invokingRoot, err := runner.Run("git", "rev-parse", "--show-toplevel")
	if err != nil {
		return err
	}
	invokingRoot = strings.TrimSpace(invokingRoot)

	porcelain, err := runner.Run("git", "worktree", "list", "--porcelain")
	if err != nil {
		return err
	}
	worktrees, err := parseWorktreeList(porcelain)
	if err != nil {
		return err
	}
	if len(worktrees) == 0 {
		return errors.New("git worktree list returned no worktrees")
	}
	mainPath := worktrees[0].path
	managedRoot := filepath.Join(mainPath, ".worktrees")

	switch opts.mode {
	case modeList:
		return listManaged(os.Stdout, managedRoot, worktrees)
	case modeRemove:
		return removeManaged(runner, managedRoot, worktrees, opts.remove, opts.force)
	case modeCreate, modeRef, modePR:
		return createManaged(runner, opts, managedRoot, invokingRoot, worktrees)
	default:
		return errors.New("unknown mode")
	}
}

func parseArgs(args []string) (options, error) {
	fs := flag.NewFlagSet("ws-worktree", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	ref := fs.String("ref", "", "ref")
	branch := fs.String("branch", "", "branch")
	pr := fs.String("pr", "", "pull request")
	list := fs.Bool("list", false, "list")
	remove := fs.String("remove", "", "remove")
	force := fs.Bool("force", false, "force")
	help := fs.Bool("help", false, "help")
	if err := fs.Parse(args); err != nil {
		return options{}, err
	}
	if *help {
		return options{mode: modeHelp}, nil
	}
	pos := fs.Args()
	set := 0
	for _, ok := range []bool{*ref != "", *pr != "", *list, *remove != "", len(pos) == 1} {
		if ok {
			set++
		}
	}
	if set != 1 || len(pos) > 1 {
		return options{}, errors.New("usage: run ws-worktree --help")
	}
	if *force && *remove == "" {
		return options{}, errors.New("--force is only valid with --remove")
	}
	if *list {
		return options{mode: modeList}, nil
	}
	if *remove != "" {
		return options{mode: modeRemove, remove: *remove, force: *force}, nil
	}
	if *pr != "" {
		b := *branch
		if b == "" {
			b = "chore/pr-" + *pr
		}
		return options{mode: modePR, pr: *pr, branch: b}, nil
	}
	if *ref != "" {
		return options{mode: modeRef, ref: *ref, branch: *branch}, nil
	}
	return options{mode: modeCreate, branch: pos[0]}, nil
}

func branchSlug(branch string) string { return strings.ReplaceAll(branch, "/", "-") }

func parseWorktreeList(raw string) ([]worktree, error) {
	var out []worktree
	var cur *worktree
	s := bufio.NewScanner(strings.NewReader(raw))
	for s.Scan() {
		line := s.Text()
		if line == "" {
			if cur != nil {
				out = append(out, *cur)
				cur = nil
			}
			continue
		}
		if strings.HasPrefix(line, "worktree ") {
			if cur != nil {
				out = append(out, *cur)
			}
			cur = &worktree{path: strings.TrimPrefix(line, "worktree ")}
			continue
		}
		if cur != nil && strings.HasPrefix(line, "branch refs/heads/") {
			cur.branch = strings.TrimPrefix(line, "branch refs/heads/")
		}
	}
	if cur != nil {
		out = append(out, *cur)
	}
	return out, s.Err()
}

func allocateOffset(managedRoot string, worktrees []worktree) (int, error) {
	return allocateOffsetWithWriter(managedRoot, worktrees, os.Stderr)
}

func allocateOffsetWithWriter(managedRoot string, worktrees []worktree, pruneHintWriter io.Writer) (int, error) {
	used := map[int]bool{}
	for _, wt := range managedWorktrees(managedRoot, worktrees) {
		if _, err := os.Lstat(wt.path); errors.Is(err, fs.ErrNotExist) {
			_, _ = fmt.Fprintf(pruneHintWriter, "ws-worktree: stale worktree record %s; run 'git worktree prune'\n", wt.path)
			continue
		} else if err != nil {
			return 0, err
		}
		offset, err := readOffset(filepath.Join(wt.path, markerFileName))
		if err != nil {
			return 0, fmt.Errorf("%s: %w", wt.path, err)
		}
		if offset <= 0 {
			return 0, fmt.Errorf("%s: invalid %s marker: managed worktree offset must be positive", wt.path, markerFileName)
		}
		used[offset/portStride] = true
	}
	for slot := 1; ; slot++ {
		if !used[slot] {
			return slot * portStride, nil
		}
	}
}

func readOffset(path string) (int, error) {
	raw, err := os.ReadFile(path) //nolint:gosec // marker path is derived from git worktree records and the configured marker filename.
	if err != nil {
		return 0, err
	}
	offset, err := strconv.Atoi(strings.TrimSpace(string(raw)))
	if err != nil || offset < 0 || offset%portStride != 0 {
		return 0, fmt.Errorf("invalid %s marker", markerFileName)
	}
	return offset, nil
}

func checkGitignore(mainPath string) error {
	raw, err := os.ReadFile(filepath.Join(mainPath, ".gitignore")) //nolint:gosec // mainPath comes from git worktree list; this guard only reads repository policy.
	if err != nil {
		return err
	}
	patterns := map[string]bool{".worktrees/": false, ".worktree-offset": false}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if _, ok := patterns[line]; ok {
			patterns[line] = true
		}
	}
	var missing []string
	for p, ok := range patterns {
		if !ok {
			missing = append(missing, p)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf(".gitignore is missing required worktree patterns; add:\n%s", strings.Join(missing, "\n"))
	}
	return nil
}

func createManaged(runner commandRunner, opts options, managedRoot, invokingRoot string, worktrees []worktree) error { //nolint:gocyclo // command orchestration follows the spec's ordered creation steps.
	mainPath := filepath.Dir(managedRoot)
	if err := checkGitignore(mainPath); err != nil {
		return err
	}
	branch := opts.branch
	if opts.mode == modeRef && branch == "" {
		if !localBranchExists(runner, opts.ref) {
			return errors.New("--ref without --branch must name an existing local branch")
		}
		branch = opts.ref
	}
	if err := validateBranch(runner, branch); err != nil {
		return err
	}
	slug := branchSlug(branch)
	path := filepath.Join(managedRoot, slug)
	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("worktree path already exists: %s", path)
	}
	for _, wt := range worktrees {
		if wt.path == path {
			return fmt.Errorf("worktree path already registered: %s", path)
		}
	}
	offset, err := allocateOffset(managedRoot, worktrees)
	if err != nil {
		return err
	}
	if opts.mode == modeCreate && localBranchExists(runner, branch) {
		return errors.New("target branch already exists; use --ref for an existing branch")
	}
	args, err := addArgs(runner, opts, path, branch)
	if err != nil {
		return err
	}
	if _, err := runner.Run("git", args...); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(path, markerFileName), []byte(strconv.Itoa(offset)+"\n"), 0o600); err != nil {
		return err
	}
	if err := copyIncludedFiles(runner, invokingRoot, path); err != nil {
		return err
	}
	fmt.Printf("Created worktree\n  path: %s\n  branch: %s\n  slug: %s\n  port offset: %d\n  portal Postgres: %d\n  docs dev: %d\n\nNext steps:\n  cd %s\n  direnv allow\n  codegraph init\n  opencode   # or start the agent CLI you want in this directory\n", path, branch, slug, offset, postgresBase+offset, docsBase+offset, path)
	return nil
}

func addArgs(runner commandRunner, opts options, path, branch string) ([]string, error) {
	switch opts.mode {
	case modeCreate:
		base := "main"
		if _, err := runner.Run("git", "fetch", "origin", "main"); err == nil {
			base = "origin/main"
		}
		return []string{"worktree", "add", "-b", branch, path, base}, nil
	case modeRef:
		if opts.branch != "" {
			return []string{"worktree", "add", "-b", branch, path, opts.ref}, nil
		}
		return []string{"worktree", "add", path, branch}, nil
	case modePR:
		ref := "refs/pull/" + opts.pr + "/head"
		if _, err := runner.Run("git", "fetch", "origin", ref); err != nil {
			return nil, err
		}
		return []string{"worktree", "add", "-b", branch, path, "FETCH_HEAD"}, nil
	default:
		return nil, errors.New("not a create mode")
	}
}

func validateBranch(runner commandRunner, branch string) error {
	if _, err := runner.Run("git-guard", "branch-name", branch); err != nil {
		return err
	}
	_, err := runner.Run("git-guard", "branch-protect", branch)
	return err
}

func localBranchExists(runner commandRunner, branch string) bool {
	_, err := runner.Run("git", "show-ref", "--verify", "--quiet", "refs/heads/"+branch)
	return err == nil
}

func managedWorktrees(managedRoot string, worktrees []worktree) []worktree {
	root := filepath.Clean(managedRoot) + string(os.PathSeparator)
	var out []worktree
	for _, wt := range worktrees {
		if strings.HasPrefix(filepath.Clean(wt.path)+string(os.PathSeparator), root) {
			out = append(out, wt)
		}
	}
	return out
}

func listManaged(w io.Writer, managedRoot string, worktrees []worktree) error {
	for _, wt := range managedWorktrees(managedRoot, worktrees) {
		offset, err := readOffset(filepath.Join(wt.path, markerFileName))
		if err != nil {
			return err
		}
		_, _ = fmt.Fprintf(w, "%s\t%s\t%d\t%d\t%s\n", filepath.Base(wt.path), wt.branch, offset/portStride, offset, wt.path)
	}
	return nil
}

func removeManaged(runner commandRunner, managedRoot string, worktrees []worktree, target string, force bool) error {
	for _, wt := range managedWorktrees(managedRoot, worktrees) {
		if target == wt.path || target == wt.branch || target == filepath.Base(wt.path) {
			args := []string{"worktree", "remove"}
			if force {
				fmt.Fprintln(os.Stderr, "ws-worktree: --force may discard dirty or untracked files")
				args = append(args, "--force")
			}
			args = append(args, wt.path)
			_, err := runner.Run("git", args...)
			if err == nil {
				fmt.Fprintln(os.Stderr, "ws-worktree: removed; consider running git worktree prune")
			}
			return err
		}
	}
	return fmt.Errorf("managed worktree not found: %s", target)
}

func includedFiles(root string, ignored map[string]bool) ([]string, error) {
	includePath := filepath.Join(root, ".worktreeinclude")
	raw, err := os.ReadFile(includePath) //nolint:gosec // .worktreeinclude is read from the invoking worktree root.
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	patterns := includePatterns(string(raw))
	var matches []string
	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if ignored[rel] && matchAny(patterns, rel) {
			matches = append(matches, rel)
		}
		return nil
	})
	return matches, err
}

func includePatterns(raw string) []string {
	var patterns []string
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "#") {
			patterns = append(patterns, line)
		}
	}
	return patterns
}

func matchAny(patterns []string, rel string) bool {
	// .worktreeinclude currently supports simple filepath.Match globs plus exact
	// relative-path equality, not full gitignore pattern semantics. The initial
	// workspace patterns (.env*, deploy/local/.env) fit this intentionally small
	// matcher; expand deliberately if future policy needs gitignore features.
	for _, p := range patterns {
		if ok, _ := filepath.Match(p, rel); ok || p == rel {
			return true
		}
	}
	return false
}

func copyIncludedFiles(runner commandRunner, srcRoot, dstRoot string) error {
	raw, err := runner.Run("git", "-C", srcRoot, "ls-files", "--ignored", "--others", "--exclude-standard")
	if err != nil {
		return err
	}
	ignored := map[string]bool{}
	for _, line := range strings.Split(raw, "\n") {
		if line != "" {
			ignored[line] = true
		}
	}
	files, err := includedFiles(srcRoot, ignored)
	if err != nil {
		return err
	}
	for _, rel := range files {
		dst := filepath.Join(dstRoot, filepath.FromSlash(rel))
		if _, err := os.Lstat(dst); err == nil {
			return fmt.Errorf("target include file already exists: %s", rel)
		} else if !errors.Is(err, fs.ErrNotExist) {
			return err
		}
		if err := secureMkdirAll(dstRoot, filepath.Dir(dst)); err != nil {
			return err
		}
		raw, err := os.ReadFile(filepath.Join(srcRoot, filepath.FromSlash(rel))) //nolint:gosec // source is a gitignored relative path selected by .worktreeinclude.
		if err != nil {
			return err
		}
		if err := writeNewFile(dst, raw); err != nil {
			return err
		}
	}
	return nil
}

func secureMkdirAll(root, dir string) error {
	root = filepath.Clean(root)
	dir = filepath.Clean(dir)
	if dir == root || dir == "." {
		return nil
	}
	rel, err := filepath.Rel(root, dir)
	if err != nil {
		return err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) || filepath.IsAbs(rel) {
		return fmt.Errorf("target parent escapes worktree: %s", dir)
	}
	current := root
	for _, part := range strings.Split(rel, string(os.PathSeparator)) {
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		switch {
		case errors.Is(err, fs.ErrNotExist):
			if mkdirErr := os.Mkdir(current, 0o700); mkdirErr != nil {
				return mkdirErr
			}
		case err != nil:
			return err
		case info.Mode()&os.ModeSymlink != 0:
			return fmt.Errorf("target parent is a symlink: %s", current)
		case !info.IsDir():
			return fmt.Errorf("target parent is not a directory: %s", current)
		}
	}
	return nil
}

func writeNewFile(path string, data []byte) error {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0o600) //nolint:gosec // destination was validated under the new worktree and is opened exclusively without following symlinks.
	if err != nil {
		return err
	}
	_, writeErr := file.Write(data)
	closeErr := file.Close()
	return errors.Join(writeErr, closeErr)
}

func usage(w io.Writer) {
	_, _ = fmt.Fprint(w, `usage:
  ws-worktree <branch>
  ws-worktree --ref <ref> [--branch <branch>]
  ws-worktree --pr <number> [--branch <branch>]
  ws-worktree --list
  ws-worktree --remove <branch|slug|path> [--force]
  ws-worktree --help
`)
}
