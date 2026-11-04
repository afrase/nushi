// A theme built again from the same tokens equals the last one: an unequal
// one makes MaterialApp blend the two for 200 ms, rebuilding the whole
// transcript on each frame (a sidebar toggle did, from e0bad690 on).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';

void main() {
  final file = readThemeFile(
    'Mine.json',
    writeThemeFile(builtInThemes[1], 'Mine'),
  ).theme!;

  test('Material themes made twice from one theme are equal', () {
    for (final c in [...builtInThemes, file]) {
      for (final b in Brightness.values) {
        expect(
          NushiTheme.forTheme(c, b),
          NushiTheme.forTheme(c, b),
          reason: '${c.name} $b',
        );
        expect(
          NushiTheme(c.of(b), dark: c.dark).toThemeData(),
          NushiTheme(c.of(b), dark: c.dark).toThemeData(),
          reason: '${c.name} $b',
        );
      }
    }
  });

  test('a theme file read again, or another theme, is a new theme', () {
    final again = readThemeFile(
      'Mine.json',
      writeThemeFile(builtInThemes[1], 'Mine'),
    ).theme!;
    expect(
      NushiTheme.forTheme(again, Brightness.dark),
      isNot(NushiTheme.forTheme(file, Brightness.dark)),
    );
    expect(
      NushiTheme.forTheme(builtInThemes[2], Brightness.dark),
      isNot(NushiTheme.forTheme(builtInThemes[1], Brightness.dark)),
    );
    expect(
      const NushiTheme(Tokens.dark),
      isNot(const NushiTheme(Tokens.dark, dark: Tokens.light)),
    );
  });
}
