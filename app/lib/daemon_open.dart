part of 'daemon.dart';

/// The chat that's open: picking it, and loading, reloading and letting go
/// of chats' items.
extension DaemonOpen on Daemon {
  /// Fetches a chat's snapshot; its events have been held since `loading`.
  Future<void> _load(ChatState chat, [int tries = 0]) async {
    if (chat.loaded || chat.loading) return;
    chat
      ..loading = true
      ..stale = () => _reload(chat);
    try {
      // The phone takes the recent part first, older pages on scrolling
      // up: a long chat opens fast on a slow link.
      chat.load(
        await client.getChat(
          // From API 71, whose events say where each item is.
          GetChatRequest(
            chatId: chat.id,
            recent: remote && daemonApi >= 71 ? Daemon.recentItems : 0,
          ),
        ),
      );
    } on Object catch (e) {
      chat.unload();
      if (remote) {
        // The phone: no raw error, but tries again (and again once the link
        // is back); details show why.
        chat.loadError = errorText(e);
        _retryLoad(chat, tries);
      } else {
        chat.error = errorText(e);
      }
      _changed();
    }
  }

  /// Takes a fresh snapshot of [chat] (an event reached past what the phone
  /// has of it).
  void _reload(ChatState chat) {
    if (!chat.loaded) return;
    chat.unload();
    unawaited(_load(chat));
  }

  /// Tries a failed load again while the chat shows and the daemon
  /// answers: 2 s, then twice as long each time, up to 30 s.
  void _retryLoad(ChatState chat, [int tries = 0]) {
    final wait = Duration(seconds: [2, 4, 8, 16, 30][min(tries, 4)]);
    _loadRetry?.cancel();
    _loadRetry = Timer(wait, () {
      if (chat.loaded || chat.id != selectedId || !chats.containsKey(chat.id)) {
        return;
      }
      if (!connected) return _retryLoad(chat, tries + 1); // relinking
      unawaited(_load(chat, tries + 1)); // which comes back here if it fails
    });
  }

  void select(String chatId) {
    _leaveTrust();
    selectedId = chatId;
    chatOpened.value = {
      ...chatOpened.value,
      chatId: DateTime.now().millisecondsSinceEpoch,
    };
    place = const ChatPlace();
    final chat = chats[chatId];
    if (chat != null) unawaited(_load(chat));
    _letGo();
    shown();
    _changed();
  }

  /// Lets the items of loaded chats not among the last [Daemon.keptChats]
  /// picked go; each loads again when opened.
  void _letGo() {
    if (selectedId case final id?) {
      _picked
        ..remove(id)
        ..add(id);
    }
    if (_picked.length > Daemon.keptChats) _picked.removeAt(0);
    for (final c in chats.values) {
      if (c.loaded && !_picked.contains(c.id)) c.letGo();
    }
  }

  /// The selected chat is shown: picked, or the app came to the front. A
  /// chat whose agent should run but doesn't reopens, and one whose reopen
  /// failed tries again, once a show (the daemon's ReopenChat). A sleeping
  /// one stays asleep.
  void shown() {
    if (selected case final chat? when !chat.archived) reopen(chat);
  }

  /// ReopenChat for [chat] (Try again); how it goes shows in the chat.
  void reopen(ChatState chat) =>
      client.reopenChat(ReopenChatRequest(chatId: chat.id)).ignore();
}
