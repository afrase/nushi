part of 'daemon.dart';

/// What the daemon says keeping [Daemon.chats] current: its events, and the
/// list of chats they bring up to date.
extension DaemonEvents on Daemon {
  /// Says the app has shown [removedChats]: the daemon forgets them.
  void dismissRemoved() {
    final ids = [for (final r in removedChats) r.id];
    removedChats = [];
    _changed();
    client.dismissRemovedChats(DismissRemovedChatsRequest(ids: ids)).ignore();
  }

  /// Subscribes to the daemon's events. The subscription's first message
  /// starts its own list of the chats; what comes while that list is on
  /// its way is held for it, as this subscription's alone, so a list from
  /// a subscription since dropped ([_listChats]) can't let another's
  /// events through early.
  void _subscribe() {
    var live = false;
    List<EventsResponse>? held;
    late final StreamSubscription<EventsResponse> sub;
    sub = _events = client
        .events(EventsRequest(imageRefs: true))
        .listen(
          (e) {
            if (!live) {
              // The first message says the subscription is live: now the
              // list can't miss a chat.
              live = true;
              held = [];
              unawaited(
                _listChats(sub, () {
                  final events = held ?? [];
                  held = null;
                  // A dropped subscription's events go with it: the next
                  // one's list covers them.
                  if (identical(_events, sub)) events.forEach(_handle);
                }),
              );
              unawaited(_listAgents());
              unawaited(
                client
                    .getRemote(GetRemoteRequest())
                    .then((r) => remoteState.value = r.remote, onError: (_) {}),
              );
              return;
            }
            if (held case final h?) {
              h.add(e); // applied after the list, which may be older
            } else {
              _handle(e);
            }
          },
          onError: (_) => _dropped(sub),
          onDone: () => _dropped(sub),
        );
  }

  /// The daemon ended [sub]: the next ping subscribes again, unless a
  /// newer subscription has already taken its place.
  void _dropped(StreamSubscription<EventsResponse> sub) {
    if (identical(_events, sub)) _events = null;
  }

  void _handle(EventsResponse e) {
    onEvent?.call(e);
    if (e.hasRemote()) {
      remoteState.value = e.remote;
    } else if (e.hasUpdate()) {
      if (!remote) _sawUpdate(e.update);
    } else if (e.hasRemovedChats()) {
      removedChats = e.removedChats.chats;
      _changed();
    } else if (e.hasTerminals()) {
      terminals.apply(e.chatId, e.terminals.terminals);
    } else if (e.hasRelatedWorktrees()) {
      // Unnumbered, so not for ChatState.apply, and only the Mac shows them.
      if (!remote) chats[e.chatId]?.related.take(e.relatedWorktrees.worktrees);
    } else if (e.hasServersChanged()) {
      if (!remote) devServers.changed(e.serversChanged);
    } else if (e.hasShow()) {
      // The phone offers Preview on the tool row; it opens nothing itself.
      if (!remote) chats[e.chatId]?.showAsked.value = ShowFile(e.show);
    } else if (e.hasShowUrl()) {
      // A page on the Mac's loopback (ADR 0100): nothing the phone opens.
      if (!remote) chats[e.chatId]?.showAsked.value = ShowPage(e.showUrl);
    } else if (sides[e.chatId] case final side?) {
      e.removed ? _sideGone(side) : _applySide(side, e);
    } else if (e.hasChat()) {
      _chat(e.chat);
      _changed();
    } else if (e.removed) {
      _forget({e.chatId});
      _changed();
    } else if (chats[e.chatId] case final chat?) {
      final failed = chat.reopenFailed;
      chat.apply(e);
      // Its agent became ready (not a reopen starting): shown, it reopens.
      if (failed && !chat.reopenFailed && !chat.busy && chat.id == selectedId) {
        shown();
      }
    }
  }

  /// Lists the chats for the subscription [sub], then [release]s the events
  /// it held meanwhile, in order: the list was read at some point while
  /// they came, so they bring it up to date (a chat started meanwhile
  /// included). What's forgotten is what was kept before the list was
  /// asked for: a chat added while it was on its way (by an event, or by
  /// StartChat's answer) wasn't in it to be read. A list that answers once
  /// [sub] is no longer the subscription does nothing: the newer one lists
  /// again. When listing fails, the subscription starts again, and with
  /// it the list.
  Future<void> _listChats(
    StreamSubscription<EventsResponse> sub,
    VoidCallback release,
  ) async {
    for (final c in [...chats.values, ...sides.values]) {
      c.unload(); // events may have been missed while disconnected
    }
    terminals.stale();
    devServers.reload(); // its events may have been missed too
    // What's kept for chats deleted while the app was away: the stores
    // keep the chats of the app's whole life.
    final kept = {
      ...chats.keys,
      if (!remote) ...[
        ...chatsKept(),
        ...reviews.value.keys,
        ...rememberedContexts,
      ],
      ...?drafts?.ids,
    };
    try {
      final resp = await client.listChats(ListChatsRequest());
      if (!identical(_events, sub)) return;
      removedChats = resp.removed;
      final listed = resp.chats..forEach(_chat);
      // Chats deleted meanwhile go; side chats the daemon lost (it
      // restarted) end, the others catch up. A chat whose record the
      // daemon couldn't read isn't gone: what's kept for it stays (API
      // 144; an older daemon names none).
      final ids = {for (final c in listed) c.id, ...resp.unreadable};
      _forget(kept.difference(ids).difference(sides.keys.toSet()));
      // An unreadable chat already listed (its record stopped reading
      // across a restart) leaves the list: the daemon has no such chat.
      for (final id in resp.unreadable) {
        if (!listed.any((c) => c.id == id)) chats.remove(id);
      }
      for (final side in sides.values) {
        side.loading = true; // its events wait for its snapshot
      }
      chatsListed = true;
    } on Object {
      // The next ping subscribes again; a newer subscription stays.
      if (identical(_events, sub)) _unsubscribe();
      return;
    } finally {
      release();
    }
    if (!identical(_events, sub)) return;
    if (!chats.containsKey(selectedId)) selectedId = null;
    for (final chat in [...chats.values]) {
      if (chat.side.value case final side?) {
        try {
          side.load(
            await client.getChat(
              GetChatRequest(chatId: side.id, imageRefs: true),
            ),
          );
        } on Object {
          if (!identical(_events, sub)) return;
          chat.side.value = null;
          sides.remove(side.id);
        }
      }
    }
    if (selected != null) unawaited(_load(selected!));
    _changed();
  }

  /// Forgets the chats [ids], gone (deleted here, or while the app was
  /// away), and everything kept for them: the prefs kept by chat (their
  /// Changes scope, terminals panel, place in their project's order, when
  /// opened, pins, pull request's comments seen and Clean up's Not now),
  /// review comments, context breakdown, terminals and draft. (A pin goes
  /// with its chat: the daemon's.)
  void _forget(Set<String> ids) {
    for (final id in ids) {
      chats.remove(id);
      drafts?.forget(id);
      if (commentsOf(id).isNotEmpty) setComments(id, []);
      if (!remote) forgetContext(id);
      terminals.forget(id);
    }
    forgetChats(ids);
    if (ids.contains(selectedId)) selectedId = null;
  }

  Future<void> _listAgents() async {
    try {
      await listAgents(client);
      _changed();
    } on Object {
      // As they were: the next subscription asks again.
    }
  }

  ChatState _chat(Chat c) {
    final chat = chats[c.id] ??= ChatState(c.id, c.folder);
    if (chat.archived && !c.archived) {
      // Unarchived: the daemon replays it from scratch.
      chat.unload();
      if (chat.id == selectedId) unawaited(_load(chat));
    }
    if (chat.folder != c.folder) {
      chat.moved(c.folder);
      closeSide(chat); // it ran on the old agent
    }
    if (!remote) keepFileTabs(this, chat);
    // An archived chat's draft goes; one unarchived is followed again.
    if (c.archived) {
      drafts?.forget(c.id);
    } else {
      drafts?.attach(chat);
    }
    chat
      ..worktree = c.hasWorktree() ? c.worktree : null
      ..agent = c.agent
      ..scratch = c.scratch
      ..jiraSite = c.jiraSite
      ..jiraKey = c.jiraKey
      ..github = c.hasGithub() ? c.github : null
      ..pull = c.hasPull()
          ? c.pull
          : c.github.pull
          ? c.github
          : null
      ..pulls = c.pulls.isNotEmpty
          ? c.pulls
          : [if (c.hasPull()) c.pull else if (c.github.pull) c.github]
      ..title = c.title
      ..archived = c.archived
      ..archivedAt = c.archivedUnixMs == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(c.archivedUnixMs.toInt())
      ..done = daemonApi >= doneApi ? c.done : null
      ..pin = c.pin
      ..color = ChatColor.named(c.color)
      ..pinnedMessages = c.pinnedMessages
      ..pinTitles = {for (final p in c.messagePins) p.itemId: p.title}
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      ..updated = DateTime.fromMillisecondsSinceEpoch(
        (c.updatedUnixMs == 0 ? c.createdUnixMs : c.updatedUnixMs).toInt(),
      )
      // Only the list carries a status; a chat event would clear it.
      ..listed(c.hasStatus() ? c.status : null);
    // The sidebar (not the phone's list) keeps its folder as a project,
    // with chats or none ([sidebarProjects]); archived, it brings none
    // back.
    if (!remote && !chat.archived && !chat.scratch) keepProject(chat.home);
    return chat;
  }
}
