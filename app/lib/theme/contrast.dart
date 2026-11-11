import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme_file.dart';
import 'package:nushi/theme/tokens.dart';

/// The WCAG contrast of [a] and [b].
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// The pairs of [t] that read under what the built-in themes are held to
/// (`tokens_test`, `chat_colors_test`, `code_ink_test`): text AA (4.5:1)
/// on every fill it sits on, a mark 3:1. Each a line naming the pair, for
/// a custom theme's warning in Settings; the worst first.
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
    ('toolAccent', t.toolAccent, 'codeBlock', t.codeBlock, 3),
    for (final (ink, c) in [
      ('text', t.text),
      ('textSecondary', t.textSecondary),
      ('textMuted', t.textMuted),
      ('done', t.done),
      ('crashed', t.crashed),
    ])
      (ink, c, 'codeBlock', t.codeBlock, 4.5),
    ('textMuted', t.textMuted, 'a quote on base', on(t.quote, t.base), 4.5),
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
    ('crashed', t.crashed, 'lifted', t.lifted, 4.5),
    ('subagentAccent', t.subagentAccent, 'accentSoft', t.accentSoft, 4.5),
    ('onAccent', t.onAccent, 'accent', t.accent, 4.5),
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
  ];
  final low = [
    for (final (ink, c, fill, b, floor) in pairs)
      if (contrast(c, b) case final r when r < floor) (r, ink, fill, floor),
  ]..sort((x, y) => x.$1.compareTo(y.$1));
  return [
    for (final (r, ink, fill, floor) in low)
      '$ink on $fill: ${r.toStringAsFixed(2)}:1, under ${_floor(floor)}:1',
  ];
}

String _floor(double f) => f == 3 ? '3' : '4.5';
