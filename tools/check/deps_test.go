package main

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// The repository's root, from this package's folder, where go test runs.
const repoRoot = "../.."

// docs/development.md's Dependencies section names every module go.mod
// requires directly and every package the app's pubspec depends on (but
// Flutter's SDK and the repository's own packages), each with why it's
// there: depguard is off for this list (.golangci.yml), so nothing else
// notices a dependency added without a word.
func TestDependenciesAreNamed(t *testing.T) {
	section := dependenciesSection(t)
	var missing []string
	for _, name := range append(goRequires(t), pubspecPackages(t, "app/pubspec.yaml")...) {
		// A name in backticks, alone or as a package path under it
		// (`golang.org/x/sys/unix` names golang.org/x/sys).
		named := regexp.MustCompile("`" + regexp.QuoteMeta(name) + "[`/]")
		if !named.MatchString(section) {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		t.Errorf("docs/development.md's Dependencies doesn't name %q: add each, with what it's for and its licence", missing)
	}
}

// dependenciesSection is the text of development.md's Dependencies.
func dependenciesSection(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(repoRoot, "docs", "development.md"))
	if err != nil {
		t.Fatal(err)
	}
	_, after, ok := strings.Cut(string(b), "\n## Dependencies\n")
	if !ok {
		t.Fatal("docs/development.md has no Dependencies section")
	}
	if end := strings.Index(after, "\n## "); end >= 0 {
		after = after[:end]
	}
	return after
}

// goRequires lists the modules go.mod requires directly.
func goRequires(t *testing.T) []string {
	t.Helper()
	var mods []string
	inBlock := false
	for _, line := range lines(t, "go.mod") {
		f := strings.Fields(line)
		switch {
		case len(f) == 2 && f[0] == "require" && f[1] == "(":
			inBlock = true
		case inBlock && len(f) == 1 && f[0] == ")":
			inBlock = false
		case strings.Contains(line, "// indirect"):
		case inBlock && len(f) >= 2:
			mods = append(mods, f[0])
		case len(f) >= 3 && f[0] == "require":
			mods = append(mods, f[1])
		}
	}
	if len(mods) == 0 {
		t.Fatal("go.mod requires nothing directly?")
	}
	return mods
}

// pubspecPackages lists a pubspec's dependencies and dev_dependencies,
// leaving out the SDK's (sdk:) and the repository's own (path:).
func pubspecPackages(t *testing.T, name string) []string {
	t.Helper()
	var pkgs []string
	inDeps := false
	current := ""
	keep := func() {
		if current != "" {
			pkgs = append(pkgs, current)
		}
		current = ""
	}
	for _, line := range lines(t, name) {
		switch {
		case line == "dependencies:" || line == "dev_dependencies:":
			keep()
			inDeps = true
		case !strings.HasPrefix(line, " ") && strings.TrimSpace(line) != "":
			keep()
			inDeps = false
		case !inDeps:
		case strings.HasPrefix(line, "    "):
			if f := strings.Fields(line); len(f) > 0 && (f[0] == "sdk:" || f[0] == "path:") {
				current = ""
			}
		case strings.HasPrefix(line, "  ") && strings.Contains(line, ":"):
			keep()
			current, _, _ = strings.Cut(strings.TrimSpace(line), ":")
		}
	}
	keep()
	if len(pkgs) == 0 {
		t.Fatalf("%s depends on nothing?", name)
	}
	return pkgs
}

// lines reads a file of the repository, a line at a time.
func lines(t *testing.T, name string) []string {
	t.Helper()
	f, err := os.Open(filepath.Join(repoRoot, name))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close() //nolint:errcheck // read only
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		out = append(out, sc.Text())
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	return out
}
