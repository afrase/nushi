import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:nushi/theme/theme.dart';

/// A tab reaches the next multiple of this many columns, in the preview's
/// source and its editor alike (ADR 0096): Go's and a Makefile's indent
/// reads as gofmt's and most editors' four. One width, not a setting.
const tabSize = 4;

/// What one column of [style] advances: a character of the code font,
/// which is monospaced, as [scaler] draws it.
double columnWidth(TextStyle style, TextScaler scaler) {
  if (_measured case (final s, final k, final w)
      when s == style && k == scaler) {
    return w;
  }
  final zero = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final w = zero.width;
  zero.dispose();
  _measured = (style, scaler, w);
  return w;
}

(TextStyle, TextScaler, double)? _measured;

/// The columns the code unit [c] takes: a wide character (CJK, a full
/// width form, an emoji's surrogate pair) two, a combining mark none.
/// Near enough for tab stops: such a character drawn by a fallback font
/// may not be exactly two columns wide.
int columnsOf(int c) {
  if (c >= 0xDC00 && c <= 0xDFFF) return 0; // counted at its high half
  if (c >= 0x0300 && c <= 0x036F || c == 0x200B || c == 0x200D) return 0;
  if (c >= 0xD800 && c <= 0xDBFF ||
      c >= 0x1100 && c <= 0x115F ||
      c >= 0x2E80 && c <= 0xA4CF ||
      c >= 0xAC00 && c <= 0xD7A3 ||
      c >= 0xF900 && c <= 0xFAFF ||
      c >= 0xFE30 && c <= 0xFE4F ||
      c >= 0xFF00 && c <= 0xFF60 ||
      c >= 0xFFE0 && c <= 0xFFE6) {
    return 2;
  }
  return 1;
}

/// How many columns a tab at [column] spans: to the next stop.
int tabColumns(int column) => tabSize - column % tabSize;

/// [runs], a line's text in styled runs from its start, with each tab
/// drawn to the next stop. Flutter draws a tab as a space; the tab's run
/// takes a font size ([fontSize] the line's) at which that space spans
/// the tab's columns, [column] wide each, with [spacing] (the letter
/// spacing the runs inherit, already in [column]) after it. Not letter
/// spacing, which would be simpler: Skia's paragraph shifts a line by half
/// the letter spacing of its first glyph, a leading tab's, and puts its
/// carets out of step with it. The line's height must be held by a strut
/// (`forceStrutHeight`), as the editor's is, or the larger size would
/// raise it. The text is the same, so offsets, the caret, selection,
/// copying and saving keep the real tab.
List<TextSpan> tabStops(
  List<TextSpan> runs, {
  required double fontSize,
  required double column,
  double spacing = 0,
}) {
  if (!runs.any((r) => r.text?.contains('\t') ?? false)) return runs;
  final glyph = column - spacing; // a space's own advance
  final out = <TextSpan>[];
  var at = 0;
  for (final run in runs) {
    final text = run.text ?? '';
    if (!text.contains('\t')) {
      out.add(run);
      for (var i = 0; i < text.length; i++) {
        at += columnsOf(text.codeUnitAt(i));
      }
      continue;
    }
    var from = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c != 0x09) {
        at += columnsOf(c);
        continue;
      }
      if (i > from) {
        out.add(TextSpan(text: text.substring(from, i), style: run.style));
      }
      final n = tabColumns(at);
      out.add(
        TextSpan(
          text: '\t',
          style: (run.style ?? const TextStyle()).copyWith(
            fontSize: fontSize * (n * column - spacing) / glyph,
          ),
        ),
      );
      at += n;
      from = i + 1;
    }
    if (from < text.length) {
      out.add(TextSpan(text: text.substring(from), style: run.style));
    }
  }
  return out;
}

/// [line] in runs of its syntax [spans] (`start, length, capture`
/// triples), plain where none.
List<TextSpan> spansOf(Tokens t, String line, Uint32List? spans) {
  if (spans == null) return [TextSpan(text: line)];
  final out = <TextSpan>[];
  var at = 0;
  for (var k = 0; k + 2 < spans.length; k += 3) {
    final start = min(spans[k], line.length);
    final end = min(spans[k] + spans[k + 1], line.length);
    if (start > at) out.add(TextSpan(text: line.substring(at, start)));
    if (end <= start) continue;
    final ink = t.ink(Capture.values[spans[k + 2]]);
    out.add(
      TextSpan(
        text: line.substring(start, end),
        style: TextStyle(
          color: ink.color,
          fontStyle: ink.italic ? FontStyle.italic : null,
          fontWeight: ink.bold ? FontWeight.w700 : null,
        ),
      ),
    );
    at = end;
  }
  if (at < line.length) out.add(TextSpan(text: line.substring(at)));
  return out;
}
