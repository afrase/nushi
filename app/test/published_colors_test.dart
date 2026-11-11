// A named third-party theme draws what it's known by in its published
// colors (ADR 0086): the surfaces, the body text, the selection, code's
// colors, a diff's fills and the terminal's sixteen, each as its source
// has it (docs/development.md's Dependencies names each source and its
// version). These are not held to the contrast floors of `tokens_test`:
// code's colors, the terminal's and a diff's, and the transcript's body
// text are no pair of `contrastWarnings`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';

/// [t]'s colors by a theme file's names, and its terminal's own text.
Map<String, Color> _colors(Tokens t) => {
  ...tokenColors(t),
  'terminal.foreground': ?t.terminal.foreground,
};

void _published(String theme, Tokens t, Map<String, int> rgb) {
  final colors = _colors(t);
  for (final MapEntry(key: name, value: hex) in rgb.entries) {
    expect(
      colors[name],
      Color(0xFF000000 | hex),
      reason: '$theme: $name is #${hex.toRadixString(16).padLeft(6, '0')}',
    );
  }
}

void main() {
  test('Tokyo Night is tokyonight.nvim’s Night and Day', () {
    final tokyo = builtInTheme('tokyo-night')!;
    expect(tokyo.darkName, 'Tokyo Night');
    expect(tokyo.lightName, 'Tokyo Night Day');
    // extras/lua/tokyonight_night.lua.
    _published('Night', tokyo.dark, {
      'base': 0x1a1b26, // bg
      'window': 0x16161e, // bg_dark, the side bar's
      'codeBlock': 0x16161e,
      'lifted': 0x292e42, // bg_highlight
      'text': 0xc0caf5, // fg
      'agentText': 0xc0caf5,
      'textSecondary': 0xa9b1d6, // fg_dark
      'accent': 0x7aa2f7, // blue
      'link': 0x7aa2f7,
      'accentSoft': 0x283457, // bg_visual, the selection
      'userBand': 0x283457,
      'needs': 0xe0af68, // yellow
      'done': 0x9ece6a, // green
      'crashed': 0xf7768e, // red
      'syntax.comment': 0x565f89,
      'syntax.keyword': 0xbb9af7, // magenta
      'syntax.declaration': 0x7aa2f7, // blue
      'syntax.type': 0x2ac3de, // blue1
      'syntax.string': 0x9ece6a, // green
      'syntax.number': 0xff9e64, // orange
      'syntax.constant': 0xff9e64,
      'syntax.regexp': 0xb4f9f8, // blue6
      'syntax.field': 0x73daca, // green1
      'syntax.symbol': 0x89ddff, // blue5
      'syntax.parameter': 0xe0af68, // yellow
      'syntax.meta': 0x7dcfff, // cyan
      'syntax.tag': 0xf7768e, // red
      'terminal.black': 0x15161e,
      'terminal.red': 0xf7768e,
      'terminal.green': 0x9ece6a,
      'terminal.yellow': 0xe0af68,
      'terminal.blue': 0x7aa2f7,
      'terminal.magenta': 0xbb9af7,
      'terminal.cyan': 0x7dcfff,
      'terminal.white': 0xa9b1d6,
      'terminal.brightBlack': 0x414868,
      'terminal.brightRed': 0xff899d,
      'terminal.brightGreen': 0x9fe044,
      'terminal.brightYellow': 0xfaba4a,
      'terminal.brightBlue': 0x8db0ff,
      'terminal.brightMagenta': 0xc7a9ff,
      'terminal.brightCyan': 0xa4daff,
      'terminal.brightWhite': 0xc0caf5,
      'diff.background': 0x1a1b26,
      'diff.text': 0xc0caf5,
      'diff.insertedLine': 0x243e4a, // diff.add
      'diff.deletedLine': 0x4a272f, // diff.delete
      'diff.modifiedLine': 0x1f2231, // diff.change
      'diff.modifiedWord': 0x394b70, // diff.text
    });
    // The terminal's text is the theme's, fg.
    expect(tokyo.dark.terminal.foreground, isNull);
    // extras/lua/tokyonight_day.lua.
    _published('Day', tokyo.light, {
      'base': 0xe1e2e7, // bg
      'window': 0xd0d5e3, // bg_dark, the side bar's
      'codeBlock': 0xd0d5e3,
      'selected': 0xc4c8da, // bg_highlight
      'agentText': 0x3760bf, // fg
      'accentSoft': 0xb7c1e3, // bg_visual, the selection
      'userBand': 0xb7c1e3,
      'syntax.comment': 0x848cb5,
      'syntax.keyword': 0x9854f1, // magenta
      'syntax.declaration': 0x2e7de9, // blue
      'syntax.type': 0x188092, // blue1
      'syntax.string': 0x587539, // green
      'syntax.number': 0xb15c00, // orange
      'syntax.constant': 0xb15c00,
      'syntax.regexp': 0x2e5857, // blue6
      'syntax.field': 0x387068, // green1
      'syntax.symbol': 0x006a83, // blue5
      'syntax.parameter': 0x8c6c3e, // yellow
      'syntax.meta': 0x007197, // cyan
      'syntax.tag': 0xf52a65, // red
      'terminal.foreground': 0x3760bf, // fg
      'terminal.black': 0xb4b5b9,
      'terminal.red': 0xf52a65,
      'terminal.green': 0x587539,
      'terminal.yellow': 0x8c6c3e,
      'terminal.blue': 0x2e7de9,
      'terminal.magenta': 0x9854f1,
      'terminal.cyan': 0x007197,
      'terminal.white': 0x6172b0,
      'terminal.brightBlack': 0xa1a6c5,
      'terminal.brightRed': 0xff4774,
      'terminal.brightGreen': 0x5c8524,
      'terminal.brightYellow': 0xa27629,
      'terminal.brightBlue': 0x358aff,
      'terminal.brightMagenta': 0xa463ff,
      'terminal.brightCyan': 0x007ea8,
      'terminal.brightWhite': 0x3760bf,
      'diff.background': 0xe1e2e7,
      'diff.text': 0x3760bf,
      'diff.insertedLine': 0xb7ced5, // diff.add
      'diff.deletedLine': 0xdababe, // diff.delete
      'diff.modifiedLine': 0xd5d9e4, // diff.change
      'diff.modifiedWord': 0x92a6d5, // diff.text
    });
  });

  test('Solarized’s code is its sixteen, and its light terminal', () {
    final solarized = builtInTheme('solarized')!;
    // altercation/solarized's table, and its Vim scheme's groups.
    const accents = {
      'syntax.keyword': 0x859900, // green
      'syntax.declaration': 0x268bd2, // blue
      'syntax.type': 0xb58900, // yellow
      'syntax.string': 0x2aa198, // cyan
      'syntax.number': 0xd33682, // magenta
      'syntax.regexp': 0xdc322f, // red
      'syntax.constant': 0x6c71c4, // violet
      'syntax.meta': 0xcb4b16, // orange
    };
    const ansi = {
      'terminal.black': 0x073642, // base02
      'terminal.red': 0xdc322f,
      'terminal.green': 0x859900,
      'terminal.yellow': 0xb58900,
      'terminal.blue': 0x268bd2,
      'terminal.magenta': 0xd33682,
      'terminal.cyan': 0x2aa198,
      'terminal.white': 0xeee8d5, // base2
      'terminal.brightRed': 0xcb4b16, // orange
      'terminal.brightMagenta': 0x6c71c4, // violet
      'terminal.brightWhite': 0xfdf6e3, // base3
    };
    _published('Solarized Dark', solarized.dark, {
      'base': 0x002b36, // base03
      'raised': 0x073642, // base02
      ...accents,
      'syntax.comment': 0x586e75, // base01
      'syntax.parameter': 0x93a1a1, // base1
      ...ansi,
    });
    _published('Solarized Light', solarized.light, {
      'base': 0xfdf6e3, // base3
      'window': 0xeee8d5, // base2
      ...accents,
      'syntax.comment': 0x93a1a1, // base1
      'syntax.parameter': 0x586e75, // base01
      ...ansi,
      'terminal.brightBlack': 0x002b36, // base03
      'terminal.brightGreen': 0x586e75, // base01
      'terminal.brightYellow': 0x657b83, // base00
      'terminal.brightBlue': 0x839496, // base0
      'terminal.brightCyan': 0x93a1a1, // base1
    });
  });

  test('Nord’s dark code and terminal are nord0 to nord15', () {
    // nordtheme/nord's sixteen; the comment is nordtheme/visual-studio-code
    // 0.19.0's.
    _published('Nord', builtInTheme('nord')!.dark, {
      'base': 0x2e3440, // nord0
      'raised': 0x3b4252, // nord1
      'lifted': 0x434c5e, // nord2
      'text': 0xeceff4, // nord6
      'syntax.keyword': 0x81a1c1, // nord9
      'syntax.tag': 0x81a1c1,
      'syntax.declaration': 0x88c0d0, // nord8
      'syntax.type': 0x8fbcbb, // nord7
      'syntax.string': 0xa3be8c, // nord14
      'syntax.number': 0xb48ead, // nord15
      'syntax.constant': 0xb48ead,
      'syntax.regexp': 0xebcb8b, // nord13
      'syntax.meta': 0xd08770, // nord12
      'syntax.comment': 0x616e88,
      'terminal.black': 0x3b4252,
      'terminal.red': 0xbf616a,
      'terminal.green': 0xa3be8c,
      'terminal.yellow': 0xebcb8b,
      'terminal.blue': 0x81a1c1,
      'terminal.magenta': 0xb48ead,
      'terminal.cyan': 0x88c0d0,
      'terminal.white': 0xe5e9f0,
      'terminal.brightBlack': 0x4c566a,
      'terminal.brightCyan': 0x8fbcbb,
      'terminal.brightWhite': 0xeceff4,
    });
  });

  test('Catppuccin is Mocha and Latte', () {
    final catppuccin = builtInTheme('catppuccin')!;
    expect(catppuccin.darkName, 'Catppuccin Mocha');
    expect(catppuccin.lightName, 'Catppuccin Latte');
    // catppuccin/palette 1.8.0; the terminals' as catppuccin/kitty's.
    _published('Mocha', catppuccin.dark, {
      'window': 0x11111b, // crust
      'base': 0x1e1e2e,
      'codeBlock': 0x181825, // mantle
      'text': 0xcdd6f4,
      'accent': 0xcba6f7, // mauve
      'syntax.keyword': 0xcba6f7,
      'syntax.declaration': 0x89b4fa, // blue
      'syntax.type': 0xf9e2af, // yellow
      'syntax.string': 0xa6e3a1, // green
      'syntax.number': 0xfab387, // peach
      'syntax.regexp': 0xf5c2e7, // pink
      'syntax.field': 0xb4befe, // lavender
      'syntax.symbol': 0xf2cdcd, // flamingo
      'syntax.parameter': 0xeba0ac, // maroon
      'syntax.comment': 0x9399b2, // overlay2
      'terminal.black': 0x45475a,
      'terminal.red': 0xf38ba8,
      'terminal.green': 0xa6e3a1,
      'terminal.yellow': 0xf9e2af,
      'terminal.blue': 0x89b4fa,
      'terminal.magenta': 0xf5c2e7,
      'terminal.cyan': 0x94e2d5,
      'terminal.white': 0xbac2de,
      'terminal.brightBlack': 0x585b70,
      'terminal.brightWhite': 0xa6adc8,
    });
    _published('Latte', catppuccin.light, {
      'window': 0xdce0e8, // crust
      'base': 0xeff1f5,
      'raised': 0xe6e9ef, // mantle
      'text': 0x4c4f69,
      'accent': 0x8839ef, // mauve
      'syntax.keyword': 0x8839ef,
      'syntax.declaration': 0x1e66f5, // blue
      'syntax.type': 0xdf8e1d, // yellow
      'syntax.string': 0x40a02b, // green
      'syntax.number': 0xfe640b, // peach
      'syntax.regexp': 0xea76cb, // pink
      'syntax.field': 0x7287fd, // lavender
      'syntax.symbol': 0xdd7878, // flamingo
      'syntax.parameter': 0xe64553, // maroon
      'syntax.comment': 0x7c7f93, // overlay2
      'terminal.black': 0x5c5f77,
      'terminal.red': 0xd20f39,
      'terminal.green': 0x40a02b,
      'terminal.yellow': 0xdf8e1d,
      'terminal.blue': 0x1e66f5,
      'terminal.magenta': 0xea76cb,
      'terminal.cyan': 0x179299,
      'terminal.white': 0xacb0be,
      'terminal.brightBlack': 0x6c6f85,
      'terminal.brightGreen': 0x40a02b,
      'terminal.brightYellow': 0xdf8e1d,
      'terminal.brightMagenta': 0xea76cb,
      'terminal.brightWhite': 0xbcc0cc,
    });
  });

  test('code’s colors, the terminal’s, a diff’s and the body text are '
      'no pair of the contrast warnings', () {
    // Each drawn in the pane's own fill, where nothing could read it.
    final t = builtInTheme('tokyo-night')!.light;
    final hidden = withColors(t, {
      for (final name in tokenColors(t).keys)
        if (name.startsWith('syntax.') ||
            name.startsWith('terminal.') ||
            name.startsWith('diff.') ||
            name == 'agentText')
          name: t.base,
    });
    expect(hidden.ink(Capture.comment).color, t.base);
    expect(contrastWarnings(hidden), isEmpty);
  });

  test('a theme file keeps the terminal text of the theme it starts '
      'from', () {
    final f = readThemeFile('T.json', '{"from": "tokyo-night"}');
    expect(f.theme!.light.terminal.foreground, const Color(0xFF3760BF));
  });
}
