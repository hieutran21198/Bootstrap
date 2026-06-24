package main

import (
	"reflect"
	"strings"
	"testing"
)

func TestPatchTreeOutput_inlinesNativeInfoDescriptions(t *testing.T) {
	output := strings.Join([]string{
		".",
		"├── docs",
		"│\u00a0\u00a0  { Documentation",
		"│\u00a0\u00a0 └── specs",
		"│\u00a0\u00a0     { Specs",
		"└── go.work",
		"",
	}, "\n")

	lines := patchTreeOutput(output, map[string]string{})
	got := formatPatchedLines(lines, options{tabular: true, docOnly: true, commentColumn: 24})

	want := []string{
		"├── docs                # Documentation",
		"│\u00a0\u00a0 └── specs           # Specs",
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("formatted lines mismatch\nwant: %#v\n got: %#v", want, got)
	}
}

func TestPatchTreeOutput_usesDescriptionMapWhenTreeInfoIsAbsent(t *testing.T) {
	output := strings.Join([]string{
		".",
		"├── docs",
		"│   └── specs",
		"└── apps",
		"",
	}, "\n")

	lines := patchTreeOutput(output, map[string]string{
		"docs":       "Documentation",
		"docs/specs": "Specs",
	})
	got := formatPatchedLines(lines, options{docOnly: true, commentColumn: 32})

	want := []string{
		"├── docs  # Documentation",
		"│   └── specs  # Specs",
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("formatted lines mismatch\nwant: %#v\n got: %#v", want, got)
	}
}

func TestParseArgs_docOnlyIsWrapperOption(t *testing.T) {
	opts := parseArgs([]string{"--tabular", "--doc-only", "-L", "2", "."})

	if !opts.tabular {
		t.Fatal("expected tabular to be enabled")
	}
	if !opts.docOnly {
		t.Fatal("expected docOnly to be enabled")
	}

	wantArgs := []string{"-L", "2", "."}
	if !reflect.DeepEqual(opts.treeArgs, wantArgs) {
		t.Fatalf("tree args mismatch\nwant: %#v\n got: %#v", wantArgs, opts.treeArgs)
	}
}
