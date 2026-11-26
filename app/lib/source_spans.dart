import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:nushi/theme/theme.dart';

/// The columns between tab stops where none is asked for (the phone's
/// source): Go's and a Makefile's indent reads as gofmt's and most
/// editors' four. The Mac's Files pane has it as a setting (`tabSize`),
/// for its source and its editor alike (ADR 0096).
const defaultTabSize = 4;

/// The room under a source's last line with Scroll past end on (Claude
/// desktop's and VS Code's): scrolled to its end, the last line [line]
/// high sits at the top of a [viewport] high view, under its [top] inset;
/// never less than the [bottom] inset it has otherwise.
double pastEndPadding(
  double viewport,
  double line, {
  required double top,
  required double bottom,
}) => max(bottom, viewport - line - top);

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

/// How many columns a tab at [column] spans: to the next stop, every
/// [size] columns.
int tabColumns(int column, int size) => size - column % size;

/// [runs], a line's text in styled runs from its start, with each tab
/// drawn to the next stop, every [tabSize] columns. Flutter draws a tab as
/// a space; the tab's run takes a font size ([fontSize] the line's) at
/// which that space spans the tab's columns, [column] wide each, with
/// [spacing] (the letter spacing the runs inherit, already in [column])
/// after it. Not letter
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
  required int tabSize,
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
      final n = tabColumns(at, tabSize);
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

/// A find's match in a line, by character, and whether it's the current
/// one (`preview_find.dart`'s `LineHit`).
typedef Hit = ({int start, int end, bool now});

/// [runs], a line's text in styled runs from its start, split where each
/// of [hits] (a find's matches in it, by character) starts and ends, a
/// hit's part drawn in [ink] of its run's colour ([plain] where the run
/// has none of its own): code keeps its contrast on the hit's fill, as on
/// a diff's tint (ADR 0086's amendment, issue 117). A line's spans are
/// built as it is, so this is once per line and query, not per frame.
List<TextSpan> onHits(
  List<TextSpan> runs,
  List<Hit> hits, {
  required Color plain,
  required Color Function(Color color, {required bool now}) ink,
}) {
  if (hits.isEmpty) return runs;
  return [
    for (final (text, style, hit) in _pieces(runs, hits))
      if (hit == null)
        TextSpan(text: text, style: style)
      else
        switch ((
          style?.color ?? plain,
          ink(style?.color ?? plain, now: hit.now),
        )) {
          (final was, final drawn) when was == drawn => TextSpan(
            text: text,
            style: style,
          ),
          (_, final drawn) => TextSpan(
            text: text,
            style: (style ?? const TextStyle()).copyWith(color: drawn),
          ),
        },
  ];
}

/// [runs] as they are drawn again over a selection ([hits] the find's
/// matches in the line, which are painted over the selection): each part
/// in [ink] of its colour ([plain] where it has none) on the selection's
/// fill, or a hit's over it, and clear where that is its own colour, as
/// what reads isn't drawn again. Null when nothing changes.
List<TextSpan>? overSelected(
  List<TextSpan> runs,
  List<Hit> hits, {
  required Color plain,
  required Color Function(Color color, Hit? hit) ink,
}) {
  var any = false;
  final out = <TextSpan>[];
  for (final (text, style, hit) in _pieces(runs, hits)) {
    final color = style?.color ?? plain;
    final drawn = ink(color, hit);
    if (drawn != color) any = true;
    out.add(
      TextSpan(
        text: text,
        style: (style ?? const TextStyle()).copyWith(
          // design: clear, not a colour: what reads isn't drawn again
          color: drawn == color ? const Color(0x00000000) : drawn,
        ),
      ),
    );
  }
  return any ? out : null;
}

/// [runs] in pieces, split where each of [hits] starts and ends: each
/// piece's text, its run's style and the hit it's in, if any. [hits] are
/// in order and apart, as a find gives them (`hitsIn`): one walk forward
/// over them, so a long line with a hit every few characters costs as
/// many steps as it has pieces.
Iterable<(String, TextStyle?, Hit?)> _pieces(
  List<TextSpan> runs,
  List<Hit> hits,
) => _split(
  runs,
  hits,
  (h) => h.start,
  (h) => h.end,
).map((p) => (p.text, p.style, p.inside));

/// [runs] split at the edges of [stretches] (in order and apart), as
/// [_pieces] for any kind of stretch: each piece's text, its run's style,
/// the stretch it's in.
Iterable<({String text, TextStyle? style, S? inside})> _split<S>(
  List<TextSpan> runs,
  List<S> stretches,
  int Function(S) start,
  int Function(S) end,
) sync* {
  var at = 0;
  var next = 0; // the first stretch that may still end after [from]
  for (final run in runs) {
    final text = run.text ?? '';
    final runEnd = at + text.length;
    var from = at;
    while (from < runEnd) {
      while (next < stretches.length && end(stretches[next]) <= from) {
        next++;
      }
      // The stretch [from] is in, or the next one's start.
      final s = next < stretches.length && start(stretches[next]) < runEnd
          ? stretches[next]
          : null;
      final inside = s != null && start(s) <= from;
      final to = s == null
          ? runEnd
          : inside
          ? min(end(s), runEnd)
          : min(start(s), runEnd);
      yield (
        text: text.substring(from - at, to - at),
        style: run.style,
        inside: inside ? s : null,
      );
      from = to;
    }
    at = runEnd;
  }
}

/// A stretch of a line on a fill painted under its code: from `start` to
/// `end`, by character.
typedef Filled = ({int start, int end, Color fill});

/// [runs], a line's text in styled runs from its start, its parts on
/// [filled] (in order and apart) drawn in [ink] of their colour ([plain]
/// where a run has none of its own) on that fill: the file editor's, whose
/// re_editor paints its selection and a find's hits under the spans it's
/// given (issue 117). A part whose ink is its own colour stays in its
/// run, unsplit; a run no fill reaches is itself, untouched, so a long
/// line costs what its fills cover; and a line whose code all reads on
/// its fills is `runs` itself, so re_editor keeps the paragraph it laid
/// out for them.
List<TextSpan> onFills(
  List<TextSpan> runs,
  List<Filled> filled, {
  required Color plain,
  required Color Function(Color color, Color fill) ink,
}) {
  if (filled.isEmpty) return runs;
  final out = <TextSpan>[];
  var changed = false;
  var at = 0;
  var next = 0; // the first stretch that may still end after [at]
  for (final run in runs) {
    final text = run.text ?? '';
    final runEnd = at + text.length;
    while (next < filled.length && filled[next].end <= at) {
      next++;
    }
    if (next == filled.length || filled[next].start >= runEnd) {
      out.add(run);
      at = runEnd;
      continue;
    }
    final color = run.style?.color ?? plain;
    final pieces = <TextSpan>[];
    // The run's text in its own colour, since its last part that isn't.
    final same = StringBuffer();
    void keep() {
      if (same.isEmpty) return;
      pieces.add(TextSpan(text: same.toString(), style: run.style));
      same.clear();
    }

    var from = at;
    var k = next;
    while (from < runEnd) {
      while (k < filled.length && filled[k].end <= from) {
        k++;
      }
      // The stretch [from] is in, or the next one's start.
      final f = k < filled.length && filled[k].start < runEnd
          ? filled[k]
          : null;
      final inside = f != null && f.start <= from;
      final to = f == null
          ? runEnd
          : inside
          ? min(f.end, runEnd)
          : min(f.start, runEnd);
      final piece = text.substring(from - at, to - at);
      final drawn = inside ? ink(color, f.fill) : color;
      if (drawn == color) {
        same.write(piece);
      } else {
        keep();
        pieces.add(
          TextSpan(
            text: piece,
            style: (run.style ?? const TextStyle()).copyWith(color: drawn),
          ),
        );
      }
      from = to;
    }
    if (pieces.isEmpty) {
      out.add(run);
    } else {
      keep();
      out.addAll(pieces);
      changed = true;
    }
    at = runEnd;
  }
  return changed ? out : runs;
}
