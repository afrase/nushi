import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

// What a chat's change marks and its Files tree's dots count from (ADR
// 0131), found once for the chat's folder and shared by both, so a file's
// marks and its dot can never disagree about the base.

/// What a file's change marks count from (ADR 0131).
enum MarksFrom {
  /// Where the chat's branch left its base, the Branch view's comparison.
  branch,

  /// Before the chat's own commits, on the branch it counts from itself
  /// (the default branch): the parent of the oldest of the branch's
  /// latest commits made since the chat began.
  chat,

  /// The last commit: no branch base, and no commit since the chat began
  /// (or a file outside the chat's folder).
  lastCommit,
}

/// A base found: what GetDiff's `base` is ('' for the last commit), and
/// what that is.
typedef MarksBase = ({String base, MarksFrom from});

/// The last commit as a base.
const MarksBase lastCommitBase = (base: '', from: MarksFrom.lastCommit);

/// [chat]'s base for its marks and dots, found when first asked and again
/// once it may have moved: the chat's turn ended, it committed, or its
/// folder or worktree changed. One lookup for every file shown and the
/// tree, and one notice to each of them (a file's `LineBase`, the tree's
/// `TreeDots`) when it may have moved, to ask again.
final class ChatMarksBase extends ChangeNotifier {
  new _(this.chat) {
    _key = _keyNow();
    _wasBusy = chat.busy;
    chat.addListener(_check);
  }

  final ChatState chat;

  Future<MarksBase>? _found;
  late (String, String, int) _key;
  late bool _wasBusy;

  (String, String, int) _keyNow() =>
      (chat.folder, chat.worktree?.base ?? '', chat.commits);

  /// Forgets the base when it may have moved, and tells its listeners.
  /// Run from the chat's own listener and again before each answer, so
  /// whoever asks first gets the new base.
  void _check() {
    final ended = _wasBusy && !chat.busy;
    _wasBusy = chat.busy;
    final key = _keyNow();
    if (ended || key != _key) {
      _key = key;
      _found = null;
      notifyListeners();
    }
  }

  /// The base, as last found or found now. A lookup that fails throws
  /// (the marks say they couldn't compare, ADR 0131) and is forgotten, so
  /// the next ask looks again; a newer lookup already under way stays.
  Future<MarksBase> find(Daemon daemon) {
    _check();
    if (_found case final found?) return found;
    final finding = _found = _find(daemon);
    unawaited(
      finding.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_found, finding)) _found = null;
        },
      ),
    );
    return finding;
  }

  /// The branch the Branch view counts from, or on that branch itself
  /// from before the chat's commits ([_chatStart]).
  Future<MarksBase> _find(Daemon daemon) async {
    final b = await ChangeSpan.branchBase(daemon, chat);
    if (!b.status.git) return lastCommitBase;
    final span = ChangeSpan(chat.folder, Scope.branch, b.base, b.status);
    if (!span.onBase) return (base: b.base, from: MarksFrom.branch);
    return await _chatStart(daemon);
  }

  /// On the branch it counts from (the default branch): from the parent
  /// of the oldest of the branch's latest commits (ListCommits' last 50)
  /// made since the chat began, so the chat's own commits stay marked;
  /// with none, the last commit. A commit of the user's made meanwhile on
  /// that branch counts too: the daemon doesn't know whose a commit is.
  Future<MarksBase> _chatStart(Daemon daemon) async {
    final r = await daemon.client.listCommits(
      ListCommitsRequest(folder: chat.folder),
    );
    final began = chat.created.millisecondsSinceEpoch ~/ 1000;
    final own = r.commits.takeWhile((c) => c.unixSeconds.toInt() >= began);
    if (own.isEmpty) return lastCommitBase;
    return (base: '${own.last.hash}^', from: MarksFrom.chat);
  }
}

final _bases = Expando<ChatMarksBase>();

/// [chat]'s one [ChatMarksBase].
ChatMarksBase marksBaseOf(ChatState chat) =>
    _bases[chat] ??= ChatMarksBase._(chat);
