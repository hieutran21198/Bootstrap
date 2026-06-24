// better-tree
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"
)

var treeLineRe = regexp.MustCompile(`^((?:│   |    )*)(├── |└── )(.*)$`)

type options struct {
	tabular       bool
	docOnly       bool
	commentColumn int
	treeArgs      []string
}

type patchedLine struct {
	line string
	desc string
}

func main() {
	opts := parseArgs(os.Args[1:])

	descriptions, err := loadDescriptions()
	if err != nil {
		fmt.Fprintf(os.Stderr, "better-tree: failed to load descriptions: %v\n", err)
		os.Exit(1)
	}

	treeArgs := append([]string{
		"-n",
		"--noreport",
		"--gitignore",
		"--info",
	}, opts.treeArgs...)

	output, err := runTree(treeArgs)
	if err != nil {
		fmt.Fprintf(os.Stderr, "better-tree: %v\n", err)
		os.Exit(1)
	}

	lines := patchTreeOutput(output, descriptions)
	printPatchedLines(lines, opts)
}

func parseArgs(args []string) options {
	opts := options{
		commentColumn: 32,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]

		switch {
		case arg == "--tabular":
			opts.tabular = true

		case arg == "--doc-only":
			opts.docOnly = true

		case arg == "--comment-column":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "better-tree: --comment-column requires a number")
				os.Exit(2)
			}

			column, err := strconv.Atoi(args[i+1])
			if err != nil || column < 1 {
				fmt.Fprintln(os.Stderr, "better-tree: invalid --comment-column")
				os.Exit(2)
			}

			opts.commentColumn = column
			i++

		case strings.HasPrefix(arg, "--comment-column="):
			raw := strings.TrimPrefix(arg, "--comment-column=")

			column, err := strconv.Atoi(raw)
			if err != nil || column < 1 {
				fmt.Fprintln(os.Stderr, "better-tree: invalid --comment-column")
				os.Exit(2)
			}

			opts.commentColumn = column

		default:
			opts.treeArgs = append(opts.treeArgs, arg)
		}
	}

	return opts
}

func loadDescriptions() (map[string]string, error) {
	raw := os.Getenv("WORKSPACE_TREE_DESCRIPTIONS")
	if strings.TrimSpace(raw) == "" {
		return map[string]string{}, nil
	}

	var descriptions map[string]string
	if err := json.Unmarshal([]byte(raw), &descriptions); err != nil {
		return nil, err
	}

	return descriptions, nil
}

func runTree(args []string) (string, error) {
	cmd := exec.Command("tree", args...)

	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", err
	}

	return stdout.String(), nil
}

func patchTreeOutput(output string, descriptions map[string]string) []patchedLine {
	scanner := bufio.NewScanner(strings.NewReader(output))

	stack := make([]string, 0, 32)
	lines := make([]patchedLine, 0, 128)

	for scanner.Scan() {
		line := scanner.Text()

		if desc, ok := parseInfoLine(line); ok {
			if len(lines) > 0 {
				lines[len(lines)-1].desc = desc
			}
			continue
		}

		if line == "." {
			lines = append(lines, patchedLine{line: line})
			continue
		}

		normalizedLine := strings.ReplaceAll(line, "\u00a0", " ")
		matches := treeLineRe.FindStringSubmatch(normalizedLine)
		if matches == nil {
			lines = append(lines, patchedLine{line: line})
			continue
		}

		prefix := matches[1]
		rawName := matches[3]

		level := prefixLevel(prefix)
		name := cleanName(rawName)

		if level < len(stack) {
			stack = stack[:level]
		}

		path := joinPath(stack, name)
		desc := descriptions[path]

		lines = append(lines, patchedLine{
			line: line,
			desc: desc,
		})

		stack = append(stack, name)
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "better-tree: failed to scan tree output: %v\n", err)
	}

	return lines
}

func printPatchedLines(lines []patchedLine, opts options) {
	for _, line := range formatPatchedLines(lines, opts) {
		fmt.Println(line)
	}
}

func formatPatchedLines(lines []patchedLine, opts options) []string {
	column := opts.commentColumn

	if opts.tabular {
		maxWidth := column

		for _, item := range lines {
			if item.desc == "" {
				continue
			}

			width := displayWidth(item.line)
			if width+2 > maxWidth {
				maxWidth = width + 2
			}
		}

		column = maxWidth
	}

	formatted := make([]string, 0, len(lines))

	for _, item := range lines {
		if opts.docOnly && item.desc == "" {
			continue
		}

		if item.desc == "" {
			formatted = append(formatted, item.line)
			continue
		}

		if opts.tabular {
			padding := column - displayWidth(item.line)
			if padding < 2 {
				padding = 2
			}

			formatted = append(formatted, fmt.Sprintf("%s%s# %s", item.line, strings.Repeat(" ", padding), item.desc))
			continue
		}

		formatted = append(formatted, fmt.Sprintf("%s  # %s", item.line, item.desc))
	}

	return formatted
}

func parseInfoLine(line string) (string, bool) {
	normalizedLine := strings.ReplaceAll(line, "\u00a0", " ")
	openBrace := strings.Index(normalizedLine, "{")
	if openBrace < 0 {
		return "", false
	}

	prefix := strings.Trim(normalizedLine[:openBrace], " │\t")
	if prefix != "" {
		return "", false
	}

	desc := strings.TrimSpace(normalizedLine[openBrace+1:])
	return desc, desc != ""
}

func prefixLevel(prefix string) int {
	level := 0

	for prefix != "" {
		switch {
		case strings.HasPrefix(prefix, "│   "):
			level++
			prefix = strings.TrimPrefix(prefix, "│   ")
		case strings.HasPrefix(prefix, "    "):
			level++
			prefix = strings.TrimPrefix(prefix, "    ")
		default:
			return level
		}
	}

	return level
}

func cleanName(name string) string {
	name = strings.SplitN(name, " -> ", 2)[0]
	name = strings.TrimSuffix(name, "/")

	return name
}

func joinPath(stack []string, name string) string {
	parts := append([]string{}, stack...)
	parts = append(parts, name)

	return strings.Join(parts, "/")
}

func displayWidth(s string) int {
	return utf8.RuneCountInString(s)
}
