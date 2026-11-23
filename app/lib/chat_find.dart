import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/transcript_find.dart';

/// Asks the daemon for a find's matches in a chat's items before one; null
/// when it can't (older than `findInChatApi`).
typedef AskAbove = Future<FindInChatResponse?> Function(
  FindInChatRequest request,
  CancelableSignal signal,
);

/// ⌘F in a chat's transcript, the whole chat (ADR 0144). The daemon counts
/// the matches in the items above what's loaded ([ask], FindInChat); each
/// is a hit keyed `far <item> <n>`, before the matches the transcript
/// finds in what's loaded. A step to one asks the transcript to load up to
/// its item ([pending]); once it's in and laid out, the step lands on that
/// item's own matches there. Typing goes to the first match loaded (the
/// nearest above with none), loading nothing; the first step from that
/// nearest one, either way, shows it.
class ChatFind extends Find {
  new(this._chat);

  final ChatState _chat;

  /// Set by the chat's transcript: the daemon's search, and the key of
  /// an item's entry (Marks.entry) once it's laid out, else null.
  AskAbove? ask;
  String? Function(String item)? entryOf;

  /// How long typing pauses before what is typed is looked for.
  static const Duration pause = Waits.typing;

  List<ChatMatch> _far = const [];
  List<String> _near = const [];
  Timer? _wait;
  Timer? _typing; // what's typed ([_next]) waits to be looked for
  String _next = '';
  CancelableSignal? _asking;
  bool _typed = false; // no step since the query changed
  int _stepAsk = -1;

  /// Something is looked for, or about to be (typed, in its pause): the
  /// chat keeps what it has loaded.
  bool get looking => _typing != null || (query ?? '').isNotEmpty;

  /// The daemon is being asked, or about to be.
  bool get searching => _typing != null || _wait != null || _asking != null;

  /// The daemon searches what isn't loaded, as far as is known (its last
  /// answer): no Load all. Kept from query to query, so the bar's line
  /// doesn't come and go as each is typed.
  bool get whole => _whole;
  bool _whole = true;

  /// The daemon's search stopped at its bound: the count is a floor.
  bool get more => _more;
  bool _more = false;

  /// The far hit a step went to, until its item's matches are laid out.
  String? get pending => _pending;
  String? _pending;

  /// Whether the last ask to show the current hit was a step.
  bool get stepped => asked == _stepAsk;

  /// The item of a far hit's [key]; null for a hit in what's loaded.
  static String? farItem(String? key) =>
      key != null && key.startsWith('far ') ? key.split(' ')[1] : null;

  @override
  String get count {
    final q = query ?? '';
    if (q.isNotEmpty && hits.isEmpty && searching) return '';
    final c = super.count;
    return _more && hits.isNotEmpty ? '$c+' : c;
  }

  /// What's typed is looked for after a pause ([pause]), in what's loaded
  /// and above it alike: a first letter matches most of a long chat, and
  /// marking it all, going to its first match and asking the daemon are
  /// work thrown away by the next. Cleared, or closed, at once.
  @override
  set query(String? q) {
    if (q == (_typing == null ? query : _next)) return;
    _typing?.cancel();
    _typing = null;
    if (q == query) return; // typed and taken back within the pause
    if (q == null || q.isEmpty) {
      _look(q);
      return;
    }
    _next = q;
    _typing = Timer(pause, () {
      _typing = null;
      _look(q);
    });
  }

  /// Looks for [q] now.
  void _look(String? q) {
    _typed = true;
    _pending = null;
    super.query = q;
    _askAbove(now: true);
  }

  @override
  void close() {
    _cancel();
    _typing?.cancel();
    _typing = null;
    _far = const [];
    _near = const [];
    _more = false;
    _pending = null;
    super.close();
  }

  /// The chat took a fresh snapshot (a reconnect, a rewind): what was
  /// counted above may be gone, so it's asked again.
  void reloaded() {
    if ((query ?? '').isNotEmpty) _askAbove();
  }

  void _cancel() {
    _wait?.cancel();
    _wait = null;
    _asking?.cancel();
    _asking = null;
  }

  /// Asks the daemon about what's above the loaded part, after a pause
  /// (none with [now]: the typing has paused already), cancelling what it
  /// asked before. With nothing above, the loaded find is all of it.
  void _askAbove({bool now = false}) {
    _cancel();
    _far = const [];
    _more = false;
    final q = query ?? '';
    if (q.isEmpty || ask == null || _chat.older == 0 || _chat.items.isEmpty) {
      _merge();
      return;
    }
    if (now) {
      unawaited(_askNow(q));
    } else {
      _wait = Timer(pause, () {
        _wait = null;
        unawaited(_askNow(q));
      });
    }
    _merge();
  }

  Future<void> _askNow(String q) async {
    final signal = _asking = CancelableSignal();
    FindInChatResponse? r;
    try {
      r = await ask!(
        FindInChatRequest(
          chatId: _chat.id,
          text: q,
          before: _chat.items.first.id,
        ),
        signal,
      );
    } on Object {
      r = null; // the loaded find, with Load all, as before
    }
    if (signal != _asking) return;
    _asking = null;
    _whole = r != null;
    if (r != null) {
      _far = r.matches;
      _more = r.more;
    }
    _merge();
    // The bar's line and count follow, whether or not the hits changed
    // (searching no more: "None" in place of nothing).
    notifyListeners();
  }

  @override
  void found(List<String> hits) {
    _near = hits;
    _merge();
  }

  @override
  void step(int by) {
    if (_typing != null) {
      // ⏎ before the pause is over: what's typed is looked for now, which
      // goes to its first match.
      _typing!.cancel();
      _typing = null;
      _look(_next);
      return;
    }
    if (hits.isEmpty) return;
    // With nothing loaded to go to, typing made the nearest match above
    // current without loading it: the first step, either way, shows it.
    final move = _typed && farItem(current) != null ? 0 : by;
    _typed = false;
    // Set before the step tells its listeners: the transcript loads a far
    // one's part as it hears of it.
    _stepAsk = asked + 1;
    final next = hits[(at + move) % hits.length];
    _pending = farItem(next) == null ? null : next;
    super.step(move);
  }

  /// The hits: the far ones whose items aren't laid out (not loaded, or
  /// loaded and not yet built), then the loaded ones. A pending step lands
  /// once its item is laid out.
  void _merge() {
    final all = _Hits([
      for (final m in _far)
        if (entryOf?.call(m.itemId) == null) m,
    ], _near);
    final far = all.far;
    if (_pending case final p? when !all.contains(p)) {
      _pending = null;
      final i = _landing(p, all);
      foundAt(all, i ?? min(far, max(0, all.length - 1)), ask: true);
      return;
    }
    if (all.isEmpty) {
      if (hits.isNotEmpty || at != 0) foundAt(const [], 0);
      return;
    }
    final was = current;
    final int i;
    final wasAt = was == null ? -1 : all.indexOf(was);
    if (_typed) {
      i = _near.isNotEmpty ? far : all.length - 1;
    } else if (wasAt >= 0) {
      i = wasAt;
    } else {
      i = min(at, all.length - 1);
    }
    if (hits case final _Hits before when before.same(all) && i == at) return;
    foundAt(all, i);
  }

  /// Where far hit [key] lands among [all]: its item's entry's match of
  /// the same place, or its last. An entry can hold several items (a run
  /// of calls, a subagent's call and steps), its marks theirs in order: the
  /// item's own come after the matches the daemon counted in the entry's
  /// items before it.
  int? _landing(String key, _Hits all) {
    final parts = key.split(' ');
    final item = parts[1];
    final entry = entryOf?.call(item);
    if (entry == null) return null;
    final mine = [
      for (final (i, k) in all.near.indexed)
        if (k.startsWith('$entry ')) all.far + i,
    ];
    if (mine.isEmpty) return null;
    var k = int.parse(parts[2]);
    for (final m in _far) {
      if (m.itemId == item) break;
      if (entryOf?.call(m.itemId) == entry) k += m.count;
    }
    return mine[min(k, mine.length - 1)];
  }

  @override
  void dispose() {
    _cancel();
    _typing?.cancel();
    super.dispose();
  }
}

/// A chat find's hits without a string for each: the far ones are runs of
/// an item's matches, each keyed `far <item> <k>` as it's read, then the
/// loaded ones' keys. A common query in a long chat has millions of
/// matches above what's loaded, and the hits are merged again on every
/// frame whose marks may have changed (a streaming reply's).
class _Hits extends ListBase<String> {
  new(this.runs, this.near) {
    var total = 0;
    for (final m in runs) {
      _ends.add(total += m.count);
    }
  }

  /// The items with matches above what's laid out, in order.
  final List<ChatMatch> runs;

  /// The keys of the matches laid out.
  final List<String> near;

  // Each run's end among the far hits.
  final _ends = <int>[];

  /// How many hits are far ones.
  int get far => _ends.lastOrNull ?? 0;

  @override
  int get length => far + near.length;

  @override
  set length(int _) => throw UnsupportedError('A find’s hits are fixed');

  @override
  String operator [](int i) {
    if (i >= far) return near[i - far];
    RangeError.checkNotNegative(i);
    var (lo, hi) = (0, _ends.length - 1);
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_ends[mid] > i) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return 'far ${runs[lo].itemId} ${i - (lo == 0 ? 0 : _ends[lo - 1])}';
  }

  @override
  void operator []=(int i, String value) =>
      throw UnsupportedError('A find’s hits are fixed');

  @override
  int indexOf(Object? element, [int start = 0]) {
    final int i;
    if (ChatFind.farItem(element as String?) case final item?) {
      i = _farIndex(item, int.tryParse(element!.split(' ')[2]) ?? -1);
    } else {
      final n = near.indexOf(element ?? '');
      i = n < 0 ? -1 : far + n;
    }
    return i >= start ? i : -1;
  }

  @override
  bool contains(Object? element) => indexOf(element) >= 0;

  int _farIndex(String item, int k) {
    for (final (j, m) in runs.indexed) {
      if (m.itemId != item) continue;
      if (k < 0 || k >= m.count) return -1;
      return (j == 0 ? 0 : _ends[j - 1]) + k;
    }
    return -1;
  }

  /// Whether [other] has the same hits: the same runs and loaded keys.
  bool same(_Hits other) {
    if (runs.length != other.runs.length || !listEquals(near, other.near)) {
      return false;
    }
    for (var j = 0; j < runs.length; j++) {
      if (!identical(runs[j], other.runs[j])) return false;
    }
    return true;
  }
}
