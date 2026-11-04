part of 'daemon.dart';

/// A long chat's pages: it opens with its recent part (GetChatRequest.recent)
/// and takes the pages before it (GetChatItems) as the transcript scrolls
/// up, or as something goes to a message not taken yet (ADR 0026).
extension DaemonPages on Daemon {
  /// How many items a chat opens with, and a page brings.
  int get pageItems => remote ? Daemon.recentItems : Daemon.macRecentItems;

  /// Whether a snapshot can be the recent part: from API 71, whose events
  /// say where each item is.
  bool get pages => daemonApi >= 71;

  /// Takes the page of [chat]'s items before those it has (nothing when it
  /// has them all, or a page is on its way). Given [through], it goes on
  /// page by page until it has all those messages, given [until] until a
  /// page has one it holds, or with [all] to the chat's start, and puts
  /// them in at once, after any page on its way. A failed page sets
  /// [ChatState.olderFailed] until the next try.
  Future<void> loadOlder(
    ChatState chat, {
    Iterable<String> through = const [],
    bool Function(Item)? until,
    bool all = false,
  }) async {
    final more = all || through.isNotEmpty || until != null;
    // One at a time: after any on its way, and any that waited for it.
    for (var on = chat.olderLoad; on != null; on = chat.olderLoad) {
      if (!more) return;
      await on;
    }
    if (chat.older == 0 || chat.items.isEmpty || !chat.loaded) return;
    final have = {for (final it in chat.items) it.id};
    final want = {...through}..removeAll(have);
    if (!all && through.isNotEmpty && want.isEmpty) return;
    if (until != null && chat.items.any(until)) return;
    final done = Completer<void>();
    chat.olderGoing(done.future);
    final before = chat.items.first.id;
    final snapshot = chat.snapshots;
    final page = <Item>[];
    var failed = false;
    try {
      var first = before;
      var older = chat.older;
      while (true) {
        final got = await client.getChatItems(
          GetChatItemsRequest(
            chatId: chat.id,
            before: first,
            // Going to a message: as much as the daemon gives at once.
            limit: more ? 500 : pageItems,
          ),
        );
        page.insertAll(0, got.items);
        older = got.older;
        want.removeAll(got.items.map((it) => it.id));
        if (got.items.isEmpty || older == 0) break;
        if (!all && (until != null ? got.items.any(until) : want.isEmpty)) {
          break;
        }
        first = got.items.first.id;
      }
      // Only onto what it was asked for: a reload meanwhile (a reconnect,
      // a rewind) took another snapshot.
      if (chat.loaded &&
          chat.snapshots == snapshot &&
          chat.items.isNotEmpty &&
          chat.items.first.id == before) {
        chat.prepend(page, older);
      }
    } on Object {
      // The phone asks again on its next scroll up; the Mac says so at the
      // transcript's top, with Try again.
      failed = true;
    } finally {
      chat.olderDone(failed: failed);
      done.complete();
    }
  }

  /// [chat] was left at its bottom: back to its recent part, the rest let
  /// go until it's scrolled up to again. After this frame: the transcript
  /// that left it is being built.
  void leftAtBottom(ChatState chat) {
    if (!pages) return;
    scheduleMicrotask(() {
      if (chat.kept == null) chat.trim(pageItems);
    });
  }
}
