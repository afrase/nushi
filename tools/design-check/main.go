// Command design-check fails on app code that goes around the design
// system's shared pieces (docs/design.md): a raw Tooltip (Pressable's
// tooltip or tooltip() instead), a Material button (Button, IconTap,
// LinkText…), an AlertDialog outside nushiDialog, a tooltip's shortcut in
// brackets or after spaces (withKey instead), a raw Color(0x…) or a
// Colors.<name> other than transparent (a token instead), and a fontSize
// literal (NushiTheme's ui() or code() at a size instead). The controls'
// and the theme's own files make the pieces, so they're left out, and so
// is generated code. A deliberate use stays with a marker on its line or
// alone on the line above: `// design: <why>`. It prints each use and
// exits 1. make lint-dart runs it from the repository root over app/lib
// (or the folders it's given).
package main

import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// rule is one way around the shared pieces: what finds it on a line and
// what to use instead.
type rule struct {
	pattern *regexp.Regexp
	what    string
	except  string // a match that's fine (Colors.transparent)
}

// stringLiteral finds a Dart string literal on one line, for the rules
// about what a string says.
var stringLiteral = regexp.MustCompile(`'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"`)

// keyGlyph is a key's symbol as a shortcut is written (keys.dart).
const keyGlyph = `[⌘⌃⌥⇧⎋⏎↩]`

var (
	bracketedKey = regexp.MustCompile(`\(\s*(?:` + keyGlyph + `|Ctrl\+|Control\+|\$\{?keyLabel\b|\$\{?[\w.]*\.shortcut\b)`)
	spacedKey    = regexp.MustCompile(`\S {2,}` + keyGlyph)
)

// rules are checked on every line of code but comments, outside the
// controls' and the theme's files.
var rules = []rule{
	{regexp.MustCompile(`\bTooltip\(`), "a raw Tooltip: Pressable's or Tap's tooltip, or tooltip()", ""},
	{regexp.MustCompile(`\b(?:ElevatedButton|TextButton|OutlinedButton|IconButton|FilledButton)\b`), "a Material button: Button, IconTap, LinkText or another of controls.dart's", ""},
	{regexp.MustCompile(`\bAlertDialog\(`), "an AlertDialog: nushiDialog or confirm", ""},
	{regexp.MustCompile(`\bColor\(0x`), "a raw color: a token of theme/tokens.dart", ""},
	{regexp.MustCompile(`\bColors\.[a-z]\w*`), "a Material color: a token of theme/tokens.dart", "Colors.transparent"},
	{regexp.MustCompile(`\bfontSize:\s*\d`), "a font size: NushiTheme's ui() or code() at a size", ""},
}

// keyInString is the rule on what a string says: a tooltip's shortcut is
// written with withKey, never "(⌘K)" or "Close  ⌘W".
const keyInString = "a shortcut in brackets or after spaces: withKey(label, key)"

// marker on a line, or alone on the line above, keeps a deliberate use.
const marker = "// design:"

// generated are the suffixes of protoc's and Connect's Dart, left out.
var generated = []string{".pb.dart", ".pbenum.dart", ".pbjson.dart", ".pbserver.dart", ".pbgrpc.dart"}

// use is one line that goes around a shared piece.
type use struct {
	path string
	line int
	what string
}

func main() {
	roots := os.Args[1:]
	if len(roots) == 0 {
		roots = []string{"app/lib"}
	}
	var uses []use
	for _, root := range roots {
		found, err := check(root)
		if err != nil {
			fmt.Fprintln(os.Stderr, "design-check:", err)
			os.Exit(2)
		}
		uses = append(uses, found...)
	}
	for _, u := range uses {
		fmt.Fprintf(os.Stderr, "%s:%d: %s\n", u.path, u.line, u.what)
	}
	if len(uses) > 0 {
		fmt.Fprintln(os.Stderr, "Use the shared piece (docs/design.md), or keep a deliberate use with `// design: <why>` "+
			"on its line or alone on the line above.")
		os.Exit(1)
	}
}

// check lists the uses in the Dart files under root, the controls', the
// theme's and generated code left out.
func check(root string) ([]use, error) {
	var uses []use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir():
			if rel, _ := filepath.Rel(root, path); rel == "gen" || rel == "theme" {
				return filepath.SkipDir
			}
			return nil
		case !strings.HasSuffix(path, ".dart") || exempt(path):
			return nil
		}
		found, err := inFile(path)
		uses = append(uses, found...)
		return err
	})
	return uses, err
}

// exempt says whether path makes the shared pieces (controls.dart and its
// parts) or is generated.
func exempt(path string) bool {
	base := filepath.Base(path)
	if base == "controls.dart" || strings.HasPrefix(base, "controls_") {
		return true
	}
	for _, s := range generated {
		if strings.HasSuffix(base, s) {
			return true
		}
	}
	return strings.Contains(base, ".connect.")
}

// inFile lists one file's uses, comments and marked lines left out.
func inFile(path string) ([]use, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read only
	var uses []use
	marked := false // the line above is the marker alone
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := sc.Text()
		trimmed := strings.TrimSpace(line)
		above := marked
		marked = strings.HasPrefix(trimmed, marker)
		if above || strings.HasPrefix(trimmed, "//") || strings.Contains(line, marker) {
			continue
		}
		code := line
		if at := strings.Index(code, " // "); at >= 0 && !inString(code, at) {
			code = code[:at]
		}
		for _, r := range rules {
			for _, m := range r.pattern.FindAllString(code, -1) {
				if m != r.except {
					uses = append(uses, use{path, n, r.what})
					break
				}
			}
		}
		for _, s := range stringLiteral.FindAllString(code, -1) {
			if bracketedKey.MatchString(s) || spacedKey.MatchString(s) {
				uses = append(uses, use{path, n, keyInString})
				break
			}
		}
	}
	return uses, sc.Err()
}

// inString says whether byte at of line is inside a string literal.
func inString(line string, at int) bool {
	for _, span := range stringLiteral.FindAllStringIndex(line, -1) {
		if at > span[0] && at < span[1] {
			return true
		}
	}
	return false
}
