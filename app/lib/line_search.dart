import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:nushi/preview_find.dart';

// ⌘F in a long text (a read-only source of megabytes) without holding the
// UI thread: the search looks through the lines a slice at a time, the
// rest after the frames and keys waiting, a later query dropping an
// earlier one's search unfinished; it keeps at most [findCeiling] matches,
// packed, with no object or string apiece, and the bar says when there
// are more. The lines in sight find their own matches, all of them.

/// The most matches a long text's find keeps; past it the bar counts
/// "10,000+".
const findCeiling = 10000;

/// How many characters a slice looks through before it lets a frame in:
/// a millisecond or two, in a debug build, with matches all along.
const int sliceChars = 1 << 18;

/// Matches in a text's lines, top to bottom: each its line (from 0) and
/// its characters there.
class PackedHits {
  /// None yet.
  new();

  /// Of [at], packed as `_at` is.
  new _of(Iterable<int> at) {
    _at.addAll(at);
  }

  final List<int> _at = []; // line, start, end, line, start, end…

  /// How many there are.
  int get length => _at.length ~/ 3;

  bool get isEmpty => _at.isEmpty;

  int line(int i) => _at[i * 3];
  int start(int i) => _at[i * 3 + 1];
  int end(int i) => _at[i * 3 + 2];

  void _add(int line, int start, int end) => _at.addAll([line, start, end]);

  /// The match at [line] from [start], or -1: a binary search, as they're
  /// in order.
  int indexOf(int line, int start) {
    var (lo, hi) = (0, length - 1);
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final c = this.line(mid) != line
          ? this.line(mid).compareTo(line)
          : this.start(mid).compareTo(start);
      if (c == 0) return mid;
      if (c < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }

  /// Each match's key for the find ("line:start"), made only when read.
  List<String> get keys => LazyKeys(length, (i) => '${line(i)}:${start(i)}');
}

/// A find's keys for its hits, each made only when read: [length] of
/// them, the one at `i` its key function's; read only.
class LazyKeys extends ListBase<String> {
  new(this._length, this._key);

  final int _length;
  final String Function(int i) _key;

  @override
  int get length => _length;

  @override
  set length(int n) => throw UnsupportedError('read only');

  @override
  String operator [](int i) => _key(RangeError.checkValidIndex(i, this));

  @override
  void operator []=(int i, String key) => throw UnsupportedError('read only');
}

/// Where a search goes on from: a match's line and its start there.
typedef Spot = ({int line, int start});

/// One search at a time through a text's lines (`LineSearch.start`, or
/// `LineSearch.back` up from the end).
class LineSearch {
  int _run = 0;

  /// The characters looked at since a test last set it to 0, the
  /// keystroke's own slice included.
  @visibleForTesting
  static int looked = 0;

  /// Drops the search under way, if any: its result never comes.
  void cancel() => _run++;

  /// Looks for [query] (lowered) in [lines], each cut at [cut]
  /// characters, from the top or from past the match at [after], the
  /// first slice now and each next one once what waits on the UI thread
  /// has run; [done] takes the matches, at most [findCeiling], and whether
  /// there were more, unless another search or a [cancel] came first.
  void start(
    List<String> lines,
    String query, {
    required int cut,
    required void Function(PackedHits hits, {required bool more}) done,
    Spot? after,
  }) {
    final hits = PackedHits();
    var more = false;
    final from = after?.line ?? 0;
    _slices(lines.length - from, (k) {
      final i = from + k;
      final line = _cut(lines[i], cut);
      for (final (start, end) in hitsIn(line, query)) {
        if (i == after?.line && start <= after!.start) continue;
        if (hits.length == findCeiling) {
          more = true;
          return null;
        }
        hits._add(i, start, end);
      }
      return line.length + 1;
    }, () => done(hits, more: more));
  }

  /// [start]'s search the other way: up from the end, or from before the
  /// match at [before]; [done] takes the last [findCeiling] matches at
  /// most, in the text's order, and how many come before them, counted to
  /// the top, so the first of them is known by its number.
  void back(
    List<String> lines,
    String query, {
    required int cut,
    required void Function(PackedHits hits, {required int earlier}) done,
    Spot? before,
  }) {
    final kept = <int>[]; // end, start, line, from the last kept up
    var earlier = 0;
    final from = before?.line ?? lines.length - 1;
    _slices(from + 1, (k) {
      final i = from - k;
      final line = _cut(lines[i], cut);
      for (final (start, end) in hitsIn(line, query).toList().reversed) {
        if (i == before?.line && start >= before!.start) continue;
        if (kept.length < findCeiling * 3) {
          kept.addAll([end, start, i]);
        } else {
          earlier++;
        }
      }
      return line.length + 1;
    }, () => done(PackedHits._of(kept.reversed), earlier: earlier));
  }

  static String _cut(String line, int cut) =>
      line.length > cut ? line.substring(0, cut) : line;

  /// Runs [look] on each of [count] lines (its own count, from 0), a slice
  /// of [sliceChars] at a time, then [end], unless overtaken; [look]
  /// answers the characters it looked at, or null to end there.
  void _slices(int count, int? Function(int k) look, void Function() end) {
    final run = ++_run;
    var k = 0;
    void slice() {
      if (run != _run) return;
      var left = sliceChars;
      while (k < count && left > 0) {
        final n = look(k);
        if (n == null) break;
        left -= n;
        looked += n;
        k++;
      }
      if (k < count && left <= 0) return Timer.run(slice);
      // Done before it's told: what it tells may start the next search.
      _run++;
      end();
    }

    slice();
  }
}

/// Where a step past the matches a [LaterFind] keeps goes on to look.
enum Beyond {
  /// On from the last one kept, which has more after it.
  after,

  /// Round to the top, from the last match of all.
  top,

  /// Back from the first one kept, which has more before it.
  before,

  /// Round to the end, from the first match of all.
  end,
}

/// A preview's find whose matches come a moment after its query, from a
/// [LineSearch]: the bar keeps the last count till they come, a ⏎
/// pressed meanwhile is taken once they have, and past [findCeiling] the
/// count says "10,000+". It keeps at most [findCeiling] matches at a time:
/// a step past them asks its view to look on ([onBeyond]) and goes on
/// into what that finds, so ⏎ and ⇧⏎ still reach every match.
class LaterFind extends PreviewFind {
  bool _looking = false;
  bool _more = false;
  int _base = 0;
  int _steps = 0;
  bool _ask = false;

  /// Looks on past the matches kept, the way given, and hands what it
  /// finds to [took]; null: a step goes round the matches kept.
  void Function(Beyond way)? onBeyond;

  /// Whether the matches for the query are still being looked for.
  bool get looking => _looking;

  /// How many matches come before the first one kept.
  int get base => _base;

  /// A search for the query has started: what the last one found past
  /// the ceiling isn't carried over to its count meanwhile.
  void look() {
    _looking = true;
    _more = _ask = false;
    _steps = _base = 0;
  }

  /// The search found [hits], the one at [at] current, [base] matches
  /// before them and [more] after.
  void took(List<String> hits, int at, {required bool more, int base = 0}) {
    _looking = false;
    _more = more;
    _base = base;
    final steps = _steps;
    final ask = _ask || steps != 0;
    _steps = 0;
    _ask = false;
    final n = hits.length;
    final to = at + steps;
    if (n == 0 || (to >= 0 && to < n)) return foundAt(hits, to, ask: ask);
    // The steps taken meanwhile go past these too.
    final edge = to < 0 ? 0 : n - 1;
    foundAt(hits, edge);
    step(to - edge);
  }

  /// The last query's count while it looks, nothing before the first:
  /// never "None" for a query not looked for yet. Past the ceiling, the
  /// count from the top and how many there are at least.
  @override
  String get count {
    if (_looking && hits.isEmpty) return '';
    if ((query ?? '').isEmpty || hits.isEmpty || (!_more && _base == 0)) {
      return super.count;
    }
    final number = _base + order.number(at, hits.length);
    final total = _base + hits.length;
    return _more ? '$number of ${_grouped(total)}+' : '$number of $total';
  }

  @override
  void step(int by) {
    if (_looking) {
      _steps += by;
      return;
    }
    final n = hits.length;
    final to = at + by;
    final beyond = onBeyond;
    if (n == 0 || (to >= 0 && to < n) || (!_more && _base == 0)) {
      return super.step(by);
    }
    if (beyond == null) return super.step(by);
    _looking = _ask = true;
    if (to >= n) {
      _steps = to - n;
      beyond(_more ? Beyond.after : Beyond.top);
    } else {
      _steps = to + 1;
      beyond(_base > 0 ? Beyond.before : Beyond.end);
    }
  }

  @override
  void close() {
    _looking = _more = _ask = false;
    _base = _steps = 0;
    super.close();
  }
}

/// [n] with its thousands set apart, as the ceiling's words have it.
String _grouped(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
