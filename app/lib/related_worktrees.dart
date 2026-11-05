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
class RelatedWorktrees extends ChangeNotifier {
  new(this.chatId);

  final String chatId;

  /// Who the stats are asked of: the Mac's app sets it, as a phone has no
  /// Changes view.
  NushiServiceClient? client;

  /// The worktrees, in the order they were found.
  List<RelatedWorktree> list = const [];

  /// The path the Changes view shows, null for the chat's own folder.
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
  RelatedWorktree? get picked =>
      list.where((w) => w.path == _shown).firstOrNull;

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
    list = worktrees;
    _fetchSoon();
    if (same) return;
    if (picked == null) _shown = null; // it's the chat's folder again
    notifyListeners();
  }

  /// A turn ended: what's on screen of the worktrees still there is read
  /// again. Their heads may not have moved, so an event may not come.
  void turnEnded() {
    _dirty.addAll(list.where((w) => w.state == 'present').map((w) => w.path));
    _fetchSoon();
  }

  /// Reload: looks, then reads what's on screen again.
  Future<void> reload() async {
    if (list.isEmpty) return;
    _dirty.addAll(list.map((w) => w.path));
    await read();
    _fetchSoon();
  }

  /// Shows [path] in the Changes view, or the chat's own folder (null). A
  /// click asks for this: it's read at once.
  void pick(String? path) {
    _shown = path;
    _asked = path != null;
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

  /// A row of [path] is on screen: its stats are read when due.
  void want(String path) {
    _wanted.update(path, (n) => n + 1, ifAbsent: () => 1);
    _fetchSoon();
  }

  /// A row of [path] left the screen.
  void unwant(String path) {
    final n = _wanted[path] ?? 0;
    if (n <= 1) {
      _wanted.remove(path);
    } else {
      _wanted[path] = n - 1;
    }
  }

  /// [path]'s stats as last read, if they have been.
  RelatedWorktreeStats? stats(String path) => _stats[path];

  /// Reads [path]'s stats now, for a click: never from what was read.
  Future<RelatedWorktreeStats?> statsNow(String path) async {
    final w = list.where((w) => w.path == path).firstOrNull;
    final client = this.client;
    if (w == null || client == null) return null;
    final key = {path: _key(w)};
    _counted.addAll(key); // no row's fetch for the same thing
    _dirty.remove(path);
    final got = await client.getRelatedWorktreeStats(
      GetRelatedWorktreeStatsRequest(chatId: chatId, paths: [path]),
    );
    _hold(got.stats, key);
    return got.stats.firstOrNull;
  }

  /// What [path] amounts to now, to tell when it changes; null until read.
  String? stamp(String path) {
    final s = _stats[path];
    final w = list.where((w) => w.path == path).firstOrNull;
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

  bool _due(RelatedWorktree w) =>
      _wanted.containsKey(w.path) &&
      (_dirty.contains(w.path) || _counted[w.path] != _key(w));

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
    final due = {for (final w in list.where(_due)) w.path: _key(w)};
    if (due.isEmpty) return;
    _fetching = true;
    // Marked first: a failure waits for the next event, turn or Reload.
    _counted.addAll(due);
    _dirty.removeAll(due.keys);
    try {
      final got = await client.getRelatedWorktreeStats(
        GetRelatedWorktreeStatsRequest(chatId: chatId, paths: due.keys),
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

  void _hold(List<RelatedWorktreeStats> stats, Map<String, String> keys) {
    for (final s in stats) {
      _stats[s.path] = s;
    }
    _counted.addAll(keys);
    if (stats.isNotEmpty) notifyListeners();
  }
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

/// "merged", or "removed" for one that's gone and that git doesn't show on
/// the branch: a squash merge reads as this, git can't see it. '' for one
/// still there and not merged.
String worktreeEnd(RelatedWorktree w) => w.merged
    ? 'merged'
    : w.state == 'present'
    ? ''
    : 'removed';
