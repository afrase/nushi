import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_sets.dart';

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

/// How far a surface must stand off the one under it: Nushi's own light
/// card on its window, the quietest step of the approved look, is 1.9.
const _surfaceFloor = 1.8;
const _borderFloor = 8.0;

void main() {
  for (final (name, t) in everySet) {
    Color on(Color tint, Color surface) => Color.alphaBlend(tint, surface);

    // What a row can be (as in chat_colors_test), and the tints text sits
    // on in the transcript and the cards.
    final rows = {
      'raised': t.raised,
      'hovered': on(t.hover, t.raised),
      'selected': t.selected,
      'accentSoft': t.accentSoft,
      'base': t.base,
      'hovered on base': on(t.hover, t.base),
    };
    // The sidebar's rows, on the window itself (ADR 0111): their text, and
    // their marks (a state's dot, a chat's color). A state's word there is
    // a pill on its own soft fill.
    final sidebar = {
      'window': t.window,
      'hovered on window': on(t.hover, t.window),
    };
    final tints = {
      'subagentTint': t.subagentTint,
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
              ...sidebar,
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
          // A finding's file and line, and the card's mark, on its card.
          'findingsAccent on raised': (t.findingsAccent, t.raised),
          'onAccent on accent': (t.onAccent, t.accent),
          'onAccent on accentPressed': (t.onAccent, t.accentPressed),
          // The transcript's fills (ADR 0111): code's surface under a tool
          // call's output, an open file's row and its counts; a pill
          // button on a card; a subagent's row while its pane is open.
          for (final MapEntry(key: ink, value: c) in {
            ...inks,
            'done': t.done,
            'crashed': t.crashed,
          }.entries)
            '$ink on codeBlock': (c, t.codeBlock),
          // A quote's soft fill, wherever quoted text sits.
          for (final MapEntry(key: fill, value: f) in {
            'base': t.base,
            'raised': t.raised,
            'codeBlock': t.codeBlock,
          }.entries)
            'muted on a quote on $fill': (t.textMuted, on(t.quote, f)),
          'userBandMuted on a quote in the bubble': (
            t.userBandMuted,
            on(t.quote, t.userBand),
          ),
          'text on lifted': (t.text, t.lifted),
          'secondary on lifted': (t.textSecondary, t.lifted),
          'text on lifted, hovered': (t.text, on(t.hover, t.lifted)),
          // A button is the lifted fill everywhere (ADR 0111): its key
          // hint, and a destructive one's red (under the pointer it is on
          // crashedSoft, above).
          'muted on lifted': (t.textMuted, t.lifted),
          'crashed on lifted': (t.crashed, t.lifted),
          // A review comment's state chip, and a pull request's tiles'.
          'running on accentSoft': (t.running, t.accentSoft),
          'subagentAccent on accentSoft': (t.subagentAccent, t.accentSoft),
          'subagentAccent on crashedSoft': (t.subagentAccent, t.crashedSoft),
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
            for (final MapEntry(key: row, value: f) in {
              ...rows,
              ...sidebar,
            }.entries)
              '$ink on $row': (c, f),
          'needs on its halo': (t.needs, t.needsSoft),
          // A tool call's icon on its row, a card, hovered too, and on an
          // open file's row in a run.
          'toolAccent on raised': (t.toolAccent, t.raised),
          'toolAccent on raised, hovered': (
            t.toolAccent,
            on(t.hover, t.raised),
          ),
          'toolAccent on codeBlock': (t.toolAccent, t.codeBlock),
        },
        3,
        _contrast,
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
