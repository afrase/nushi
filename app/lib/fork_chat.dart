import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
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
    !d.sides.containsKey(chat.id); // a side chat is kept instead

/// Whether [chat] can be forked at [item], one of the agent's messages, as
/// the daemon says; not the newest one while it's still coming ([live]).
bool canForkAt(Daemon d, ChatState chat, Item item, {required bool live}) =>
    canForkChat(d, chat) && chat.canRewind && item.forkable && !live;

/// Forks [chat] into a new chat, all of it or up to [at], and shows the
/// new chat (the phone shows it on a screen of its own: not [select]).
/// Returns it; null when the daemon refused, which was shown.
Future<ChatState?> forkChat(
  BuildContext context,
  Daemon d,
  ChatState chat, {
  Item? at,
  bool select = true,
}) async {
  ChatState? fork;
  await tryOrShow(context, () async {
    final r = await d.client.forkAsChat(
      ForkAsChatRequest(chatId: chat.id, itemId: at?.id),
    );
    fork = d.chats[r.chatId] ??= ChatState(r.chatId, chat.folder);
    if (select) d.select(r.chatId);
  });
  return fork;
}

/// Whether [side], a side chat, can be kept as a chat now: between turns.
bool canKeepSide(Daemon d, ChatState side) =>
    d.daemonApi >= forkApi && !side.busy && !side.waiting;

/// Keep as chat: [chat]'s side chat becomes a chat of its own in the
/// sidebar. The side pane closes and [chat] stays shown; a toast says so,
/// with Go to chat.
Future<void> keepSide(BuildContext context, Daemon d, ChatState chat) async {
  final side = chat.side.value;
  if (side == null) return;
  final toast = ScaffoldMessenger.maybeOf(context);
  await tryOrShow(context, () async {
    final r = await d.client.keepSideChat(KeepSideChatRequest(chatId: side.id));
    if (chat.side.value == side) chat.side.value = null;
    d.sides.remove(side.id);
    d.chats[r.chatId] ??= ChatState(r.chatId, chat.folder);
    d.listChanged();
    toast
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('The side chat is now a chat in the sidebar'),
          action: SnackBarAction(
            label: 'Go to chat',
            onPressed: () => d.select(r.chatId),
          ),
        ),
      );
  });
}

/// One of the agent's messages with "Fork from here" on hover (top right),
/// when [onFork] is set. Only on hover: a right-click on a message is the
/// selection's (Copy).
class ForkTarget extends StatelessWidget {
  const new({required this.child, super.key, this.onFork});

  final Widget child;
  final VoidCallback? onFork;

  @override
  Widget build(BuildContext context) {
    final run = onFork;
    if (run == null) return child;
    return Hover(
      builder: (context, {required hover}) => Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (hover)
            Positioned(
              top: 0,
              right: 0,
              child: IconTap(
                Icons.call_split,
                size: 15,
                color: NushiTheme.of(context).t.textMuted,
                tooltip: 'Fork from here: a new chat up to this message',
                onTap: run,
              ),
            ),
        ],
      ),
    );
  }
}
