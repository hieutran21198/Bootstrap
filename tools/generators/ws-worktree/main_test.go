package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestParseArgs(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		args []string
		want options
	}{
		{"fresh", []string{"feature/x"}, options{mode: modeCreate, branch: "feature/x"}},
		{"ref", []string{"--ref", "origin/main", "--branch", "feature/x"}, options{mode: modeRef, ref: "origin/main", branch: "feature/x"}},
		{"pr default", []string{"--pr", "12"}, options{mode: modePR, pr: "12", branch: "chore/pr-12"}},
		{"list", []string{"--list"}, options{mode: modeList}},
		{"remove", []string{"--remove", "feature-x", "--force"}, options{mode: modeRemove, remove: "feature-x", force: true}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := parseArgs(tc.args)
			if err != nil {
				t.Fatalf("parseArgs() error = %v", err)
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("parseArgs() = %#v; want %#v", got, tc.want)
			}
		})
	}
}

func TestParseArgsForceRequiresRemove(t *testing.T) {
	t.Parallel()
	cases := [][]string{
		{"--force", "feature/x"},
		{"--force", "--list"},
		{"--force", "--ref", "feature/x"},
	}
	for _, args := range cases {
		args := args
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			t.Parallel()
			_, err := parseArgs(args)
			if err == nil || !strings.Contains(err.Error(), "--force") {
				t.Fatalf("parseArgs(%v) error = %v; want --force usage error", args, err)
			}
		})
	}
}

func TestBranchSlug(t *testing.T) {
	t.Parallel()
	if got := branchSlug("feature/tenant-invite"); got != "feature-tenant-invite" {
		t.Errorf("branchSlug() = %q", got)
	}
}

func TestParseWorktreeList(t *testing.T) {
	t.Parallel()
	raw := "worktree /repo\nHEAD abc\nbranch refs/heads/main\n\nworktree /repo/.worktrees/feature-x\nHEAD def\nbranch refs/heads/feature/x\n"
	got, err := parseWorktreeList(raw)
	if err != nil {
		t.Fatalf("parseWorktreeList() error = %v", err)
	}
	want := []worktree{{path: "/repo", branch: "main"}, {path: "/repo/.worktrees/feature-x", branch: "feature/x"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parseWorktreeList() = %#v; want %#v", got, want)
	}
}

func TestAllocateOffsetReuse(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	root := filepath.Join(dir, ".worktrees")
	mustMarker(t, filepath.Join(root, "one"), "10\n")
	mustMarker(t, filepath.Join(root, "three"), "30\n")
	got, err := allocateOffset(root, []worktree{
		{path: filepath.Join(root, "one")},
		{path: filepath.Join(root, "three")},
	})
	if err != nil {
		t.Fatalf("allocateOffset() error = %v", err)
	}
	if got != 20 {
		t.Errorf("allocateOffset() = %d; want 20", got)
	}
}

func TestAllocateOffsetSkipsOrphanedRecordsWithPruneHint(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	root := filepath.Join(dir, ".worktrees")
	live := filepath.Join(root, "live")
	orphan := filepath.Join(root, "orphan")
	mustMarker(t, live, "10\n")
	var stderr bytes.Buffer
	got, err := allocateOffsetWithWriter(root, []worktree{{path: live}, {path: orphan}}, &stderr)
	if err != nil {
		t.Fatalf("allocateOffset() error = %v", err)
	}
	if got != 20 {
		t.Errorf("allocateOffset() = %d; want 20", got)
	}
	if !strings.Contains(stderr.String(), "stale worktree record "+orphan) || !strings.Contains(stderr.String(), "git worktree prune") {
		t.Errorf("prune hint = %q; want stale record and prune hint", stderr.String())
	}
}

func TestAllocateOffsetRejectsInvalidManagedMarkers(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name   string
		marker string
	}{
		{"zero", "0\n"},
		{"non-aligned", "11\n"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			dir := t.TempDir()
			root := filepath.Join(dir, ".worktrees")
			wt := filepath.Join(root, tc.name)
			mustMarker(t, wt, tc.marker)
			_, err := allocateOffset(root, []worktree{{path: wt}})
			if err == nil || !strings.Contains(err.Error(), markerFileName) {
				t.Fatalf("allocateOffset() error = %v; want loud %s error", err, markerFileName)
			}
		})
	}
}

func TestCheckGitignore(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(".worktrees/\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	err := checkGitignore(dir)
	if err == nil || !strings.Contains(err.Error(), ".worktree-offset") {
		t.Fatalf("checkGitignore() error = %v; want missing .worktree-offset", err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(".worktrees/\n.worktree-offset\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := checkGitignore(dir); err != nil {
		t.Fatalf("checkGitignore() error = %v", err)
	}
}

func TestIncludedFiles(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	writeFile(t, dir, ".worktreeinclude", ".env*\ndeploy/local/.env\n")
	writeFile(t, dir, ".env", "secret")
	writeFile(t, dir, ".env.local", "secret")
	writeFile(t, dir, "deploy/local/.env", "secret")
	writeFile(t, dir, "tracked.env", "no")
	got, err := includedFiles(dir, map[string]bool{
		".env":              true,
		".env.local":        true,
		"deploy/local/.env": true,
	})
	if err != nil {
		t.Fatalf("includedFiles() error = %v", err)
	}
	want := []string{".env", ".env.local", "deploy/local/.env"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("includedFiles() = %#v; want %#v", got, want)
	}
}

func TestCopyIncludedFilesUsesInvokingRootForIgnoredFilesAndBytes(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	mainRoot := filepath.Join(dir, "main")
	invokingRoot := filepath.Join(dir, "linked", "subdir", "..")
	invokingRoot = filepath.Clean(invokingRoot)
	dstRoot := filepath.Join(mainRoot, ".worktrees", "feature-x")
	writeFile(t, mainRoot, ".env", "main-secret")
	writeFile(t, invokingRoot, ".worktreeinclude", ".env*\n")
	writeFile(t, invokingRoot, ".env", "linked-secret")
	writeFile(t, invokingRoot, ".env.tracked", "tracked-secret")
	if err := os.MkdirAll(dstRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	runner := fakeRunner{responses: map[string]string{
		strings.Join([]string{"git", "-C", invokingRoot, "ls-files", "--ignored", "--others", "--exclude-standard"}, "\x00"): ".env\n",
	}}
	if err := copyIncludedFiles(runner, invokingRoot, dstRoot); err != nil {
		t.Fatalf("copyIncludedFiles() error = %v", err)
	}
	got := readString(t, filepath.Join(dstRoot, ".env"))
	if got != "linked-secret" {
		t.Errorf("copied .env = %q; want invoking worktree bytes", got)
	}
	if _, err := os.Lstat(filepath.Join(dstRoot, ".env.tracked")); !os.IsNotExist(err) {
		t.Errorf("tracked matching file was copied; Lstat error = %v", err)
	}
}

func TestCopyIncludedFilesRejectsDestinationSymlinks(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name  string
		setup func(t *testing.T, dstRoot, escapeRoot string)
	}{
		{
			name: "dangling file symlink",
			setup: func(t *testing.T, dstRoot, escapeRoot string) {
				t.Helper()
				if err := os.Symlink(filepath.Join(escapeRoot, "missing"), filepath.Join(dstRoot, ".env")); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "non-dangling file symlink",
			setup: func(t *testing.T, dstRoot, escapeRoot string) {
				t.Helper()
				writeFile(t, escapeRoot, "outside", "outside")
				if err := os.Symlink(filepath.Join(escapeRoot, "outside"), filepath.Join(dstRoot, ".env")); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "symlinked parent",
			setup: func(t *testing.T, dstRoot, escapeRoot string) {
				t.Helper()
				writeFile(t, escapeRoot, "placeholder", "outside")
				if err := os.RemoveAll(filepath.Join(dstRoot, "nested")); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(escapeRoot, filepath.Join(dstRoot, "nested")); err != nil {
					t.Fatal(err)
				}
			},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			dir := t.TempDir()
			srcRoot := filepath.Join(dir, "src")
			dstRoot := filepath.Join(dir, "dst")
			escapeRoot := filepath.Join(dir, "escape")
			writeFile(t, srcRoot, ".worktreeinclude", ".env\nnested/.env\n")
			writeFile(t, srcRoot, ".env", "secret")
			writeFile(t, srcRoot, "nested/.env", "nested-secret")
			if err := os.MkdirAll(dstRoot, 0o700); err != nil {
				t.Fatal(err)
			}
			tc.setup(t, dstRoot, escapeRoot)
			runner := ignoredRunner(srcRoot, ".env\nnested/.env\n")
			if err := copyIncludedFiles(runner, srcRoot, dstRoot); err == nil {
				t.Fatal("copyIncludedFiles() error = nil; want symlink rejection")
			}
			if got := readStringIfExists(t, filepath.Join(escapeRoot, "outside")); got == "secret" || got == "nested-secret" {
				t.Errorf("secret bytes were written through symlink: %q", got)
			}
			if got := readStringIfExists(t, filepath.Join(escapeRoot, ".env")); got != "" {
				t.Errorf("secret bytes escaped to symlinked parent: %q", got)
			}
		})
	}
}

func TestCopyIncludedFilesNoOverwriteAndPerms(t *testing.T) {
	t.Parallel()
	t.Run("no overwrite", func(t *testing.T) {
		t.Parallel()
		dir := t.TempDir()
		srcRoot := filepath.Join(dir, "src")
		dstRoot := filepath.Join(dir, "dst")
		writeFile(t, srcRoot, ".worktreeinclude", ".env\n")
		writeFile(t, srcRoot, ".env", "secret")
		writeFile(t, dstRoot, ".env", "old")
		if err := copyIncludedFiles(ignoredRunner(srcRoot, ".env\n"), srcRoot, dstRoot); err == nil {
			t.Fatal("copyIncludedFiles() error = nil; want existing destination failure")
		}
		if got := readString(t, filepath.Join(dstRoot, ".env")); got != "old" {
			t.Errorf("existing file = %q; want old", got)
		}
	})
	t.Run("perms", func(t *testing.T) {
		t.Parallel()
		dir := t.TempDir()
		srcRoot := filepath.Join(dir, "src")
		dstRoot := filepath.Join(dir, "dst")
		writeFile(t, srcRoot, ".worktreeinclude", "nested/.env\n")
		writeFile(t, srcRoot, "nested/.env", "secret")
		if err := os.MkdirAll(dstRoot, 0o700); err != nil {
			t.Fatal(err)
		}
		if err := copyIncludedFiles(ignoredRunner(srcRoot, "nested/.env\n"), srcRoot, dstRoot); err != nil {
			t.Fatalf("copyIncludedFiles() error = %v", err)
		}
		assertPerm(t, filepath.Join(dstRoot, "nested"), 0o700)
		assertPerm(t, filepath.Join(dstRoot, "nested", ".env"), 0o600)
	})
}

type fakeRunner struct{ responses map[string]string }

func (f fakeRunner) Run(name string, args ...string) (string, error) {
	key := strings.Join(append([]string{name}, args...), "\x00")
	value, ok := f.responses[key]
	if !ok {
		return "", fmt.Errorf("unexpected command: %q", key)
	}
	return value, nil
}

func ignoredRunner(root, ignored string) fakeRunner {
	return fakeRunner{responses: map[string]string{
		strings.Join([]string{"git", "-C", root, "ls-files", "--ignored", "--others", "--exclude-standard"}, "\x00"): ignored,
	}}
}

func readString(t *testing.T, path string) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func readStringIfExists(t *testing.T, path string) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return ""
	}
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func assertPerm(t *testing.T, path string, want os.FileMode) {
	t.Helper()
	info, err := os.Lstat(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := info.Mode().Perm(); got != want {
		t.Errorf("mode %s = %v; want %v", path, got, want)
	}
}

func mustMarker(t *testing.T, dir, content string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	writeFile(t, dir, markerFileName, content)
}

func writeFile(t *testing.T, root, rel, content string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}
