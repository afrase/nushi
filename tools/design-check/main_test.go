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
		"say.dart":     "m.showSnackBar(SnackBar(content: c));\naction: SnackBarAction(label: l),\nm.hideCurrentSnackBar();\n",
		// A control's timing is motion.dart's too.
		"controls_small.dart": "duration: const Duration(milliseconds: 120),\n",
		// Fine: the shared pieces, a token, a marked line, comments, names
		// that only look alike.
		"fine.dart": "tooltip(context, 'x', c);\nColors.transparent;\nTooltipThemeData();\nfontSize: style.fontSize! * 2,\n" +
			"// a Tooltip( in a comment\nfinal s = TextStyle(fontSize: 0); // design: hidden\n" +
			"// design: a QR code is dark on white\ncolor: Colors.white,\nwithKey('Close', '⌘W');\n" +
			"label: 'Send (3)',\ntooltip: 'Run tests',\nfinal c = t.text; // Colors.red was too loud\n" +
			"const Duration(seconds: 10);\nduration: Motion.quick,\n// design: a debounce, not motion\nTimer(const Duration(milliseconds: 250), f);\n",
		// Corners (ADR 0110): numbers flagged, the controls' too; tokens,
		// a square corner, a circle and a marked size pass.
		"corner.dart": "borderRadius: BorderRadius.circular(6),\nconst Radius.circular(2.5)\nradius: 14,\nbox(t.border, radius: 8)\n" +
			"radius: 0,\nradius: NushiTheme.control,\nBorderRadius.circular(NushiTheme.pill)\nBoxShadow(color: t.shadow, blurRadius: 12)\n" +
			"Radius.circular(thickness / 2)\nradius: 9, // not a corner: the circle\n  // not a corner: its splash\nradius: 9,\n" +
			"BorderRadius.all(Radius.circular(4)).fromCircle(4)\nradius: 9, // design: a dot\n",
		"controls_menus.dart": "borderRadius: BorderRadius.circular(6),\n",
		// One press path: Material's ink, a ListTile or a hand-kept press,
		// in a view or another control's file, but in controls_press.dart,
		// which makes Pressable; a marked line and a look-alike name pass.
		"press.dart": "InkWell(onTap: f, child: c);\nreturn InkResponse(onTap: f);\nListTile(title: t),\n" +
			"FocusableActionDetector(actions: a);\nPressWatch(onPress: p, child: c);\n" +
			"// design: a switch's row\nListTile(onTap: f),\nListTileTheme(data: d);\nTap(onTap: f, child: c);\n",
		"controls_toggle.dart": "child: InkWell(onTap: f),\n",
		// A GestureDetector that takes a primary tap, flagged on the line
		// it opens, however laid out; a right-click's or a drag's, a tap
		// of a nested call's, a marked one and a name in a string pass.
		"gesture.dart": "GestureDetector(onTap: f, child: c);\nreturn GestureDetector(\n  behavior: b,\n  onDoubleTap: f,\n);\n" +
			"GestureDetector(onSecondaryTapUp: f, onPanStart: g);\nGestureDetector(\n  child: Tap(onTap: f),\n);\n" +
			"// design: an image's zoom\nGestureDetector(onTap: f);\nGestureDetector(onTapUp: f); // design: the dim\n" +
			"text('GestureDetector(onTap:');\nchild: GestureDetector(\n  onTapDown: (d) => f(d),\n  child: GestureDetector(onTap: g),\n);\n",
		"controls_press.dart": "child: FocusableActionDetector(\nchild: PressWatch(\nGestureDetector(onTap: f);\n",
		// The type scale: a step passes, between steps fails, however the
		// call is laid out; only ui() and code() are read, each branch of a
		// ternary, and only the call's own size:, not a nested call's.
		"scale.dart": "theme.ui(t.text, size: 12.5)\ntheme.code(t.text, size: 12)\ntheme.ui(\n  t.text,\n  size: 14.5,\n  weight: w,\n)\n" +
			"Icon(i, size: 12.5)\ntheme.ui(t.text, size: base * 0.9)\ntheme.ui(f('(', 1), size: 18).copyWith(height: 1)\n" +
			"theme.ui(t.text, size: 16)\n// design: the pairing code\ntheme.code(t.text, size: 40)\n" +
			"theme.ui(t.text, size: small ? 12.5 : 13)\ntheme.ui(colorOf(Icon(i, size: 18)), size: 13)\n" +
			"theme.code(t.text, size: small ? 12 : 13)\ntheme.ui(t.text, size: a ? 12 : 13.5, weight: w)\n" +
			"theme.ui(t.text, size: a ? 1.5 : 2.5)\n",
		"phone/scale.dart":       "theme.ui(t.text, size: 16)\ntheme.ui(t.text, size: 17)\n",
		"motion.dart":            "static const quick = Duration(milliseconds: 120);\n",
		"toast.dart":             "messenger.showSnackBar(SnackBar(content: c));\n",
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
		rel, _ := filepath.Rel(root, u.Path)
		got = append(got, rel+":"+strconv.Itoa(u.Line)+": "+u.What)
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
		snack  = "a raw snack bar: showToast"
	)
	cornerAt := func(at string) string { return at + ": " + corner }
	want := []string{
		"button.dart:1: " + button,
		"button.dart:2: " + button,
		"color.dart:1: " + raw,
		"color.dart:2: " + named,
		"controls_menus.dart:1: " + corner,
		"controls_small.dart:1: " + ms,
		"controls_toggle.dart:1: " + pressPath,
		cornerAt("corner.dart:1"), cornerAt("corner.dart:2"), cornerAt("corner.dart:3"), cornerAt("corner.dart:4"),
		"dialog.dart:1: " + dialog,
		"gesture.dart:14: " + pressPath, // sorted as text
		"gesture.dart:16: " + pressPath,
		"gesture.dart:1: " + pressPath,
		"gesture.dart:2: " + pressPath,
		"keys.dart:1: " + keyInString,
		"keys.dart:2: " + keyInString,
		"keys.dart:3: " + keyInString,
		"keys.dart:4: " + keyInString,
		"phone/scale.dart:2: " + offScale,
		"phone/x.dart:1: " + button,
		"press.dart:1: " + pressPath,
		"press.dart:2: " + pressPath,
		"press.dart:3: " + pressPath,
		"press.dart:4: " + pressPath,
		"press.dart:5: " + pressPath,
		"say.dart:1: " + snack,
		"say.dart:2: " + snack,
		"scale.dart:10: " + offScale, // sorted as text
		"scale.dart:11: " + offScale,
		"scale.dart:14: " + offScale,
		"scale.dart:17: " + offScale,
		"scale.dart:18: " + offScale, // once, however many sizes are off
		"scale.dart:1: " + offScale,
		"scale.dart:5: " + offScale,
		"size.dart:1: " + size,
		"tip.dart:1: " + tip,
		"wait.dart:1: " + ms,
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}
