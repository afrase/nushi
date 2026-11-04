import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/tokens.dart';

/// The WCAG contrast of [a] and [b].
double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// How far apart [a] and [b] look: their OKLab distance, times 100. A
/// wash's contrast says little on the dark theme, where a fill reads by
/// its hue more than its lightness.
double _apart(Color a, Color b) {
  List<double> lab(Color c) {
    double lin(double v) =>
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    final (r, g, b) = (lin(c.r), lin(c.g), lin(c.b));
    final l = pow(
      0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
      1 / 3,
    );
    final m = pow(
      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
      1 / 3,
    );
    final s = pow(
      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
      1 / 3,
    );
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  final (p, q) = (lab(a), lab(b));
  return 100 *
      sqrt(
        [for (var i = 0; i < 3; i++) pow(p[i] - q[i], 2)]
            .reduce((x, y) => x + y),
      );
}

void _atLeast(
  Map<String, (Color, Color)> pairs,
  double floor,
  double Function(Color, Color) measure,
) {
  for (final MapEntry(key: what, value: (a, b)) in pairs.entries) {
    expect(measure(a, b), greaterThanOrEqualTo(floor), reason: what);
  }
}

/// How far a wash or a border must stand off what it's drawn on.
const _washFloor = 4.5;
const _borderFloor = 8.0;

void main() {
  for (final t in [Tokens.light, Tokens.dark]) {
    final name = t.brightness.name;
    Color on(Color tint, Color surface) => Color.alphaBlend(tint, surface);

    // What a row can be (as in chat_colors_test), and the tints text sits
    // on in the transcript and the cards.
    final rows = {
      'raised': t.raised,
      'hovered': on(t.hover, t.raised),
      'selected': t.selected,
      'accentSoft': t.accentSoft,
      'base': t.base,
    };
    final tints = {
      'toolTint': t.toolTint,
      'subagentTint': t.subagentTint,
      'findingsTint': t.findingsTint,
      'needsSoft': t.needsSoft,
      'doneSoft': t.doneSoft,
      'crashedSoft': t.crashedSoft,
    };

    test('text is AA on every fill it sits on ($name)', () {
      final inks = {
        'text': t.text,
        'secondary': t.textSecondary,
        'muted': t.textMuted,
      };
      _atLeast(
        {
          for (final MapEntry(key: ink, value: c) in inks.entries)
            for (final MapEntry(key: fill, value: f) in {
              ...rows,
              ...tints,
            }.entries)
              '$ink on $fill': (c, f),
          // A status word, a link or the accent's text in a row, hovered too
          // (a menu's Delete…).
          for (final MapEntry(key: ink, value: c) in {
            'needs': t.needs,
            'done': t.done,
            'running': t.running,
            'crashed': t.crashed,
            'link': t.link,
            'accentInk': t.accentInk,
          }.entries)
            for (final MapEntry(key: row, value: f) in rows.entries)
              '$ink on $row': (c, f),
          'needs on needsSoft': (t.needs, t.needsSoft),
          'done on doneSoft': (t.done, t.doneSoft),
          'crashed on crashedSoft': (t.crashed, t.crashedSoft),
          'userBandText on userBand': (t.userBandText, t.userBand),
          'userBandMuted on userBand': (t.userBandMuted, t.userBand),
          'subagentAccent on subagentTint': (t.subagentAccent, t.subagentTint),
          'findingsAccent on findingsTint': (t.findingsAccent, t.findingsTint),
          'onAccent on accent': (t.onAccent, t.accent),
          'onAccent on accentPressed': (t.onAccent, t.accentPressed),
        },
        4.5,
        _contrast,
      );
    });

    test('a status mark reads 3:1 on every row, a tint’s mark on it '
        '($name)', () {
      _atLeast(
        {
          for (final MapEntry(key: ink, value: c) in {
            'running': t.running,
            'needs': t.needs,
            'done': t.done,
            'crashed': t.crashed,
            'idle': t.idle,
          }.entries)
            for (final MapEntry(key: row, value: f) in rows.entries)
              '$ink on $row': (c, f),
          'needs on its halo': (t.needs, t.needsSoft),
          'toolAccent on toolTint': (t.toolAccent, t.toolTint),
        },
        3,
        _contrast,
      );
    });

    test('a wash stands off what it’s drawn on ($name)', () {
      _atLeast(
        {
          'hover on raised': (on(t.hover, t.raised), t.raised),
          'hover on base': (on(t.hover, t.base), t.base),
          'selected on raised': (t.selected, t.raised),
          'selected on base': (t.selected, t.base),
          'the open chat on raised': (t.accentSoft, t.raised),
          'accentSoft on base': (t.accentSoft, t.base),
          'userBand on base': (t.userBand, t.base),
          for (final MapEntry(key: k, value: c) in tints.entries)
            '$k on base': (c, t.base),
        },
        _washFloor,
        _apart,
      );
      _atLeast(
        {
          'borderSubtle on base': (t.borderSubtle, t.base),
          'borderStrong on raised': (t.borderStrong, t.raised),
          'fieldBorder on fieldFill': (t.fieldBorder, t.fieldFill),
          'userBandBorder on base': (t.userBandBorder, t.base),
          'toolBorder on base': (t.toolBorder, t.base),
          'subagentBorder on base': (t.subagentBorder, t.base),
          'findingsBorder on base': (t.findingsBorder, t.base),
        },
        _borderFloor,
        _apart,
      );
      // Under the pointer a row darkens further.
      expect(
        _apart(on(t.pressed, t.raised), t.raised),
        greaterThan(_apart(on(t.hover, t.raised), t.raised)),
      );
    });
  }
}
