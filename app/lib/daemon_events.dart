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

  void _subscribe() {
    var live = false;
    _events = client
        .events(EventsRequest())
        .listen(
          (e) {
            if (!live) {
              // The first message says the subscription is live: now the
              // list can't miss a chat.
              live = true;
              unawaited(_listChats());
              unawaited(_listAgents());
              unawaited(
                client
                    .getRemote(GetRemoteRequest())
                    .then((r) => remoteState.value = r.remote, onError: (_) {}),
              );
              return;
            }
            if (_held case final held?) {
              held.add(e); // applied after the list, which may be older
            } else {
              _handle(e);
            }
          },
          onError: (_) => _events = null,
          onDone: () => _events = null,
        );
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
    } else if (e.hasShow()) {
      // The phone offers Preview on the tool row; it opens nothing itself.
      if (!remote) chats[e.chatId]?.showAsked.value = e.show;
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

  /// Lists the chats, then applies the events held meanwhile, in order: the
  /// list was read at some point while they came, so they bring it up to
  /// date (a chat started meanwhile included). When listing fails, the
  /// subscription starts again, and with it the list.
  Future<void> _listChats() async {
    _held = [];
    for (final c in [...chats.values, ...sides.values]) {
      c.unload(); // events may have been missed while disconnected
    }
    terminals.stale();
    try {
      final resp = await client.listChats(ListChatsRequest());
      removedChats = resp.removed;
      final listed = resp.chats..forEach(_chat);
      // Chats deleted meanwhile go; side chats the daemon lost (it
      // restarted) end, the others catch up.
      final ids = {for (final c in listed) c.id};
      // And what's kept for chats deleted while the app was away: the
      // stores keep the chats of the app's whole life.
      final kept = {
        ...chats.keys,
        if (!remote) ...[
          ...chatsKept(),
          ...reviews.value.keys,
          ...rememberedContexts,
        ],
        ...?drafts?.ids,
      };
      _forget(kept.difference(ids).difference(sides.keys.toSet()));
      for (final side in sides.values) {
        side.loading = true; // its events wait for its snapshot
      }
      chatsListed = true;
    } on Object {
      unawaited(_events?.cancel());
      _events = null; // the next ping subscribes again
      return;
    } finally {
      final held = _held ?? [];
      _held = null;
      held.forEach(_handle);
    }
    if (!chats.containsKey(selectedId)) selectedId = null;
    for (final chat in [...chats.values]) {
      if (chat.side.value case final side?) {
        try {
          side.load(await client.getChat(GetChatRequest(chatId: side.id)));
        } on Object {
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
    // An archived chat's draft goes; one unarchived is followed again.
    if (c.archived) {
      drafts?.forget(c.id);
    } else {
      drafts?.attach(chat);
    }
    return chat
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
      ..title = c.title
      ..archived = c.archived
      ..done = daemonApi >= doneApi ? c.done : null
      ..pin = c.pin
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      // Only the list carries a status; a chat event would clear it.
      ..listed(c.hasStatus() ? c.status : null);
  }
}
