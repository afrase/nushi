import 'dart:typed_data';

import 'package:diff_view/diff_view.dart';

/// A find's match in a diff: its side, its line (from 0), where in the line
/// and how long, in UTF-16 units.
typedef DiffHit = ({PaneSide side, int line, int start, int length});

/// What ⌘F finds in a diff: `steps`, the hits ⏎ goes through, top to
/// bottom; and `also`, the same text on an unchanged line's other side,
/// marked but not counted, so an unchanged line isn't found twice.
typedef DiffHits = ({List<DiffHit> steps, List<DiffHit> also});

/// A hit's name for the find's list.
String hitKey(DiffHit h) => '${h.side.index}:${h.line}:${h.start}';

/// The hits of [query] in [lines]; case aside. The sides are walked
/// together: unchanged lines meet, so what's between them is in order.
DiffHits findInDiff(
  DiffLineSource lines,
  int oldLines,
  int newLines,
  String query,
) {
  final q = query.toLowerCase();
  final steps = <DiffHit>[];
  final also = <DiffHit>[];
  void add(List<DiffHit> to, PaneSide side, DiffLine l) {
    final text = l.text.toLowerCase();
    // A few characters change length when lowered: where they are, the
    // offsets would be of another text.
    if (text.length != l.text.length) return;
    for (final m in q.allMatches(text)) {
      to.add((side: side, line: l.line, start: m.start, length: q.length));
    }
  }

  var (o, n) = (0, 0);
  while (o < oldLines || n < newLines) {
    final old = o < oldLines ? lines.lineAt(PaneSide.old, o) : null;
    final neu = n < newLines ? lines.lineAt(PaneSide.neu, n) : null;
    if (old != null && old.kind != LineKind.unchanged) {
      add(steps, PaneSide.old, old);
      o++;
    } else if (neu != null && neu.kind != LineKind.unchanged) {
      add(steps, PaneSide.neu, neu);
      n++;
    } else {
      if (neu != null) add(steps, PaneSide.neu, neu);
      if (old != null) add(also, PaneSide.old, old);
      o++;
      n++;
    }
  }
  return (steps: steps, also: also);
}

/// [line] with the [hits] on it drawn: tinted as a changed word is, and in
/// the capture [mark] (the current one, [now], in [markNow]) in place of
/// its syntax.
DiffLine markHits(
  DiffLine line,
  List<DiffHit> hits,
  DiffHit? now, {
  required int mark,
  required int markNow,
}) {
  final length = line.text.length;
  final captures = Int32List(length)..fillRange(0, length, -1);
  final syntax = line.syntax;
  for (var i = 0; i + 2 < syntax.length; i += 3) {
    final end = (syntax[i] + syntax[i + 1]).clamp(0, length);
    if (syntax[i] < end) captures.fillRange(syntax[i], end, syntax[i + 2]);
  }
  for (final h in hits) {
    captures.fillRange(
      h.start,
      (h.start + h.length).clamp(0, length),
      h == now ? markNow : mark,
    );
  }
  final runs = <int>[];
  for (var i = 0; i < length;) {
    var end = i + 1;
    while (end < length && captures[end] == captures[i]) {
      end++;
    }
    if (captures[i] >= 0) runs.addAll([i, end - i, captures[i]]);
    i = end;
  }
  return DiffLine(
    line: line.line,
    text: line.text,
    kind: line.kind,
    block: line.block,
    ending: line.ending,
    inner: Uint32List.fromList([
      ...line.inner,
      for (final h in hits) ...[h.start, h.length, innerChanged],
    ]),
    syntax: Uint32List.fromList(runs),
  );
}
