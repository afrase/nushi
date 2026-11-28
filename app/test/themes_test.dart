// Themes (ADR 0086): the built-ins, a theme file's format, and the
// warning a custom theme under AA gets.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';
import 'package:nushi/theme/tokyo_night.dart';

import 'theme_sets.dart';

void main() {
  test('the built-ins: Nushi first and the default, ids apart, each set '
      'whole and of its brightness', () {
    expect(builtInThemes.first, same(nushiTheme));
    expect(nushiTheme.dark, same(Tokens.dark));
    expect(nushiTheme.light, same(Tokens.light));
    expect(
      [for (final c in builtInThemes) c.id],
      ['nushi', 'vivid', 'solarized', 'nord', 'catppuccin', 'tokyo-night'],
    );
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
    expect(names.length, 116);
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

  test('a file from before the surfaces told things apart: the names it '
      'still holds are passed over, with no note', () {
    final f = readThemeFile(
      'Old.json',
      jsonEncode({
        'name': 'Old',
        'dark': {
          for (final n in retiredTokens) n: '#112233',
          'base': '#101010',
          'nonsense': '#101010',
        },
      }),
    );
    expect(f.notes, ['"dark.nonsense" is no token: ignored.']);
    expect(f.theme!.dark.base, const Color(0xFF101010));
    expect(
      tokenColors(f.theme!.dark).keys.toSet().intersection(retiredTokens),
      isEmpty,
    );
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
    // An id with a hyphen names its built-in as any other.
    final tokyo = readThemeFile('T.json', '{"from": "tokyo-night"}');
    expect(tokyo.notes, isEmpty);
    expect(
      tokenColors(tokyo.theme!.dark),
      tokenColors(builtInTheme('tokyo-night')!.dark),
    );
    // Nushi's, when it names none.
    final plain = readThemeFile('P.json', '{"light": {"text": "#000000"}}');
    expect(plain.theme!.dark.raised, Tokens.dark.raised);
  });

  test('a surface a file doesn’t name follows the one it does (ADR 0111)', () {
    // A file from before the window, the raised bits and the hairline were
    // tokens names every color it knew: they come from its own palette,
    // not from the built-in it starts from.
    final nordDark = builtInTheme('nord')!.dark;
    final old = {...tokenColors(nordDark)}
      ..removeWhere(
        (k, _) =>
            const {'window', 'lifted', 'segment', 'line', 'quote'}.contains(k),
      );
    final f = readThemeFile(
      'Old.json',
      jsonEncode({
        'dark': {for (final e in old.entries) e.key: hexColor(e.value)},
        'light': {'base': '#FFF8E7', 'window': '#E9DFC8'},
      }),
    );
    expect(f.notes, isEmpty);
    final dark = f.theme!.dark;
    expect(dark.base, nordDark.base);
    expect(dark.window, isNot(Tokens.dark.window));
    expect(
      dark.window.computeLuminance(),
      lessThan(dark.base.computeLuminance()),
    );
    expect(
      dark.lifted.computeLuminance(),
      greaterThan(dark.raised.computeLuminance()),
    );
    expect(dark.line.a, closeTo(0.07, 0.005));
    expect(dark.quote, nordDark.text.withValues(alpha: 0.07));
    expect(
      (dark.line.r, dark.line.g, dark.line.b),
      (nordDark.text.r, nordDark.text.g, nordDark.text.b),
    );
    // One it names is kept, and what it leaves alone is the built-in's.
    final light = f.theme!.light;
    expect(light.window, const Color(0xFFE9DFC8));
    expect(light.segment, const Color(0xFFFFF8E7));
    expect(light.lifted, Tokens.light.lifted);
    expect(light.line, Tokens.light.line);
    final plain = readThemeFile('P.json', '{"dark": {"accent": "#5E81AC"}}');
    expect(plain.theme!.dark.window, Tokens.dark.window);
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
      'avatars.blue': Tokens.dark.raised,
    });
    final w = contrastWarnings(t);
    expect(w.first, startsWith('avatars.blue on raised: 1.00:1, under 3:1'));
    expect(w, contains(startsWith('textMuted on base: ')));
    expect(w.where((l) => l.startsWith('textMuted')), isNotEmpty);
  });

  test("a custom theme whose terminal search hits can't be told apart is "
      'warned, naming the keys to move apart', () {
    // A made-up dark set: its body text and needsSoft too near each other
    // for both of the hits' fills to read and stand apart.
    final t = withColors(Tokens.dark, {
      'text': const Color(0xFFD9DDD3),
      'needsSoft': const Color(0xFF736D4D),
    });
    expect(t.terminal.foreground, isNull);
    final w = contrastWarnings(t);
    expect(
      w,
      contains(
        allOf(
          startsWith('accent against needsSoft in terminal search: '),
          endsWith(', under 2:1'),
        ),
      ),
    );
    expect(w.where((l) => l.contains('terminal search')), hasLength(1));
    // Each line the search adds holds in every built-in set, as the rest.
    for (final (name, b) in everySet) {
      expect(
        contrastWarnings(b).where((l) => l.contains('terminal search')),
        isEmpty,
        reason: name,
      );
    }
  });

  test("the terminal's search hits' text under 4.5:1 on needsSoft is "
      'warned, by the key its text comes from', () {
    // A made-up dark set whose needsSoft is a light grey: even white
    // reads about 2.6:1 on it.
    final dim = withColors(Tokens.dark, {'needsSoft': const Color(0xFFA0A0A0)});
    final line = contrastWarnings(dim)
        .where((l) => l.contains('on needsSoft in terminal search'));
    expect(line, [
      allOf(
        startsWith('text on needsSoft in terminal search: '),
        endsWith(', under 4.5:1'),
      ),
    ]);
    // From a theme with the terminal's own text (Tokyo Night Day's), which
    // a file can't set: only needsSoft is named as a key. Its needsSoft a
    // grey just lighter than that blue text, which darkens toward it,
    // where even black reads 4:1.
    final own = withColors(tokyoNightLight, {
      'needsSoft': const Color(0xFF6C6C6C),
    });
    expect(own.terminal.foreground, isNotNull);
    expect(
      contrastWarnings(own)
          .where((l) => l.contains('on needsSoft in terminal search')),
      [startsWith('terminal text on needsSoft in terminal search: ')],
    );
  });

  test("the terminal's search hits' text always reads 4.5:1 on the current "
      'hit, so that pair has no warning line', () {
    // The current hit's fill is accent moved toward black or white until
    // the hits' text reads on it (`searchHitCurrent`), and either end
    // reads on that text however a theme sets it: seeded made-up themes,
    // from Tokyo Night Day too, whose terminal has its own text.
    final random = Random(117);
    Color any() => Color(0xFF000000 | random.nextInt(0x1000000));
    for (var i = 0; i < 6000; i++) {
      final from = [Tokens.dark, Tokens.light, tokyoNightLight][i % 3];
      final t = withColors(from, {
        'text': any(),
        'needsSoft': any(),
        'accent': any(),
      });
      expect(
        contrast(t.searchHitInk, t.searchHitCurrent),
        greaterThanOrEqualTo(Tokens.searchHitContrast),
        reason:
            '${hexColor(t.text)} ${hexColor(t.needsSoft)} '
            '${hexColor(t.accent)}',
      );
    }
  });

  test("the lowest ratio comes first, so the card's one line can be the "
      "terminal's search", () {
    // The made-up dark set above: its search's fills too near, its muted
    // text a little under AA on needsSoft.
    final w = contrastWarnings(
      withColors(Tokens.dark, {
        'text': const Color(0xFFD9DDD3),
        'needsSoft': const Color(0xFF736D4D),
      }),
    );
    double ratio(String line) =>
        double.parse(RegExp(r': ([\d.]+):1, under ').firstMatch(line)![1]!);
    final ratios = w.map(ratio).toList();
    expect(ratios, [...ratios]..sort());
    expect(w.length, greaterThan(1));
    expect(w.first, startsWith('accent against needsSoft in terminal'));
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
