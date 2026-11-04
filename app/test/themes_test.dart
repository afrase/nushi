// Themes (ADR 0086): the built-ins, a theme file's format, and the
// warning a custom theme under AA gets.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';

import 'theme_sets.dart';

void main() {
  test('the built-ins: Nushi first and the default, ids apart, each set '
      'whole and of its brightness', () {
    expect(builtInThemes.first, same(nushiTheme));
    expect(nushiTheme.dark, same(Tokens.dark));
    expect(nushiTheme.light, same(Tokens.light));
    expect({
      for (final c in builtInThemes) c.id,
    }, hasLength(builtInThemes.length));
    for (final c in builtInThemes) {
      expect(c.dark.brightness, Brightness.dark, reason: c.name);
      expect(c.light.brightness, Brightness.light, reason: c.name);
      expect(c.custom, isFalse);
      for (final t in [c.dark, c.light]) {
        expect(t.avatars, hasLength(avatarNames.length), reason: c.name);
        expect(t.syntax.keys, containsAll(Capture.values), reason: c.name);
      }
    }
  });

  test('no built-in set has a pair under AA, as Settings would warn', () {
    for (final (name, t) in everySet) {
      expect(contrastWarnings(t), isEmpty, reason: name);
    }
  });

  test('a theme file names chat colors as ChatColor does', () {
    expect(avatarNames, [for (final c in ChatColor.values) c.name]);
  });

  test('every token has a name, and a set rebuilt from its names is the '
      'same', () {
    final names = tokenColors(Tokens.dark);
    expect(names.length, 119);
    expect(names['base'], Tokens.dark.base);
    expect(names['avatars.teal'], Tokens.dark.avatars[1]);
    expect(names['syntax.keyword'], Tokens.dark.ink(Capture.keyword).color);
    expect(names['terminal.brightRed'], Tokens.dark.terminal.brightRed);
    expect(names['diff.insertedLine'], Tokens.dark.diff.insertedLine);
    expect(names['hover'], Tokens.dark.hover);
    for (final (name, t) in everySet) {
      expect(
        tokenColors(withColors(t, tokenColors(t))),
        tokenColors(t),
        reason: name,
      );
    }
    // Nushi's diff is diff_view's own: what it drew before themes.
    expect(Tokens.light.diff, same(DiffColors.intelliJLight));
    expect(Tokens.dark.terminal, same(TerminalColors.vsCodeDark));
  });

  test('a file written from a theme reads back as it, no notes', () {
    for (final c in builtInThemes) {
      final f = readThemeFile('Mine.json', writeThemeFile(c, 'Mine'));
      expect(f.notes, isEmpty, reason: c.name);
      expect(f.theme!.id, 'custom:Mine');
      expect(f.theme!.name, 'Mine');
      expect(f.theme!.custom, isTrue);
      // As the file has them: a tint's alpha (hover's) to 1/255.
      expect(_hex(f.theme!.dark), _hex(c.dark), reason: c.name);
      expect(_hex(f.theme!.light), _hex(c.light), reason: c.name);
    }
    final json = jsonDecode(writeThemeFile(builtInThemes[3], 'N')) as Map;
    expect(json['from'], 'nord');
    expect((json['dark'] as Map)['base'], '#2E3440');
    expect((json['dark'] as Map)['hover'], startsWith('#13'));
  });

  test('a partial file changes what it names, from the theme it starts '
      'from', () {
    final f = readThemeFile(
      'Night.json',
      '{"from": "nord", "dark": {"base": "#101010", "accent": "#80FF0000"}}',
    );
    expect(f.notes, isEmpty);
    final t = f.theme!;
    expect(t.name, 'Night');
    expect(t.dark.base, const Color(0xFF101010));
    expect(t.dark.accent, const Color(0x80FF0000));
    expect(t.dark.raised, builtInTheme('nord')!.dark.raised);
    expect(tokenColors(t.light), tokenColors(builtInTheme('nord')!.light));
    // Nushi's, when it names none.
    final plain = readThemeFile('P.json', '{"light": {"text": "#000000"}}');
    expect(plain.theme!.dark.raised, Tokens.dark.raised);
  });

  test('what a file has wrong is a note each, the rest still applies', () {
    final f = readThemeFile(
      'Odd.json',
      jsonEncode({
        'name': 7,
        'from': 'monokai',
        'colour': 'blue',
        'dark': {
          'basee': '#101010',
          'text': 'red',
          'raised': '#12345',
          'link': 12,
          'selected': '#202020',
        },
        'light': [1, 2],
      }),
    );
    expect(f.theme!.name, 'Odd');
    expect(f.theme!.dark.selected, const Color(0xFF202020));
    expect(f.theme!.dark.text, Tokens.dark.text);
    expect(f.notes, [
      '"name" isn’t text: the file’s name is used.',
      startsWith('"from" names no built-in theme (nushi, vivid'),
      '"colour" means nothing here: ignored.',
      '"dark.basee" is no token: ignored.',
      '"dark.text" isn’t #RRGGBB or #AARRGGBB: ignored.',
      '"dark.raised" isn’t #RRGGBB or #AARRGGBB: ignored.',
      '"dark.link" isn’t #RRGGBB or #AARRGGBB: ignored.',
      '"light" isn’t an object: ignored.',
    ]);
  });

  test('a file’s words show without control or bidi characters', () {
    final f = readThemeFile(
      'Odd.json',
      jsonEncode({
        'name': 'Mid\u202Enight\u0007',
        'dark': {'ba\u202Ese': '#101010'},
      }),
    );
    expect(f.theme!.name, 'Midnight');
    expect(f.notes, ['"dark.base" is no token: ignored.']);
  });

  test('a file that is no JSON object, or too large, has no theme', () {
    for (final (text, note) in [
      ('{"dark": {', startsWith('Isn’t JSON')),
      ('[1, 2]', 'Isn’t a JSON object.'),
      ('"text"', 'Isn’t a JSON object.'),
      (' ' * (themeFileLimit + 1), 'Over 64 KB: not read.'),
    ]) {
      final f = readThemeFile('Bad.json', text);
      expect(f.theme, isNull);
      expect(f.notes, [note]);
    }
  });

  test('a custom theme under AA gets warnings naming the pair, worst '
      'first', () {
    final t = withColors(Tokens.dark, {
      'textMuted': const Color(0xFF55585E),
      'avatars.blue': const Color(0xFF2B2D30),
    });
    final w = contrastWarnings(t);
    expect(w.first, startsWith('avatars.blue on raised: 1.00:1, under 3:1'));
    expect(w, contains(startsWith('textMuted on base: ')));
    expect(w.where((l) => l.startsWith('textMuted')), isNotEmpty);
  });

  test('a color as a file writes it', () {
    expect(hexColor(const Color(0xFF00AB12)), '#00AB12');
    expect(hexColor(const Color(0x1200AB12)), '#1200AB12');
  });
}

Map<String, String> _hex(Tokens t) => {
  for (final MapEntry(:key, :value) in tokenColors(t).entries)
    key: hexColor(value),
};
