import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_changes.dart';
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
/// once its folder may have changed ([ChatChanges.baseMoved]: the chat's
/// turn ended, it committed, or its folder or worktree changed; not a scope
/// picked in Changes). One lookup for
/// every file shown and the tree, from the span its details and Changes
/// show, and one notice to each of them (a file's `LineBase`, the tree's
/// `TreeDots`) when it may have moved, to ask again.
final class ChatMarksBase extends ChangeNotifier {
  new _(this.chat);

  final ChatState chat;

  Future<MarksBase>? _found;

  /// The chat's changes, once a base was first asked for: what tells it
  /// the base may have moved.
  ChatChanges? _changes;

  /// Forgets the base, and tells its listeners to ask again.
  void _moved() {
    _found = null;
    notifyListeners();
  }

  /// The base, as last found or found now. A lookup that fails throws
  /// (the marks say they couldn't compare, ADR 0131) and is forgotten, so
  /// the next ask looks again; a newer lookup already under way stays.
  Future<MarksBase> find(Daemon daemon) {
    _changes ??= ChatChanges.of(daemon, chat)..baseMoved.addListener(_moved);
    if (_found case final found?) return found;
    final finding = _found = _find(daemon, _changes!);
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
  Future<MarksBase> _find(Daemon daemon, ChatChanges changes) async {
    final span = await changes.current();
    if (!span.status.git) return lastCommitBase;
    if (!span.onBase) return (base: span.base, from: MarksFrom.branch);
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
