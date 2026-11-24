import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A chat's folder as its changes last stood: the [span] its Changes view
/// and its details panel show (the folder's status, the scope, the base
/// and Commits' commits), its [branches] and worktrees for the Branch
/// row's menu, and the last read's [error]. One per chat, so a chat picked
/// again shows what it had at once, and one git read serves every view of
/// it.
///
/// It reads again when the folder may have changed: the chat's turn ended,
/// it moved, its worktree's base or its scope changed, a commit was made in
/// it, or the daemon is back after a read it was gone for. Only while
/// something shows it ([follow]): with nothing following it remembers the
/// read is behind. It reads again each time it is shown again, as a chat's
/// own triggers miss changes made outside it, showing what it had
/// meanwhile. Each such change bumps [moved], for what reads more than the
/// span (the Changes view's files, the change marks' base).
final class ChatChanges extends ChangeNotifier {
  new _(this.daemon, this.chat) : _key = _keyOf(chat), _wasBusy = chat.busy {
    chat.addListener(_check);
  }

  /// [chat]'s one [ChatChanges].
  factory of(Daemon daemon, ChatState chat) =>
      _all[chat] ??= ChatChanges._(daemon, chat);

  static final _all = Expando<ChatChanges>('chat changes');

  final Daemon daemon;
  final ChatState chat;

  /// The last read's span; null until one answered.
  ChangeSpan? get span => _span;
  ChangeSpan? _span;

  /// The folder's branches and worktrees, as last listed; null until
  /// listed, and outside git.
  ListBranchesResponse? get branches => _branches;
  ListBranchesResponse? _branches;

  /// Why the last listing of [branches] failed, in words (a git error: a
  /// lock, a broken ref); null once one answers. The menus say it in
  /// place of the list.
  String? get branchesError => _branchesError;
  String? _branchesError;

  /// Why the last read failed, in words; null once one answers.
  String? get error => _error;
  String? _error;

  /// Whether a read has answered, or failed, since the chat was opened.
  bool get known => _span != null || _error != null;

  /// Goes up each time the folder may have changed.
  final moved = ValueNotifier<int>(0);

  /// Goes up with [moved] but for a scope picked: the change marks' base
  /// (ADR 0131) doesn't follow the scope Changes shows.
  final baseMoved = ValueNotifier<int>(0);

  (String, String, String?, int) _key;
  bool _wasBusy;
  int _followers = 0;

  /// What was read is behind the folder's last change.
  bool _behind = true;

  /// A change's count: a read answers for the one it began in.
  int _gen = 0;
  Future<ChangeSpan>? _reading;
  int _readingGen = -1;
  int _asked = 0;

  late final _again = LoadAgain(daemon, _changed);

  static (String, String, String?, int) _keyOf(ChatState c) =>
      (c.folder, c.worktree?.base ?? '', c.scope, c.commits);

  /// Something shows it: what it has shows at once, and the first to show
  /// it reads again, as what it has may be behind though nothing here
  /// marked it (another chat in the folder, an editor or a terminal
  /// changed it); a later one reads only if it is behind.
  void follow() {
    final first = _followers++ == 0;
    if (!first && !_behind) return;
    // A read the marks began, unfollowed, listed no branches.
    if (first && _reading != null && _readingGen == _gen) {
      unawaited(listBranches());
    }
    read().ignore();
  }

  /// What showed it went.
  void unfollow() => _followers--;

  void _check() {
    final ended = _wasBusy && !chat.busy;
    _wasBusy = chat.busy;
    final key = _keyOf(chat);
    if (!ended && key == _key) return;
    final (folder, base, _, commits) = _key;
    final scopeOnly =
        !ended && key.$1 == folder && key.$2 == base && key.$4 == commits;
    _key = key;
    _changed(base: !scopeOnly);
  }

  /// The folder may have changed: read again while followed. [base]: the
  /// marks' base may have moved too (all but a scope picked).
  void _changed({bool base = true}) {
    _gen++;
    _behind = true;
    _again.cancel();
    if (_followers > 0) read().ignore();
    moved.value++;
    if (base) baseMoved.value++;
  }

  /// After [error], a read of the folder's that failed (the Changes view's
  /// files): reads again once the daemon is back, if it was gone.
  void failed(Object error) => _again.failed(error);

  /// The span as it stands: the last read's, unless the folder changed
  /// since; else [read].
  Future<ChangeSpan> current() => switch (_span) {
    final s? when !_behind => Future.value(s),
    _ => read(),
  };

  /// Reads the folder: the read under way since its last change, if one
  /// is, else a new one. The newest read asked for is what shows.
  Future<ChangeSpan> read() {
    if (_reading case final r? when _readingGen == _gen) return r;
    return _read();
  }

  /// Reads the folder now, though one is under way: a click, or a change
  /// made here (a worktree switched).
  Future<ChangeSpan> reload() {
    _gen++;
    return _read();
  }

  Future<ChangeSpan> _read() {
    final gen = _readingGen = _gen;
    final asked = ++_asked;
    if (_followers > 0) unawaited(listBranches());
    final reading = _reading = ChangeSpan.of(daemon, chat);
    reading
        .then(
          (s) {
            if (identical(_reading, reading)) _reading = null;
            if (asked != _asked) return;
            _span = s;
            _error = null;
            if (gen == _gen) _behind = false;
            notifyListeners();
          },
          onError: (Object e) {
            if (identical(_reading, reading)) _reading = null;
            if (asked != _asked) return;
            _error = errorText(e);
            _again.failed(e);
            notifyListeners();
          },
        )
        .ignore();
    return reading;
  }

  /// Lists the folder's branches and worktrees: with each read while
  /// something shows it (the change marks alone don't need them), and
  /// again as the Branch row's menu opens. A failed listing keeps what
  /// was listed and says why ([branchesError]); the daemon gone, it lists
  /// them again once it's back.
  Future<void> listBranches() async {
    try {
      _branches = await daemon.client.listBranches(
        ListBranchesRequest(folder: chat.folder),
      );
      _branchesError = null;
      notifyListeners();
    } on Object catch (e) {
      _branchesError = errorText(e);
      _again.failed(e);
      notifyListeners();
    }
  }
}
