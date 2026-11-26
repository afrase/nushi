import 'dart:math';

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/painting.dart';

import 'package:nushi/editor_sight.dart' show firstFrom;
import 'package:nushi/source_spans.dart' show Filled;
import 'package:re_editor/re_editor.dart';

// The marks the file editor's ink draws a line's code for (`EditorInk`):
// the stretches of it on each of the fills re_editor paints under it.

/// A line's hits as re_editor paints them, worked out once from what they
/// come from: the find's [matches], the line's [part] of the window they
/// are painted in, its [length]. What `EditorFind`'s marking gives
/// re_editor to paint and what the ink draws code for, alike.
class LineHits {
  /// Line [index]'s matches in [part] as re_editor paints them, each
  /// asked of [shown] but those [was] has already asked (the same
  /// matches, the line's part or length since changed). A match is in one
  /// line: the find's query has none of their ends.
  factory of(
    int index,
    int length,
    TextRange part,
    List<CodeLineSelection> matches,
    CodeLineSelection? Function(CodeLineSelection) shown, {
    LineHits? was,
  }) {
    final first = firstFrom(matches, index, part.start);
    var end = first;
    while (end < matches.length &&
        matches[end].startIndex == index &&
        matches[end].startOffset <= part.end) {
      end++;
    }
    final kept = was != null && identical(was.matches, matches) ? was : null;
    var asked = 0;
    final asShown = <CodeLineSelection?>[];
    final painted = <CodeLineSelection>[];
    final at = <CodeLineSelection>[];
    final stretches = <(int, int)>[];
    for (var i = first; i < end; i++) {
      final k = kept == null ? -1 : i - kept._first;
      final CodeLineSelection? a;
      if (k >= 0 && k < kept!._asShown.length) {
        a = kept._asShown[k];
      } else {
        asked++;
        a = shown(matches[i]);
      }
      asShown.add(a);
      if (a == null) continue;
      painted.add(a);
      if (a.startIndex != index) continue;
      final to = a.isSameLine ? a.endOffset : length;
      if (a.startOffset < to) {
        at.add(a);
        stretches.add((min(a.startOffset, length), min(to, length)));
      }
    }
    return LineHits._(
      index,
      matches,
      part,
      length,
      painted,
      at,
      Stretches(stretches),
      asked,
      first,
      asShown,
    );
  }

  new _(
    this._index,
    this.matches,
    this.part,
    this.length,
    this.painted,
    this.at,
    this.all,
    this.asked,
    this._first,
    this._asShown,
  );

  final int _index;
  final List<CodeLineSelection> matches;
  final TextRange part;
  final int length;

  /// Each hit as re_editor paints it, in order, and its stretch in [all].
  final List<CodeLineSelection> at;
  final Stretches all;

  /// How many matches were asked of re_editor for them.
  final int asked;

  // Each match from the `_first` of [matches] on, as re_editor paints it
  // (none: it doesn't).
  final int _first;
  final List<CodeLineSelection?> _asShown;

  /// The line's matches in [part] as re_editor paints them, in order.
  final List<CodeLineSelection> painted;

  // Those but the selection's, for the selection last asked for.
  (int, int, int, int)? _butFor;
  List<CodeLineSelection> _but = const [];
  late final bool _oneLine = painted.every((a) => a.startIndex == _index);

  /// [painted] but the one [s] is exactly on, if one is: it shows as the
  /// selection.
  List<CodeLineSelection> paintedBut(CodeLineSelection s) {
    if (s.startIndex != _index && _oneLine) return painted;
    final key = (s.startIndex, s.startOffset, s.endIndex, s.endOffset);
    if (key == _butFor) return _but;
    _butFor = key;
    final i = painted.indexWhere(
      (a) =>
          a.startIndex == s.startIndex &&
          a.startOffset == s.startOffset &&
          a.endIndex == s.endIndex &&
          a.endOffset == s.endOffset,
    );
    return _but = i < 0
        ? painted
        : [...painted.take(i), ...painted.skip(i + 1)];
  }

  // The stretches less one, the selection's, as last asked for.
  int _skipped = -1;
  late Stretches _less;

  /// The stretches but that of the hit [s] is exactly on, if one is: it
  /// shows as the selection.
  Stretches without(CodeLineSelection s) {
    var (lo, hi) = (0, at.length);
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (at[mid].startOffset < s.startOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (var i = lo; i < at.length; i++) {
      final a = at[i];
      if (a.startOffset != s.startOffset) break;
      if (a.endIndex != s.endIndex || a.endOffset != s.endOffset) continue;
      if (i != _skipped) {
        _skipped = i;
        _less = Stretches([...all.all.take(i), ...all.all.skip(i + 1)]);
      }
      return _less;
    }
    return all;
  }
}

/// A line's stretches, as a key: equal when they're the same.
@immutable
class Stretches {
  const new(this.all);

  /// None.
  static const none = Stretches([]);

  final List<(int, int)> all;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is Stretches && listEquals(other.all, all);

  @override
  int get hashCode => Object.hashAll(all);
}

/// The stretches of a line on each fill: the [selected] parts (in order,
/// apart) on [selection], [hits] (in order, apart) on [hit], or on [both]
/// where they meet; side by side on the same fill, one stretch.
List<Filled> filled(
  List<(int, int)> selected,
  List<(int, int)> hits, {
  required Color hit,
  required Color selection,
  required Color both,
}) {
  if (selected.isEmpty) {
    return [for (final (a, b) in hits) (start: a, end: b, fill: hit)];
  }
  final edges = <int>{
    for (final (a, b) in selected) ...[a, b],
    for (final (a, b) in hits) ...[a, b],
  }.toList()..sort();
  final out = <Filled>[];
  var (i, j) = (0, 0);
  for (var k = 0; k + 1 < edges.length; k++) {
    final (a, b) = (edges[k], edges[k + 1]);
    while (i < selected.length && selected[i].$2 <= a) {
      i++;
    }
    while (j < hits.length && hits[j].$2 <= a) {
      j++;
    }
    final inSelection = i < selected.length && selected[i].$1 <= a;
    final inHit = j < hits.length && hits[j].$1 <= a;
    if (!inSelection && !inHit) continue;
    final fill = inSelection && inHit
        ? both
        : inSelection
        ? selection
        : hit;
    if (out.lastOrNull case final last?
        when last.end == a && last.fill == fill) {
      out.last = (start: last.start, end: b, fill: fill);
    } else {
      out.add((start: a, end: b, fill: fill));
    }
  }
  return out;
}
