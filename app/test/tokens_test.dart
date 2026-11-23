import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/contrast.dart';

import 'theme_sets.dart';

/// [c]'s CIE lightness, L*, from 0 (black) to 100 (white): how light it
/// looks, in even steps.
double _lightness(Color c) {
  final y = c.computeLuminance();
  return y > 216 / 24389 ? 116 * pow(y, 1 / 3) - 16 : y * 24389 / 27;
}

/// How far apart, in L*, text, textSecondary and textMuted must be, each
/// from the next, to read as three greys.
const _greyStep = 6.0;

/// The sets whose greys can't be three steps, each with why: a named
/// theme keeps its published colors (ADR 0086), and its AA floor can sit
/// right under its text.
const _greysTogether = {
  // fg_dark and #9AA5CE, both Tokyo Night's own.
  'Tokyo Night, dark',
  // Day's text is its fg, and AA on its fills sits just under it.
  'Tokyo Night, light',
  // Latte's text is its own; Subtext1 and Subtext0, taken darker to AA,
  // land on it.
  'Catppuccin, light',
  // Solarized's greys are under AA on its fills: taken to AA, its text,
  // base0 and base01 land within 7 of each other.
  'Solarized, dark',
};

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

/// How far a surface must stand off the one under it: Nushi's own light
/// card on its window, the quietest step of the approved look, is 1.9.
const _surfaceFloor = 1.8;
const _borderFloor = 8.0;

void main() {
  test('the sets whose greys are let off are sets', () {
    expect([
      for (final (name, _) in everySet) name,
    ], containsAll(_greysTogether));
  });

  for (final (name, t) in everySet) {
    Color on(Color tint, Color surface) => Color.alphaBlend(tint, surface);

    // The tints text sits on in the transcript and the cards. Which inks
    // read on which fills is contrastWarnings' (themes_test checks every
    // set has none); this file holds what isn't a pair's floor.
    final tints = {
      'subagentTint': t.subagentTint,
      'needsSoft': t.needsSoft,
      'doneSoft': t.doneSoft,
      'crashedSoft': t.crashedSoft,
    };

    test('text, textSecondary and textMuted are three steps ($name)', () {
      final (text, secondary, muted) = (
        _lightness(t.text),
        _lightness(t.textSecondary),
        _lightness(t.textMuted),
      );
      final steps = [(text - secondary).abs(), (secondary - muted).abs()];
      // A set let off still needs it: once its greys are three steps, it
      // comes off the list.
      expect(
        steps,
        _greysTogether.contains(name)
            ? anyElement(lessThan(_greyStep))
            : everyElement(greaterThanOrEqualTo(_greyStep)),
      );
    });

    test('a field’s hint stands clearly under a typed value and muted '
        'text, and still reads ($name)', () {
      final hint = contrast(t.hint, t.fieldFill);
      expect(hint, greaterThanOrEqualTo(3), reason: 'hint on fieldFill');
      expect(
        contrast(t.text, t.fieldFill) / hint,
        greaterThanOrEqualTo(1.5),
        reason: 'text over hint',
      );
      expect(
        hint,
        lessThanOrEqualTo(contrast(t.textMuted, t.fieldFill)),
        reason: 'hint under muted',
      );
    });

    test('each surface is a step off the one it sits on ($name)', () {
      // Fill, not outline (ADR 0111): a pane on the window, a card on a
      // pane or on the window (the sidebar's), a raised bit on a card, the
      // picked segment on its track.
      _atLeast(
        {
          'base on window': (t.base, t.window),
          'raised on base': (t.raised, t.base),
          'raised on window': (t.raised, t.window),
          'lifted on raised': (t.lifted, t.raised),
          // A button on a pane, and under the pointer on a card.
          'lifted on base': (t.lifted, t.base),
          'lifted, hovered': (on(t.hover, t.lifted), t.lifted),
          'segment on raised': (t.segment, t.raised),
          // Code is sunk, on a pane and on a card alike.
          'codeBlock on base': (t.codeBlock, t.base),
          'codeBlock on raised': (t.codeBlock, t.raised),
        },
        _surfaceFloor,
        _apart,
      );
      // A hairline shows on a pane, and stays one.
      final line = _apart(on(t.line, t.base), t.base);
      expect(line, greaterThanOrEqualTo(_surfaceFloor), reason: 'line on base');
      expect(
        line,
        lessThan(_apart(t.fieldBorder, t.base)),
        reason: 'line under a field’s edge',
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
          'the open chat on window': (t.accentSoft, t.window),
          'hover on window': (on(t.hover, t.window), t.window),
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
          'fieldBorder on fieldFill': (t.fieldBorder, t.fieldFill),
          // A grey mark (a rail's dash, the empty window's logo) on a pane
          // and on the window, and an empty checkbox's edge on a card.
          'faint on base': (t.faint, t.base),
          'faint on window': (t.faint, t.window),
          'fieldBorderHover on raised': (t.fieldBorderHover, t.raised),
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
