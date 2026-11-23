import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/fork_toast.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

// Forks (ADR 0067): a new chat from a chat's conversation, all of it (Fork
// chat, in the chat's menus and the palette) or up to one of the agent's
// messages (Fork from here, on the message), going on separately; and a
// side chat kept as such a chat (Keep as chat, in its header).

/// The API from which the daemon forks a chat into a new one and keeps
/// side chats (ForkAsChat, KeepSideChat, Item.forkable).
const forkApi = 94;

/// Whether [chat] can be forked into a new chat now: its agent can fork it.
bool canForkChat(Daemon d, ChatState? chat) =>
    chat != null &&
    d.daemonApi >= forkApi &&
    chat.canFork &&
    !chat.archived &&
    !chat.sessionGone &&
    d.sideOf(chat.id) == null; // a side chat is kept instead

/// Whether [chat] can be forked at [item], one of the agent's messages, as
/// the daemon says; not the newest one while it's still coming ([live]).
bool canForkAt(Daemon d, ChatState chat, Item item, {required bool live}) =>
    canForkChat(d, chat) && chat.canRewind && item.forkable && !live;

/// Forks [chat] into a new chat, all of it or up to [at], and shows the
/// new chat (the phone shows it on a screen of its own: not [select]).
/// A toast says so, with Undo (fork_toast.dart), whose [back] takes the
/// user back to [chat] (by default, selecting it). Returns the fork; null
/// when the daemon refused, which was shown.
Future<ChatState?> forkChat(
  BuildContext context,
  Daemon d,
  ChatState chat, {
  Item? at,
  bool select = true,
  VoidCallback? back,
}) async {
  ChatState? fork;
  final toasts = Toasts.maybeOf(context);
  // The new chat shows once it's made; a fork can take a moment.
  await runAndSay(context, running: 'Forking ${chat.shownTitle}…', () async {
    final r = await d.client.forkAsChat(
      ForkAsChatRequest(chatId: chat.id, itemId: at?.id),
    );
    // Until the daemon says so itself: no folder, if the chat has none.
    fork = d.chats[r.chatId] ??= ChatState(r.chatId, chat.folder)
      ..scratch = chat.scratch;
    if (select) d.select(r.chatId);
  });
  if (fork case final fork?) {
    showForked(
      toasts,
      d,
      fork,
      back:
          back ??
          () {
            if (d.chats.containsKey(chat.id)) d.select(chat.id);
          },
    );
  }
  return fork;
}

/// Whether [side], a side chat, can be kept as a chat now: between turns.
bool canKeepSide(Daemon d, ChatState side) =>
    d.daemonApi >= forkApi && !side.busy && !side.waiting;

/// Keep as chat: [chat]'s side chat becomes a chat of its own in the
/// sidebar, with what was written in its box. The side pane closes and
/// [chat] stays shown; a toast says so, with Go to chat.
Future<void> keepSide(BuildContext context, Daemon d, ChatState chat) async {
  final side = chat.side.value;
  if (side == null) return;
  final toast = Toasts.maybeOf(context);
  await tryOrShow(context, () async {
    final r = await d.client.keepSideChat(KeepSideChatRequest(chatId: side.id));
    if (chat.side.value == side) chat.side.value = null;
    final kept = d.chats[r.chatId] ??= ChatState(r.chatId, chat.folder)
      ..scratch = chat.scratch;
    // What was half written in the side box goes on in the kept chat's,
    // followed (and kept on disk) as its draft.
    d.drafts?.attach(kept);
    if (kept.draft.isEmpty) kept.draft.takeFrom(side.draft);
    d.listChanged();
    showToast(
      toast,
      'The side chat is now a chat in the sidebar',
      action: (label: 'Go to chat', onPressed: () => d.select(r.chatId)),
      replace: true,
    );
  });
}
