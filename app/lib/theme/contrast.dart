import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme_file.dart';
import 'package:nushi/theme/tokens.dart';

/// The WCAG contrast of [a] and [b].
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// [color] as code drawn on the opaque [fill] Nushi paints under it (a
/// find's hit, its current match, the selection), where the code's colours
/// were published for [background]: ADR 0086's amendment, the same rule a
/// diff's changed line and word have. The target is the lesser of [floor]
/// (`codeOnTintContrast`) and [color]'s own contrast on [background];
/// [color] itself when it reads that on [fill]. Otherwise [color] with its
/// HSL lightness moved, hue and saturation kept, by the least step (1/255)
/// that reaches the target: first away from [fill] on [color]'s own side
/// (lighter when it is lighter than [fill]), then toward the other end.
/// Where no step reaches it, the best of [color], white and black on
/// [fill], so it never reads worse than [color] did. A translucent [color]
/// is judged as it shows on [fill] and on [background] (its alpha kept); a
/// translucent [background] is taken as opaque.
///
/// `diff_view` has the same rule inside it (`readableOn`, for its
/// `minTextContrast`) and doesn't export it; this is the app's copy, for
/// the fills it paints itself, step for step (`code_on_test` holds the two
/// to the same answers). Kept per colour, fill, background and floor:
/// a frame asks for the same few again and again.
Color codeOn(
  Color color,
  Color fill, {
  required Color background,
  required double floor,
}) {
  final key = (color.toARGB32(), fill.toARGB32(), background.toARGB32(), floor);
  if (_codeOn[key] case final c?) return c;
  if (_codeOn.length >= 4096) _codeOn.clear();
  return _codeOn[key] = _codeOn1(color, fill, background, floor);
}

final _codeOn = <(int, int, int, double), Color>{};

Color _codeOn1(Color color, Color fill, Color background, double floor) {
  if (floor <= 0) return color;
  final own = _shownContrast(color, _opaque(background));
  final target = min(own, floor);
  final start = _shownContrast(color, fill);
  if (start >= target) return color;
  final hsl = HSLColor.fromColor(color);
  final lum = _shown(color, fill).computeLuminance();
  final fillLum = fill.computeLuminance();
  final up = lum == fillLum
      ? contrast(const Color(0xFFFFFFFF), fill) >=
            contrast(const Color(0xFF000000), fill)
      : lum > fillLum;
  Color at(double l) =>
      Color(hsl.withLightness(l).toColor().toARGB32())
          .withValues(alpha: color.a);
  for (final lighter in [up, !up]) {
    for (var k = 1; ; k++) {
      final l = (hsl.lightness + (lighter ? k : -k) / 255).clamp(0.0, 1.0);
      final c = at(l);
      if (_shownContrast(c, fill) >= target) return c;
      if (l == 0 || l == 1) break;
    }
  }
  // Nothing reaches it: along each side contrast is best at its end.
  var (best, bestContrast) = (color, start);
  for (final c in [at(up ? 1 : 0), at(up ? 0 : 1)]) {
    final r = _shownContrast(c, fill);
    if (r > bestContrast) (best, bestContrast) = (c, r);
  }
  return best;
}

Color _opaque(Color c) => c.a == 1 ? c : c.withValues(alpha: 1);

/// [c] as it shows on the opaque [fill]: a translucent colour is judged
/// blended, as `diff_view` judges it.
Color _shown(Color c, Color fill) => c.a == 1 ? c : Color.alphaBlend(c, fill);

double _shownContrast(Color c, Color fill) => contrast(_shown(c, fill), fill);

/// The pairs of [t] that read under what the built-in themes are held to
/// (`themes_test` checks none of theirs is here): text AA (4.5:1) on every
/// fill it sits on, a mark 3:1, the terminal's current search hit 2:1 off
/// the rest. The one list of those floors: each a line naming the pair by
/// the keys a theme file sets, for a custom theme's warning in Settings;
/// the lowest ratio first, whatever its floor. Settings' card shows that
/// one line and how many more, so the terminal's two fills too near each
/// other (always under 2:1) come first more often than not; its text on
/// needsSoft comes after `text on needsSoft`, which is as low or lower
/// and asks for the same move, unless the terminal has its own text.
///
/// Not among them (ADR 0086): code's colors (`syntax.*`), the terminal's
/// sixteen and its text (`terminal.*`), a diff's (`diff.*`) and the
/// transcript's body text (`agentText`). A published theme's are its
/// authors' and are what it's known by, so a built-in keeps them as
/// published (`published_colors_test`) though some read under AA
/// (Tokyo Night's comments, 2.8:1), and a user's are theirs.
List<String> contrastWarnings(Tokens t) {
  Color on(Color tint, Color surface) => Color.alphaBlend(tint, surface);
  final rows = {
    'raised': t.raised,
    'a hovered row': on(t.hover, t.raised),
    'selected': t.selected,
    'accentSoft': t.accentSoft,
    'base': t.base,
    'a hovered row on base': on(t.hover, t.base),
  };
  // The sidebar's rows, on the window itself (ADR 0111): their text and
  // their marks.
  final sidebar = {
    'window': t.window,
    'a hovered row on window': on(t.hover, t.window),
  };
  final tints = {
    'subagentTint': t.subagentTint,
    'needsSoft': t.needsSoft,
    'doneSoft': t.doneSoft,
    'crashedSoft': t.crashedSoft,
  };
  final pairs = <(String, Color, String, Color, double)>[
    for (final (ink, c) in [
      ('text', t.text),
      ('textSecondary', t.textSecondary),
      ('textMuted', t.textMuted),
    ])
      for (final MapEntry(key: f, value: b) in {
        ...rows,
        ...sidebar,
        ...tints,
      }.entries)
        (ink, c, f, b, 4.5),
    for (final (ink, c) in [
      ('needs', t.needs),
      ('done', t.done),
      ('running', t.running),
      ('crashed', t.crashed),
      ('link', t.link),
      ('accentInk', t.accentInk),
    ])
      for (final MapEntry(key: f, value: b) in rows.entries)
        (ink, c, f, b, 4.5),
    for (final (ink, c) in [
      ('idle', t.idle),
      ('needs', t.needs),
      ('done', t.done),
      ('running', t.running),
      ('crashed', t.crashed),
    ])
      for (final MapEntry(key: f, value: b) in {...rows, ...sidebar}.entries)
        (ink, c, f, b, 3),
    ('needs', t.needs, 'needsSoft', t.needsSoft, 4.5),
    ('done', t.done, 'doneSoft', t.doneSoft, 4.5),
    ('crashed', t.crashed, 'crashedSoft', t.crashedSoft, 4.5),
    ('userBandText', t.userBandText, 'userBand', t.userBand, 4.5),
    ('userBandMuted', t.userBandMuted, 'userBand', t.userBand, 4.5),
    ('subagentAccent', t.subagentAccent, 'subagentTint', t.subagentTint, 4.5),
    ('findingsAccent', t.findingsAccent, 'raised', t.raised, 4.5),
    ('toolAccent', t.toolAccent, 'raised', t.raised, 3),
    ('toolAccent', t.toolAccent, 'a hovered row', on(t.hover, t.raised), 3),
    ('toolAccent', t.toolAccent, 'codeBlock', t.codeBlock, 3),
    for (final (ink, c) in [
      ('text', t.text),
      ('textSecondary', t.textSecondary),
      ('textMuted', t.textMuted),
      ('done', t.done),
      ('crashed', t.crashed),
    ])
      (ink, c, 'codeBlock', t.codeBlock, 4.5),
    for (final (f, b) in [
      ('base', t.base),
      ('raised', t.raised),
      ('codeBlock', t.codeBlock),
    ])
      ('textMuted', t.textMuted, 'a quote on $f', on(t.quote, b), 4.5),
    (
      'userBandMuted',
      t.userBandMuted,
      'a quote in userBand',
      on(t.quote, t.userBand),
      4.5,
    ),
    ('text', t.text, 'lifted', t.lifted, 4.5),
    ('textSecondary', t.textSecondary, 'lifted', t.lifted, 4.5),
    ('textMuted', t.textMuted, 'lifted', t.lifted, 4.5),
    ('text', t.text, 'lifted, hovered', on(t.hover, t.lifted), 4.5),
    ('crashed', t.crashed, 'lifted', t.lifted, 4.5),
    ('subagentAccent', t.subagentAccent, 'accentSoft', t.accentSoft, 4.5),
    ('subagentAccent', t.subagentAccent, 'crashedSoft', t.crashedSoft, 4.5),
    ('onAccent', t.onAccent, 'accent', t.accent, 4.5),
    ('onAccent', t.onAccent, 'accentPressed', t.accentPressed, 4.5),
    for (final (i, c) in t.avatars.indexed)
      for (final MapEntry(key: f, value: b) in {...rows, ...sidebar}.entries)
        ('avatars.${avatarNames[i]}', c, f, b, 3),
    for (final (f, b) in [
      ('base', t.base),
      ('raised', t.raised),
      ('codeBlock', t.codeBlock),
      ('a hovered row', on(t.hover, t.raised)),
      ('selected', t.selected),
    ])
      (
        'inlineCodeText',
        t.inlineCodeText,
        '$f under inlineCode',
        on(t.inlineCode, b),
        4.5,
      ),
    (
      'inlineCodeText',
      t.inlineCodeText,
      'userBand under userBandCode',
      on(t.userBandCode, t.userBand),
      4.5,
    ),
    // The terminal's search (`searchHitInk`, `searchHitCurrent`): derived
    // from the terminal's text, needsSoft and the accent, so a theme can
    // leave them no room. Each line names the keys a theme file sets, the
    // colours to move apart, though what it measures is the derived one:
    // the terminal's text is `text` unless the `from` theme gives its own
    // (Tokyo Night Day's), which a file can't set, so only needsSoft is
    // named there. The hits' text on the current hit isn't here: that
    // fill is the accent moved until the text reads on it, which black or
    // white always does (themes_test checks).
    (
      t.terminal.foreground == null ? 'text' : 'terminal text',
      t.searchHitInk,
      'needsSoft in terminal search',
      t.needsSoft,
      Tokens.searchHitContrast,
    ),
  ];
  final low = [
    for (final (ink, c, fill, b, floor) in pairs)
      if (contrast(c, b) case final r when r < floor)
        (r, '$ink on $fill', floor),
    if (contrast(t.searchHitCurrent, t.needsSoft) case final r
        when r < Tokens.searchHitGap)
      (r, 'accent against needsSoft in terminal search', Tokens.searchHitGap),
  ]..sort((x, y) => x.$1.compareTo(y.$1));
  return [
    for (final (r, pair, floor) in low)
      '$pair: ${r.toStringAsFixed(2)}:1, under ${_floor(floor)}:1',
  ];
}

String _floor(double f) => switch (f) {
  2 => '2',
  3 => '3',
  _ => '4.5',
};
