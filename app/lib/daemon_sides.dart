part of 'daemon.dart';

/// Side chats: forks of a chat, opened beside it and never listed.
extension DaemonSides on Daemon {
  /// Opens [chat]'s side chat (a fork of it, ForkChat; one at a time),
  /// unless it has one or one is on its way.
  Future<void> openSide(ChatState chat) async {
    if (chat.side.value != null || chat.forking.value) return;
    chat.forking.value = true;
    try {
      final resp = await client.forkChat(ForkChatRequest(chatId: chat.id));
      final side = sides[resp.chatId] = ChatState(resp.chatId, chat.folder)
        ..agent = chat.agent;
      unawaited(_load(side));
      chat.sideHidden.value = false;
      chat.side.value = side;
    } finally {
      chat.forking.value = false;
    }
  }

  /// Ends [chat]'s side chat, if it has one.
  void closeSide(ChatState chat) {
    final side = chat.side.value;
    if (side == null) return;
    chat.side.value = null;
    sides.remove(side.id);
    client.closeSideChat(CloseSideChatRequest(chatId: side.id)).ignore();
  }

  /// Applies [e] to [side]; a turn that ends while it's hidden is unseen
  /// (its chip's dot) until it shows again.
  void _applySide(ChatState side, EventsResponse e) {
    final was = side.busy;
    side.apply(e);
    if (was &&
        !side.busy &&
        chats.values.any((c) => c.side.value == side && c.sideHidden.value)) {
      side.done = true;
    }
  }

  /// A side chat the daemon ended (its chat reloaded, moved or archived,
  /// or its agent quit).
  void _sideGone(ChatState side) {
    sides.remove(side.id);
    for (final chat in chats.values) {
      if (chat.side.value == side) chat.side.value = null;
    }
    _changed();
  }
}
