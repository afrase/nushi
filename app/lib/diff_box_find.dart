import 'package:diff_view/diff_view.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/diff_find.dart';
import 'package:nushi/line_search.dart' show LazyKeys;
import 'package:nushi/syntax.dart';
import 'package:nushi/transcript_find.dart';

/// A `DiffBox`'s part of ⌘F: what was found, for which text in which
/// lines, each hit by its key; the hits marked, the current one gone to,
/// and kept where it was across a switch of views (ADR 0107).
class DiffBoxFind {
  (String, SyntaxLines)? _foundFor;
  List<DiffHit> _steps = const []; // in the find's order, each its key's
  List<DiffHit> _marked = const []; // those and the unchanged lines' others
  String? _shown; // the hit last gone to

  /// The find's current hit, while it holds these hits.
  DiffHit? _now(Find f) {
    if (_steps.isEmpty || f.hits.length != _steps.length) return null;
    final h = _steps[f.at.clamp(0, _steps.length - 1)];
    return f.current == hitKey(h) ? h : null;
  }

  /// Finds and marks what [f] asks for in [c]'s [lines], and goes to its
  /// current hit. [alive] says whether the box is still there once the
  /// frame ends, when the find is told its hits.
  void show(
    Find f,
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
      _steps = _marked = const [];
      return;
    }
    if (_foundFor != (q, lines)) {
      _foundFor = (q, lines);
      final doc = c.document;
      final hits = findInDiff(
        lines.plainAt,
        doc.oldLineCount,
        doc.newLineCount,
        q,
      );
      final steps = _steps = hits.steps;
      _marked = [...steps, ...hits.also];
      // Each key made only when read: there can be tens of thousands.
      tell(LazyKeys(steps.length, (i) => hitKey(steps[i])));
    }
    final now = _now(f);
    lines.mark(_marked, now);
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
    Find f,
    DiffViewController c, {
    required bool unified,
    required bool Function() current,
  }) {
    final now = _now(f);
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
