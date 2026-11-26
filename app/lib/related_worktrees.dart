import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';

/// A chat's related worktrees (ADR 0081), as the daemon says them: the list,
/// which of them the Changes view shows, and each one's stats, for what's on
/// screen.
///
/// Stats cost git processes, so a row asks for them by being built ([want]):
/// a widget collapsed, a row folded away and a panel not shown ask for
/// nothing. An answer lasts until the worktree's commits move, or a turn ends
/// for one that's present (its uncommitted work can change without any
/// commit), or Reload. A removed one's commits can't change: it's read once.
/// Nothing here runs on a timer.
///
/// A path can have several records: a worktree removed and another made
/// at its path since (issue #118). Each is told by its key ([keyOf]), and
/// the daemon answers stats for each record of a path asked, in its list's
/// order, which only grows: this list is the front of it.
class RelatedWorktrees extends ChangeNotifier {
  new(this.chatId);

  final String chatId;

  /// Who the stats are asked of: the Mac's app sets it, as a phone has no
  /// Changes view.
  NushiServiceClient? client;

  /// The worktrees, in the order they were found.
  List<RelatedWorktree> get list => _list;
  List<RelatedWorktree> _list = const [];
  List<String> _keys = const []; // list's, each record's key

  /// The key of the worktree the Changes view shows ([keyOf]), null for
  /// the chat's own folder.
  String? get shown => _shown;
  String? _shown;

  /// The Scope (by name) picked for a related worktree: the chat's own stays
  /// as it was left. In the app's memory only.
  String? scope;

  bool _asked = false; // a click asked for the worktree shown to be read
  final _wanted = <String, int>{};
  final _stats = <String, RelatedWorktreeStats>{};
  final _counted = <String, String>{}; // what each stat was read for
  final _dirty = <String>{}; // to read again, whatever its commits say
  bool _soon = false; // a fetch is on its way
  bool _fetching = false;
  bool _again = false; // more came due during the fetch
  int _taken = 0; // lists taken: an answer asked before one is older

  /// The worktree the Changes view shows, if one is.
  RelatedWorktree? get picked => recordOf(_shown);

  /// [w]'s key: its path, or for a later record of a path made again its
  /// path and how many came before it. It stays as long as its record. A
  /// [w] the list no longer holds as it is (a newer list came, its head
  /// moved) is the one record of its path, call and branch, or of those
  /// the one at its last head (one call can make a path again on its
  /// branch); null when that's not one record, never another record's key.
  String? keyOf(RelatedWorktree w) {
    bool same(RelatedWorktree k) =>
        k.path == w.path && k.callId == w.callId && k.branch == w.branch;
    var i = _list.indexWhere((k) => identical(k, w));
    if (i < 0) i = _list.indexOf(w);
    if (i < 0) i = _onlyOne(same);
    if (i == -2) i = _onlyOne((k) => same(k) && k.lastHead == w.lastHead);
    return i < 0 ? null : _keys[i];
  }

  /// The index of the one record of the list that [test] takes, -1 for
  /// none, -2 for more than one.
  int _onlyOne(bool Function(RelatedWorktree) test) {
    final i = _list.indexWhere(test);
    if (i < 0) return -1;
    return _list.lastIndexWhere(test) == i ? i : -2;
  }

  /// The record of [key], if there is one.
  RelatedWorktree? recordOf(String? key) {
    final i = key == null ? -1 : _keys.indexOf(key);
    return i < 0 ? null : _list[i];
  }

  /// The worktrees to list: present ones, then removed ones, each the
  /// latest first.
  List<RelatedWorktree> get ordered => [
    ...list.reversed.where((w) => w.state == 'present'),
    ...list.reversed.where((w) => w.state != 'present'),
  ];

  /// Asks the daemon, which looks first: when the chat opens, as its events
  /// have no number to catch up from, and on Reload.
  Future<void> read() async {
    final client = this.client;
    if (client == null) return;
    final taken = _taken;
    try {
      final got = await client.getRelatedWorktrees(
        GetRelatedWorktreesRequest(chatId: chatId),
      );
      if (taken == _taken) take(got.worktrees); // else an event is newer
    } on Object {
      // None to show; the next event or Reload says.
    }
  }

  /// The daemon said [worktrees], all of them.
  void take(List<RelatedWorktree> worktrees) {
    _taken++;
    final same = listEquals(worktrees, list);
    _list = worktrees;
    _keys = relatedKeys(worktrees);
    _fetchSoon();
    if (same) return;
    if (picked == null) _shown = null; // it's the chat's folder again
    notifyListeners();
  }

  /// A turn ended: what's on screen of the worktrees still there is read
  /// again. Their heads may not have moved, so an event may not come.
  void turnEnded() {
    _dirty.addAll([
      for (var i = 0; i < _list.length; i++)
        if (_list[i].state == 'present') _keys[i],
    ]);
    _fetchSoon();
  }

  /// Reload: looks, then reads what's on screen again.
  Future<void> reload() async {
    if (list.isEmpty) return;
    _dirty.addAll(_keys);
    await read();
    _fetchSoon();
  }

  /// Shows the worktree of [key] in the Changes view, or the chat's own
  /// folder (null). A click asks for this: it's read at once.
  void pick(String? key) {
    _shown = key;
    _asked = key != null;
    notifyListeners();
  }

  /// A click asks for the worktree shown to be read, as it is now.
  void ask() {
    if (_shown == null) return;
    _asked = true;
    notifyListeners();
  }

  /// A click picks a scope for the worktrees.
  void pickScope(String name) {
    scope = name;
    ask();
  }

  /// Whether a click asked for a read that hasn't started.
  bool get asked => _asked;

  /// Takes that ask: a read of a related worktree needs one, as it runs its
  /// filters (ADR 0081).
  bool takeAsked() {
    final was = _asked;
    _asked = false;
    return was;
  }

  /// A row of the worktree of [key] is on screen: its stats are read when
  /// due.
  void want(String key) {
    _wanted.update(key, (n) => n + 1, ifAbsent: () => 1);
    _fetchSoon();
  }

  /// A row of the worktree of [key] left the screen.
  void unwant(String key) {
    final n = _wanted[key] ?? 0;
    if (n <= 1) {
      _wanted.remove(key);
    } else {
      _wanted[key] = n - 1;
    }
  }

  /// The stats of the worktree of [key] as last read, if they have been.
  RelatedWorktreeStats? stats(String key) => _stats[key];

  /// Reads the stats of the worktree of [key] now, for a click: never from
  /// what was read.
  Future<RelatedWorktreeStats?> statsNow(String key) async {
    final w = recordOf(key);
    final client = this.client;
    if (w == null || client == null) return null;
    final counted = {key: _key(w)};
    _counted.addAll(counted); // no row's fetch for the same thing
    _dirty.remove(key);
    final got = await client.getRelatedWorktreeStats(
      GetRelatedWorktreeStatsRequest(chatId: chatId, paths: [w.path]),
    );
    _hold(got.stats, counted);
    return _stats[key];
  }

  /// What the worktree of [key] amounts to now, to tell when it changes;
  /// null until read.
  String? stamp(String key) {
    final s = _stats[key];
    final w = recordOf(key);
    return s == null || w == null
        ? null
        : '${_key(w)} ${s.files} ${s.added} ${s.removed} ${s.ahead}';
  }

  /// The branch shown on [callId]'s subagent: '' when it has no worktree.
  String tagFor(String callId) {
    final of = list.where((w) => w.callId == callId).toList();
    if (of.isEmpty) return '';
    final name = worktreeName(of.first);
    return of.length == 1 ? name : '$name +${of.length - 1}';
  }

  String _key(RelatedWorktree w) => '${w.state} ${w.baseCommit} ${w.lastHead}';

  bool _due(int i) {
    final key = _keys[i];
    return _wanted.containsKey(key) &&
        (_dirty.contains(key) || _counted[key] != _key(_list[i]));
  }

  void _fetchSoon() {
    if (_soon) return;
    _soon = true;
    // Rows come in one frame, and one call asks for them all.
    scheduleMicrotask(() {
      _soon = false;
      unawaited(_fetch());
    });
  }

  Future<void> _fetch() async {
    final client = this.client;
    if (client == null) return;
    if (_fetching) {
      _again = true;
      return;
    }
    final due = {
      for (var i = 0; i < _list.length; i++)
        if (_due(i)) _keys[i]: _key(_list[i]),
    };
    if (due.isEmpty) return;
    _fetching = true;
    // Marked first: a failure waits for the next event, turn or Reload.
    _counted.addAll(due);
    _dirty.removeAll(due.keys);
    try {
      final got = await client.getRelatedWorktreeStats(
        GetRelatedWorktreeStatsRequest(
          chatId: chatId,
          paths: {for (final k in due.keys) recordOf(k)!.path},
        ),
      );
      _hold(got.stats, due);
    } on Object {
      // As it was.
    } finally {
      _fetching = false;
      if (_again) {
        _again = false;
        _fetchSoon();
      }
    }
  }

  /// Keeps [stats], the n-th of a path the n-th record of it ([keyOf]):
  /// the daemon's list may have more of a path than this one yet, after.
  void _hold(List<RelatedWorktreeStats> stats, Map<String, String> keys) {
    final seen = <String, int>{};
    for (final s in stats) {
      final n = seen[s.path] = (seen[s.path] ?? -1) + 1;
      _stats[relatedKey(s.path, n)] = s;
    }
    _counted.addAll(keys);
    if (stats.isNotEmpty) notifyListeners();
  }
}

/// The key of the [n]-th record (from 0) of [path] in a chat's list: its
/// path for the first, as nearly every path has one. git refuses a NUL in
/// a path, so none can be another's.
String relatedKey(String path, int n) => n == 0 ? path : '$path\u0000$n';

/// The folder of the record of [key] ([relatedKey]).
String relatedPath(String key) => key.split('\u0000').first;

/// The keys of [list]'s records, in its order ([relatedKey]).
List<String> relatedKeys(List<RelatedWorktree> list) {
  final seen = <String, int>{};
  return [
    for (final w in list)
      relatedKey(w.path, seen[w.path] = (seen[w.path] ?? -1) + 1),
  ];
}

/// [w]'s name to show: its branch as plain text (git takes control and bidi
/// characters in one, and an agent chooses it), else its last commit, else
/// its folder's name.
String worktreeName(RelatedWorktree w) {
  final branch = plainName(w.branch);
  if (branch.isNotEmpty) return branch;
  final head = w.lastHead;
  return head.isEmpty
      ? plainName(w.path.split('/').last)
      : head.substring(0, min(7, head.length));
}

/// How [w] ended, in the panel's words: "Merged" when its commits are on
/// the branch, as git shows it or, for a squash merge git can't see, as
/// GitHub has its pull request merged (asked once it's gone, again while
/// it's open; issue 83); "Removed", or "Merged, removed", once it's gone;
/// '' for one still there and not merged.
String worktreeEnd(RelatedWorktree w) {
  final merged = w.merged || w.pullMerged;
  return switch ((w.state == 'present', merged)) {
    (true, false) => '',
    (true, true) => 'Merged',
    (false, false) => 'Removed',
    (false, true) => 'Merged, removed',
  };
}
