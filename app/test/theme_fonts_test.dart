// The theme's fonts (ADR 0114): a picked family is what UI text and code
// are set in, the bundled one after it, so a font that's gone or lacks a
// glyph still draws; unpicked, the theme is as it always was.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  const t = Tokens.dark;
  const picked = NushiTheme(t, uiPicked: 'Avenir Next', codePicked: 'Menlo');

  test('unpicked, text is set in the bundled fonts with no fallback', () {
    const theme = NushiTheme(t);
    expect(theme.ui(t.text).fontFamily, 'IBM Plex Sans');
    expect(theme.ui(t.text).fontFamilyFallback, isNull);
    expect(theme.code(t.text).fontFamily, 'JetBrains Mono');
    expect(theme.code(t.text).fontFamilyFallback, isNull);
    final material = theme.toThemeData().textTheme;
    expect(material.bodyMedium!.fontFamily, 'IBM Plex Sans');
    expect(material.bodyMedium!.fontFamilyFallback, isNull);
    final diff = diffTheme(t);
    expect(diff.fontFamily, 'JetBrains Mono');
    expect(diff.fontFamilyFallback, ['Menlo', 'monospace']);
  });

  test('a picked family is first, the bundled one after it', () {
    final ui = picked.ui(t.text, size: 12, weight: FontWeight.w600);
    expect(ui.fontFamily, 'Avenir Next');
    expect(ui.fontFamilyFallback, ['IBM Plex Sans']);
    expect(ui.fontSize, 12);
    expect(ui.fontWeight, FontWeight.w600);
    final code = picked.code(t.text);
    expect(code.fontFamily, 'Menlo');
    expect(code.fontFamilyFallback, ['JetBrains Mono']);
    // Ligatures stay off, whatever the font.
    expect(code.fontFeatures, const [
      FontFeature.disable('liga'),
      FontFeature.disable('calt'),
    ]);
    // What takes no style from the theme gets Material's, the same font.
    final material = picked.toThemeData();
    for (final style in [
      material.textTheme.bodyMedium!,
      material.textTheme.titleLarge!,
      material.textTheme.labelSmall!,
      material.dialogTheme.titleTextStyle!,
      material.tooltipTheme.textStyle!,
      material.inputDecorationTheme.hintStyle!,
    ]) {
      expect(style.fontFamily, 'Avenir Next');
      expect(style.fontFamilyFallback, ['IBM Plex Sans']);
    }
    final diff = diffTheme(t, family: picked.codePicked);
    expect(diff.fontFamily, 'Menlo');
    expect(diff.fontFamilyFallback, ['JetBrains Mono', 'Menlo', 'monospace']);
  });

  test('one font picked leaves the other bundled', () {
    const theme = NushiTheme(t, codePicked: 'Menlo');
    expect(theme.ui(t.text).fontFamily, 'IBM Plex Sans');
    expect(theme.ui(t.text).fontFamilyFallback, isNull);
    expect(theme.code(t.text).fontFamily, 'Menlo');
  });

  test('a widget’s own fallback goes after the bundled font, not in its '
      'place', () {
    expect(
      picked.ui(t.text).thenFonts(const ['Apple Color Emoji']),
      isA<TextStyle>().having((s) => s.fontFamilyFallback, 'fallback', [
        'IBM Plex Sans',
        'Apple Color Emoji',
      ]),
    );
    expect(
      const NushiTheme(t)
          .ui(t.text)
          .thenFonts(const ['Apple Color Emoji'])
          .fontFamilyFallback,
      ['Apple Color Emoji'],
    );
  });

  test('themes are equal by their fonts too, and other tokens keep them', () {
    expect(picked, isNot(const NushiTheme(t)));
    expect(
      picked,
      const NushiTheme(t, uiPicked: 'Avenir Next', codePicked: 'Menlo'),
    );
    expect(
      picked.hashCode,
      const NushiTheme(
        t,
        uiPicked: 'Avenir Next',
        codePicked: 'Menlo',
      ).hashCode,
    );
    expect(picked, isNot(const NushiTheme(t, uiPicked: 'Avenir Next')));
    expect(picked.toThemeData(), picked.toThemeData());
    final light = picked.withTokens(Tokens.light, dark: Tokens.dark);
    expect(light.t, same(Tokens.light));
    expect(light.dark, same(Tokens.dark));
    expect(light.uiPicked, 'Avenir Next');
    expect(light.codePicked, 'Menlo');
    expect(picked.copyWith(t: Tokens.light).codePicked, 'Menlo');
  });

  test('a Material theme is made once per theme and fonts', () {
    final nord = builtInTheme('nord')!;
    final plain = NushiTheme.forTheme(nord, Brightness.dark);
    final menlo = NushiTheme.forTheme(nord, Brightness.dark, code: 'Menlo');
    expect(menlo, isNot(plain));
    expect(
      NushiTheme.forTheme(nord, Brightness.dark, code: 'Menlo'),
      same(menlo),
    );
    expect(NushiTheme.forTheme(nord, Brightness.dark), same(plain));
    expect(menlo.extension<NushiTheme>()!.codePicked, 'Menlo');
    expect(menlo.extension<NushiTheme>()!.uiPicked, isNull);
    expect(plain.extension<NushiTheme>()!.codePicked, isNull);
  });
}
