// Command design-check fails on app code that goes around the design
// system's shared pieces (docs/design.md): a raw Tooltip (Pressable's
// tooltip or tooltip() instead), a Material button (Button, IconTap,
// LinkText…), an AlertDialog outside nushiDialog, a tooltip's shortcut in
// brackets or after spaces (withKey instead), a raw Color(0x…) or a
// Colors.<name> other than transparent (a token instead), a fontSize
// literal (NushiTheme's ui() or code() at a size instead), a size given
// to ui() or code() off the type scale, a Duration(milliseconds: …)
// literal (Motion's or Waits' instead), a raw SnackBar (showToast
// instead, toast.dart's), a corner as a number (a radius token
// instead, ADR 0110), and a second press path (Material's ink, a ListTile,
// a GestureDetector that takes a tap, or hover, focus and press kept by
// hand: Tap or Pressable instead, which show a press at once, take the
// keyboard's focus and say button to a screen reader). The controls'
// and the theme's own files make the pieces, so they're left out, the
// controls' files but for durations, corners, the type scale and the
// press path (controls_press.dart makes it), and so are motion.dart for
// durations,
// toast.dart for the snack bar it makes, and generated code. A deliberate
// use stays with a marker on its line or alone on the line above:
// `// design: <why>` (or `// not a corner: <why>` for a corner's rule
// alone). It prints each use and
// exits 1. make lint-dart runs it from the repository root over app/lib
// (or the folders it's given).
package main

import (
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/afrase/nushi/tools/dartcheck"
)

// rule is one way around the shared pieces: what finds it on a line and
// what to use instead.
type rule struct {
	pattern *regexp.Regexp
	what    string
	except  string // a match that's fine (Colors.transparent)
	// inControls: the rule holds in the controls' files too, which make
	// the shared pieces but take their timing from motion.dart like any
	// view.
	inControls bool
	// notIn is a file the rule leaves out (motion.dart, which names the
	// durations).
	notIn string
	// skip finds a line the rule passes (a circle's corners).
	skip *regexp.Regexp
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
	{regexp.MustCompile(`\bTooltip\(`), "a raw Tooltip: Pressable's or Tap's tooltip, or tooltip()", "", false, "", nil},
	{regexp.MustCompile(`\b(?:ElevatedButton|TextButton|OutlinedButton|IconButton|FilledButton)\b`), "a Material button: Button, IconTap, LinkText or another of controls.dart's", "", false, "", nil},
	{regexp.MustCompile(`\bAlertDialog\(`), "an AlertDialog: nushiDialog or confirm", "", false, "", nil},
	{regexp.MustCompile(`\bColor\(0x`), "a raw color: a token of theme/tokens.dart", "", false, "", nil},
	{regexp.MustCompile(`\bColors\.[a-z]\w*`), "a Material color: a token of theme/tokens.dart", "Colors.transparent", false, "", nil},
	{regexp.MustCompile(`\bfontSize:\s*\d`), "a font size: NushiTheme's ui() or code() at a size", "", false, "", nil},
	{regexp.MustCompile(`\bSnackBar(?:Action)?\(`), "a raw snack bar: showToast", "", false, "toast.dart", nil},
	{
		regexp.MustCompile(`\bDuration\(\s*milliseconds:`),
		"a duration in milliseconds: one of motion.dart's Motion or Waits",
		"", true, "motion.dart", nil,
	},
	// A corner written as a number (Radius.circular(6), so
	// BorderRadius.circular(6) too, or radius: 6); radius: 0 is a square
	// corner, no radius at all, and a circle's size isn't a corner.
	{
		regexp.MustCompile(`Radius\.circular\(\s*[0-9.]+\s*\)|\bradius:\s*(?:0[0-9.]+|[1-9.][0-9.]*)\s*(?:[,)]|$)`),
		corner, "", true, "", regexp.MustCompile(`fromCircle\(`),
	},
	{
		regexp.MustCompile(`\b(?:InkWell|InkResponse|ListTile|FocusableActionDetector|PressWatch)\(`),
		pressPath, "", true, "controls_press.dart", nil,
	},
}

// pressPath is the press rule's verdict: Pressable is the one press path
// (ADR 0049), Tap a row's or a tab's on it.
const pressPath = "a second press path: Tap or Pressable (controls_press.dart)"

// keyInString is the rule on what a string says: a tooltip's shortcut is
// written with withKey, never "(⌘K)" or "Close  ⌘W".
const keyInString = "a shortcut in brackets or after spaces: withKey(label, key)"

// marker on a line, or alone on the line above, keeps a deliberate use;
// cornerMarker does for the corner rule only (ADR 0110 named it first).
const (
	marker       = "// design:"
	cornerMarker = "// not a corner: "
)

// corner is the corner rule's verdict (ADR 0110).
const corner = "a corner as a number: NushiTheme.tag, control, card, panel or pill, or NushiTheme.inner of one " +
	"(a size that isn't a corner takes // not a corner: <why>)"

func main() {
	os.Exit(dartcheck.Run("design-check", "Use the shared piece (docs/design.md), or keep a deliberate use with `// design: <why>` "+
		"on its line or alone on the line above.", check))
}

// check lists the lines that go around a shared piece in the Dart files
// under root, the controls', the theme's and generated code left out.
func check(root string) ([]dartcheck.Use, error) {
	var uses []dartcheck.Use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir():
			if rel, _ := filepath.Rel(root, path); rel == "gen" || rel == "theme" {
				return filepath.SkipDir
			}
			return nil
		case !strings.HasSuffix(path, ".dart") || dartcheck.Generated(path):
			return nil
		}
		found, err := inFile(path, controls(path))
		uses = append(uses, found...)
		return err
	})
	return uses, err
}

// controls says whether path makes the shared pieces (controls.dart and
// its parts).
func controls(path string) bool {
	base := filepath.Base(path)
	return base == "controls.dart" || strings.HasPrefix(base, "controls_")
}

// inFile lists one file's uses, comments and marked lines left out; in
// the controls' files ([controls]), only the rules that hold there.
func inFile(path string, controls bool) ([]dartcheck.Use, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var uses []dartcheck.Use
	var call styleCall
	var taps tapCalls
	pressOK := filepath.Base(path) == "controls_press.dart" // it makes the press path
	marked, cornerMarked := false, false                    // the line above is a marker alone
	for i, line := range strings.Split(string(b), "\n") {
		trimmed := strings.TrimSpace(line)
		above, cornerAbove := marked, cornerMarked
		marked = strings.HasPrefix(trimmed, marker)
		cornerMarked = strings.HasPrefix(trimmed, cornerMarker)
		if strings.HasPrefix(trimmed, "//") {
			continue
		}
		code := line
		if at := strings.Index(code, " // "); at >= 0 && !inString(code, at) {
			code = code[:at]
		}
		sizes := call.sizes(code) // a marked line's brackets still count
		isMarked := above || strings.Contains(line, marker)
		for _, at := range taps.pressLines(code, i+1, isMarked) {
			if !pressOK {
				uses = append(uses, dartcheck.Use{Path: path, Line: at, What: pressPath})
			}
		}
		if isMarked {
			continue
		}
		cornerOK := cornerAbove || strings.Contains(line, cornerMarker)
		for _, what := range onLine(code, filepath.Base(path), controls, cornerOK) {
			uses = append(uses, dartcheck.Use{Path: path, Line: i + 1, What: what})
		}
		for _, s := range sizes {
			if !onScale(s, path) {
				uses = append(uses, dartcheck.Use{Path: path, Line: i + 1, What: offScale})
				break // a line once
			}
		}
	}
	return uses, nil
}

// onLine lists what one line of code (its comment cut) goes around, in
// the file named base; in the controls' files, only the rules that hold
// there; cornerOK when the line is marked as not a corner.
func onLine(code, base string, controls, cornerOK bool) []string {
	var found []string
	for _, r := range rules {
		if controls && !r.inControls || r.notIn == base || cornerOK && r.what == corner ||
			r.skip != nil && r.skip.MatchString(code) {
			continue
		}
		for _, m := range r.pattern.FindAllString(code, -1) {
			if m != r.except {
				found = append(found, r.what)
				break
			}
		}
	}
	if controls {
		return found
	}
	for _, s := range stringLiteral.FindAllString(code, -1) {
		if bracketedKey.MatchString(s) || spacedKey.MatchString(s) {
			return append(found, keyInString)
		}
	}
	return found
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
