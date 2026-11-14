package main

import (
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"testing"
)

func TestCheck(t *testing.T) {
	root := t.TempDir()
	files := map[string]string{
		// Each way around a shared piece.
		"tip.dart":     "return Tooltip(message: 'x', child: c);\n",
		"button.dart":  "TextButton(onPressed: f, child: c);\nIconButton(icon: i);\n",
		"dialog.dart":  "builder: (_) => AlertDialog(title: t),\n",
		"color.dart":   "final c = Color(0xFF112233);\nfinal d = Colors.white70;\n",
		"size.dart":    "TextStyle(fontSize: 12);\n",
		"keys.dart":    "tooltip: 'Forward (⌘])',\ntooltip: 'Close  ⌘W',\ntooltip: 'Find (${keyLabel(k)})',\nlabel: 'Back (${Act.back.shortcut})',\n",
		"phone/x.dart": "OutlinedButton(onPressed: f);\n",
		"wait.dart":    "Timer(const Duration(milliseconds: 150), f);\n",
		// A control's timing is motion.dart's too.
		"controls_small.dart": "duration: const Duration(milliseconds: 120),\n",
		// Fine: the shared pieces, a token, a marked line, comments, names
		// that only look alike.
		"fine.dart": "tooltip(context, 'x', c);\nColors.transparent;\nTooltipThemeData();\nfontSize: style.fontSize! * 2,\n" +
			"// a Tooltip( in a comment\nfinal s = TextStyle(fontSize: 0); // design: hidden\n" +
			"// design: a QR code is dark on white\ncolor: Colors.white,\nwithKey('Close', '⌘W');\n" +
			"label: 'Send (3)',\ntooltip: 'Run tests',\nfinal c = t.text; // Colors.red was too loud\n" +
			"const Duration(seconds: 10);\nduration: Motion.quick,\n// design: a debounce, not motion\nTimer(const Duration(milliseconds: 250), f);\n",
		"motion.dart":            "static const quick = Duration(milliseconds: 120);\n",
		"controls.dart":          "return Tooltip(message: m, child: c);\n",
		"controls_buttons.dart":  "Color(0x2E000000);\n",
		"theme/tokens.dart":      "base: Color(0xFFFFFFFF),\n",
		"gen/nushi/v1/x.pb.dart": "Colors.red;\n",
		"x.pb.dart":              "Colors.red;\n",
		"notes.txt":              "Tooltip(\n",
	}
	for name, body := range files {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	uses, err := check(root)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, u := range uses {
		rel, _ := filepath.Rel(root, u.path)
		got = append(got, rel+":"+strconv.Itoa(u.line)+": "+u.what)
	}
	slices.Sort(got)
	const (
		tip    = "a raw Tooltip: Pressable's or Tap's tooltip, or tooltip()"
		button = "a Material button: Button, IconTap, LinkText or another of controls.dart's"
		dialog = "an AlertDialog: nushiDialog or confirm"
		raw    = "a raw color: a token of theme/tokens.dart"
		named  = "a Material color: a token of theme/tokens.dart"
		size   = "a font size: NushiTheme's ui() or code() at a size"
		ms     = "a duration in milliseconds: one of motion.dart's Motion or Waits"
	)
	want := []string{
		"button.dart:1: " + button,
		"button.dart:2: " + button,
		"color.dart:1: " + raw,
		"color.dart:2: " + named,
		"controls_small.dart:1: " + ms,
		"dialog.dart:1: " + dialog,
		"keys.dart:1: " + keyInString,
		"keys.dart:2: " + keyInString,
		"keys.dart:3: " + keyInString,
		"keys.dart:4: " + keyInString,
		"phone/x.dart:1: " + button,
		"size.dart:1: " + size,
		"tip.dart:1: " + tip,
		"wait.dart:1: " + ms,
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}
