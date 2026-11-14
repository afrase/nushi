import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';

/// What a list of chats shows of [chat] (the sidebar's row and its menu,
/// the phone's row, a collapsed group's dot, the sidebar's grouping and
/// sort, the status bar's counts): its state, title, pin, color, times,
/// folder, branch and links, and what its menu offers. It tells its
/// listeners only when one of those changes, never as text streams into
/// the transcript, which notifies the chat at every chunk; what lists the
/// chat listens to this rather than to the chat.
class ChatLook extends ChangeNotifier {
  new(this.chat) : _was = _of(chat) {
    chat.addListener(_changed);
  }

  final ChatState chat;
  Object _was;

  /// Everything a list shows of the chat, as one comparable value.
  static Object _of(ChatState c) => (
    c.phase,
    c.asleep,
    c.started != null,
    c.title,
    c.pin,
    c.color,
    c.archived,
    c.created,
    c.updated,
    c.agent,
    c.folder,
    c.scratch,
    c.worktree?.branch,
    c.jiraKey,
    c.pull,
    Object.hashAll(c.pulls),
    // What the row's menu offers.
    (c.canFork, c.canSleep, c.canRewind, c.stopping, c.background),
  );

  void _changed() {
    final now = _of(chat);
    if (now == _was) return;
    _was = now;
    notifyListeners();
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    super.dispose();
  }
}
