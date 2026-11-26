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
		"phone/scale.dart": "theme.ui(t.text, size: 16)\ntheme.ui(t.text, size: 17)\n",
		// A separator between a line's parts: a middle dot, a spaced en or
		// em dash, a hyphen with a space either side, in a string, the
		// controls' too; a minus in an interpolation, a range, a bullet,
		// a dash alone, a comment and a marked line pass.
		"dots.dart": "Text('a · b'),\n].join(' · '),\ntext: '  · ${w.twin}',\n'$shell — $folder',\n'Running – click',\n'$a - $b',\n" +
			"'and ${n - 1} more',\n'Lines 3–5',\n'• $name archives',\n'- [ ] task'\ndim ? '—' : p\n" +
			"// \"Plan · 2 of 4\"\nfinal r = RegExp(r'·.*·'); // design: a bot's text\n'a, b'\nx - y\n",
		// What the first rule missed (issue 119's review): a dot in a string
		// nested in an interpolation, a leading spaced hyphen, an em dash
		// spaced or not, a bullet as a join, a line inside a multi-line
		// string, each one's escape; a blank em dash, a masked secret, a
		// bullet starting an item and a multi-line string's plain lines pass.
		"nested.dart": "'${x.isEmpty ? '' : ' · ${x}'}'\n' - $state'\n'Running—click to cancel'\n].join(' • '),\n" +
			"text: \"\"\"\nfirst line\nPlan · 2 of 4\n\"\"\",\n" +
			"'\\u00b7'\n' \\u2014 '\n'a\\u{2022} b'.split(' \\u2022 ')\n'\\u2013 later \\u2013'\n" +
			"dim ? '—' : p\n'••••'\n'• first'\nr'\\u00b7'\n",
		// The second review's probes: a dash or hyphen between no-break
		// spaces (as written and as escapes), the dot operators and other
		// points that look like a middle dot, and a spaced hyphen that
		// starts the second of two adjacent literals (one string to Dart),
		// on one line and over two; then what must pass: a range, a minus in
		// an interpolation, a blank, Markdown items, counts, a command's
		// flag, comments, a mask, adjacent or separate literals that join
		// nothing, and a marked literal whose join the next one goes on
		// with (found on the marked line, not again on the next).
		"probes.dart": "'$a\u00a0–\u00a0$b',\n'$a\\u00a0\\u2013\\u00a0$b',\n'$a\u202f-\u202f$b',\n'a ∙ b',\n'a ⋅ b',\n" +
			"'a ‧ b',\n'a ・ b',\n'$a ' '- $b',\n'$a '\n    '- $b',\n'a \\u2219 b',\n" +
			"'3–5 files',\n'and ${n - 1} more'\ndim ? '—' : p,\n'- item\\n- [ ] next',\n'+$n −$m',\n'git log -n 5',\n" +
			"// a · b — c\n/* a – b */\n'••••',\n'first line ' 'second'\nf('$a ', '- b')\n'$a ' + '- b',\n" +
			"// design: the hyphen named\n'digits, - and _, and can\\'t '\n    'start with -.',\n",
		// The third review's probes: the middle dot's look-alikes (U+0387,
		// U+2E31, U+FF65), the rest of the dash class spaced (‒ ― ⸺), the
		// bullets ● and ▪ as a join, and an en dash between zero-width
		// spaces, as written and as escapes; then what passes: a range in
		// figure dashes, a horizontal bar alone (a blank), a bullet that
		// starts an item, a mask of ●, and two literals joined with + (not
		// judged as one string: the tool reads literals, not expressions).
		"probes3.dart": "'a \u0387 b',\n'a ⸱ b',\n'a ･ b',\n'$a ‒ $b',\n'$a ― $b',\n'$a ⸺ $b',\n" +
			"'a ● b',\n'a ▪ b',\n'$a\\u200b–\\u200b$b',\n'$a\u200b–\u200b$b',\n'a·b',\n" +
			"'3‒5 files',\ndim ? '―' : p,\n'● first',\n'●●●●',\n'$a ' + '- $b',\n'▪ item',\n",
		"theme/names.dart":       "label: 'Tokyo Night · Day',\n",
		"controls_dots.dart":     "label: 'Open · 2',\n",
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
		"controls_dots.dart:1: " + separator,
		"controls_menus.dart:1: " + corner,
		"controls_small.dart:1: " + ms,
		"controls_toggle.dart:1: " + pressPath,
		cornerAt("corner.dart:1"), cornerAt("corner.dart:2"), cornerAt("corner.dart:3"), cornerAt("corner.dart:4"),
		"dialog.dart:1: " + dialog,
		"dots.dart:1: " + separator,
		"dots.dart:2: " + separator,
		"dots.dart:3: " + separator,
		"dots.dart:4: " + separator,
		"dots.dart:5: " + separator,
		"dots.dart:6: " + separator,
		"gesture.dart:14: " + pressPath, // sorted as text
		"gesture.dart:16: " + pressPath,
		"gesture.dart:1: " + pressPath,
		"gesture.dart:2: " + pressPath,
		"keys.dart:1: " + keyInString,
		"keys.dart:2: " + keyInString,
		"keys.dart:3: " + keyInString,
		"keys.dart:4: " + keyInString,
		"nested.dart:10: " + separator, // sorted as text
		"nested.dart:11: " + separator,
		"nested.dart:12: " + separator,
		"nested.dart:1: " + separator,
		"nested.dart:2: " + separator,
		"nested.dart:3: " + separator,
		"nested.dart:4: " + separator,
		"nested.dart:7: " + separator,
		"nested.dart:9: " + separator,
		"phone/scale.dart:2: " + offScale,
		"phone/x.dart:1: " + button,
		"press.dart:1: " + pressPath,
		"press.dart:2: " + pressPath,
		"press.dart:3: " + pressPath,
		"press.dart:4: " + pressPath,
		"press.dart:5: " + pressPath,
		"probes.dart:10: " + separator, // sorted as text: the second of two lines
		"probes.dart:11: " + separator,
		"probes.dart:1: " + separator,
		"probes.dart:2: " + separator,
		"probes.dart:3: " + separator,
		"probes.dart:4: " + separator,
		"probes.dart:5: " + separator,
		"probes.dart:6: " + separator,
		"probes.dart:7: " + separator,
		"probes.dart:8: " + separator,
		"probes3.dart:10: " + separator, // sorted as text
		"probes3.dart:11: " + separator,
		"probes3.dart:1: " + separator,
		"probes3.dart:2: " + separator,
		"probes3.dart:3: " + separator,
		"probes3.dart:4: " + separator,
		"probes3.dart:5: " + separator,
		"probes3.dart:6: " + separator,
		"probes3.dart:7: " + separator,
		"probes3.dart:8: " + separator,
		"probes3.dart:9: " + separator,
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
		"theme/names.dart:1: " + separator,
		"tip.dart:1: " + tip,
		"wait.dart:1: " + ms,
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}
