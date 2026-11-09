import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Pinned messages (ADR 0085): the agent's messages, pinned from their
// actions row, and listed by the rail at the transcript's top left
// (rail.dart). The daemon keeps a chat's (PinMessage) with their titles,
// so the phone and another Mac show the same; a pin shows at once and goes
// back if the daemon refuses.

/// Whether [item] is a message a pin can mark: the agent's own, not a
/// subagent's, a tool call, a card or the user's.
bool _pinnable(Item item) =>
    item.parent.isEmpty && item.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE;

/// Whether [item] can be pinned or unpinned in [chat]: one of the agent's
/// messages the daemon shows, on a daemon that keeps pins, and not the one
/// still being written ([live]), whose title would be made from its first
/// words. Not in a side chat, which isn't one of the daemon's chats and
/// keeps none.
bool canPinMessage(Daemon d, ChatState chat, Item item, {required bool live}) =>
    d.daemonApi >= messagePinApi &&
    identical(d.chats[chat.id], chat) &&
    _pinnable(item) &&
    !live &&
    !chat.outbox.sending.contains(item);

/// The session's start, the pins rail's first entry.
const sessionStart = RailEntry('', 'Session start');

/// The first daemon that sends each pin's title with its chat
/// (`Chat.message_pins`). Against an older one the phone takes the pages
/// its pins are on before the rail's menu opens, to list them by their
/// first lines; against this one the menu opens at once, and a pick takes
/// the page it goes to.
const pinTitlesApi = 104;

/// [chat]'s pins as the rail lists them, in the transcript's order: those
/// on pages not loaded yet first (which are older), then those
/// among its items. A pin whose message is gone isn't listed.
List<RailEntry> pinEntries(ChatState chat) {
  final ids = chat.pinnedMessages.toSet();
  if (ids.isEmpty) return const [];
  final shown = [
    for (final it in chat.items)
      if (ids.contains(it.id) && _pinnable(it)) it,
  ];
  final have = {for (final it in chat.items) it.id};
  return [
    if (chat.older > 0)
      for (final id in chat.pinnedMessages)
        if (!have.contains(id))
          RailEntry(id, chat.pinTitles[id] ?? 'Pinned message'),
    for (final it in shown)
      RailEntry(it.id, switch (chat.pinTitles[it.id]) {
        final t? when t.isNotEmpty => t,
        _ => firstLine(it),
      }),
  ];
}

/// Pins [item], or unpins it if it's pinned.
Future<void> toggleMessagePin(Daemon d, ChatState chat, Item item) async {
  final before = chat.pinnedMessages;
  final pin = !before.contains(item.id);
  chat.pinnedMessages = pin
      ? [...before, item.id]
      : [
          for (final id in before)
            if (id != item.id) id,
        ];
  try {
    await d.client.pinMessage(
      PinMessageRequest(chatId: chat.id, itemId: item.id, pinned: pin),
    );
  } on Object {
    chat.pinnedMessages = before;
    rethrow;
  }
}

/// Takes the pages of [chat]'s items its pins are on, or with [all] every
/// page: the phone's rail has them laid out before its menu opens.
Future<void> loadPinned(Daemon d, ChatState chat, {bool all = false}) =>
    d.loadOlder(chat, through: chat.pinnedMessages, all: all);

/// A message's first line, as a pin without a title (an older daemon's)
/// is listed: without the Markdown that opens a heading, a quote or a
/// list's item.
String firstLine(Item item) {
  final line = item.text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  final plain = line
      .replaceFirst(RegExp(r'^(#{1,6}\s+|>\s*|[-*+]\s+|\d+[.)]\s+)'), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '');
  if (plain.isNotEmpty) return plain;
  return item.images.isNotEmpty ? 'Image' : 'Message';
}

/// Pin or Unpin, among an agent message's actions: held down, its pin
/// filled, while the message is pinned (as Claude's desktop app has it).
class PinAction extends StatelessWidget {
  const new({required this.pinned, required this.onTap, super.key});

  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return IconTap(
      pinned ? Icons.push_pin : Icons.push_pin_outlined,
      size: 15,
      color: pinned ? t.text : t.textMuted,
      held: pinned,
      tooltip: pinned ? 'Unpin' : 'Pin',
      onTap: onTap,
    );
  }
}

/// A message just gone to from the pins' menu, tinted for a moment while
/// [on]; with Reduce Motion the tint comes and goes at once.
class PinFlash extends StatelessWidget {
  const new({required this.on, required this.child, super.key});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: reduceMotion(context) ? Duration.zero : Motion.standard,
    decoration: BoxDecoration(
      color: on
          ? NushiTheme.of(context).t.accentSoft
          : NushiTheme.of(context).t.accentSoft.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}
