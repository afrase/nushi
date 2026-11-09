import 'package:diff_view/diff_view.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/diff_find.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/transcript_find.dart';

/// A `DiffBox`'s part of ⌘F: what was found, for which text in which
/// lines, each hit by its key; the hits marked, the current one gone to,
/// and kept where it was across a switch of views (ADR 0107).
class DiffBoxFind {
  (String, SyntaxLines)? _foundFor;
  List<DiffHit> _also = const [];
  Map<String, DiffHit> _hits = const {};
  String? _shown; // the hit last gone to

  /// Finds and marks what [f] asks for in [c]'s [lines], and goes to its
  /// current hit. [alive] says whether the box is still there once the
  /// frame ends, when the find is told its hits.
  void show(
    TranscriptFind f,
    SyntaxLines lines,
    DiffViewController c,
    bool Function() alive,
  ) {
    final q = f.query ?? '';
    // Not while building: telling the bar rebuilds it.
    void tell(List<String> keys) =>
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (alive()) f.found(keys);
        });
    if (q.isEmpty) {
      if (_foundFor != null) {
        lines.mark(const [], null);
        tell(const []);
      }
      _foundFor = _shown = null;
      _hits = const {};
      return;
    }
    if (_foundFor != (q, lines)) {
      _foundFor = (q, lines);
      final doc = c.document;
      final hits = findInDiff(lines, doc.oldLineCount, doc.newLineCount, q);
      _also = hits.also;
      _hits = {for (final h in hits.steps) hitKey(h): h};
      tell(_hits.keys.toList());
    }
    final now = _hits[f.current];
    lines.mark([..._hits.values, ..._also], now);
    if (now != null && f.current != _shown) {
      _shown = f.current;
      c.jumpToLine(now.side, now.line);
    }
  }

  /// [c]'s view is switching, from the unified one if [unified]: the
  /// find's current hit, if the leaving view shows it, stays where it is.
  /// The view only keeps the line a third of the way down, and a row more
  /// or less above it (an inserted line, a deleted one) can push the hit
  /// out. [current] says, once the frame ends, whether [c] is still the
  /// box's view.
  void keepHit(
    TranscriptFind f,
    DiffViewController c, {
    required bool unified,
    required bool Function() current,
  }) {
    final now = _hits[f.current];
    if (now == null) return;
    // Where the leaving view, still laid out, shows it.
    final y = c.viewportYOfLine(now.side, now.line);
    final p = unified ? c.unifiedScroll : c.scroll(now.side);
    if (y == null || !p.hasClients || y < 0) return;
    if (y + c.resources.lineHeight > p.position.viewportDimension) return;
    // Before the leaving view's own keep, which this one replaces.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current()) c.jumpToLine(now.side, now.line, viewportY: y);
    });
  }
}
