import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Pinned messages (ADR 0085): a message's pin marks it, and the chip over
// the transcript's top left lists them. The daemon keeps a chat's
// (PinMessage), so the phone and another Mac show the same; a pin shows at
// once and goes back if the daemon refuses.

/// Whether [item] is a message a pin can mark: the user's or the agent's
/// own, not a subagent's.
bool _pinnable(Item item) =>
    item.parent.isEmpty &&
    (item.kind == ItemKind.ITEM_KIND_USER_MESSAGE ||
        item.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE);

/// Whether [item] can be pinned or unpinned in [chat]: one of its messages
/// the daemon shows (not one on its way), on a daemon that keeps pins. Not
/// in a side chat, which isn't one of the daemon's chats and keeps none.
bool canPinMessage(Daemon d, ChatState chat, Item item) =>
    d.daemonApi >= messagePinApi &&
    identical(d.chats[chat.id], chat) &&
    _pinnable(item) &&
    !chat.sending.contains(item);

/// [chat]'s pinned messages among its items, in the transcript's order.
List<Item> pinnedItems(ChatState chat) {
  final ids = chat.pinnedMessages.toSet();
  if (ids.isEmpty) return const [];
  return [
    for (final it in chat.items)
      if (ids.contains(it.id) && _pinnable(it)) it,
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
/// page: the phone has only the latest at first.
Future<void> loadPinned(Daemon d, ChatState chat, {bool all = false}) async {
  bool missing() {
    final have = {for (final it in chat.items) it.id};
    return chat.pinnedMessages.any((id) => !have.contains(id));
  }

  while (chat.older > 0 && (all || missing())) {
    final older = chat.older;
    await d.loadOlder(chat);
    if (chat.older == older) return; // it failed, or a page was on its way
  }
}

/// How many pins the chip counts: those among [chat]'s items, or, while
/// it has older pages to take, every one the daemon keeps.
int pinCount(ChatState chat, List<Item> pinned) =>
    chat.older > 0 ? chat.pinnedMessages.length : pinned.length;

/// A message's first line, as a pinned message's row shows it: without
/// the Markdown that opens a heading, a quote or a list's item.
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

/// Pin or Unpin, among a message's actions.
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
      color: pinned ? t.accentInk : t.textMuted,
      tooltip: pinned ? 'Unpin' : 'Pin',
      onTap: onTap,
    );
  }
}

/// A pinned message's mark, there while its actions aren't, in their pin's
/// place.
class PinnedMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Pinned',
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Icon(
        Icons.push_pin,
        size: 15,
        color: NushiTheme.of(context).t.accentInk,
      ),
    ),
  );
}

/// A message just gone to from the pins' list, tinted for a moment while
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

/// The band behind the pins' chip where it stands over the text: the page's
/// color down to just under the chip, then fading out over its last [fade],
/// so a line scrolling under it goes rather than showing half-hidden beside
/// the chip.
class PinsBackdrop extends StatelessWidget {
  const new({super.key});

  /// How tall the band's fading edge is.
  static const fade = 12.0;

  @override
  Widget build(BuildContext context) {
    final base = NushiTheme.of(context).t.base;
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: base)),
          SizedBox(
            height: fade,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [base, base.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chip over the transcript's top left while the chat has pinned
/// messages: a pin and their [count]. It opens their list: "Start of the
/// chat" first, then each of [pinned] in the transcript's order, its first
/// line, who sent it and when, if known. A pick goes there ([onPick] with
/// null for the start). [before] runs first (the phone takes the pages
/// its pins are on).
class PinsChip extends StatelessWidget {
  const new({
    required this.chat,
    required this.pinned,
    required this.count,
    required this.onPick,
    super.key,
    this.before,
  });

  final ChatState chat;
  final List<Item> pinned;
  final int count;
  final void Function(Item? item) onPick;
  final Future<void> Function()? before;

  MenuEntry _row(BuildContext context, Item item) {
    final t = NushiTheme.of(context).t;
    final mine = item.kind == ItemKind.ITEM_KIND_USER_MESSAGE;
    final who = mine ? 'You' : chat.agentName;
    final sent = item.sent.toInt();
    final ago = sent == 0 ? '' : agoAt(sent, clock());
    return MenuEntry(
      firstLine(item),
      mark: mine
          ? Icon(Icons.person_outline, size: 16, color: t.textSecondary)
          : AgentMark(chat.agent, size: 16),
      detail: mine ? [who, if (ago.isNotEmpty) ago].join(' · ') : ago,
      tooltip: sent == 0
          ? who
          : '$who, ${fullTime(DateTime.fromMillisecondsSinceEpoch(sent))}',
      onPick: () => onPick(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Menu(
      filter: false,
      entries: [
        MenuEntry(
          'Start of the chat',
          icon: Icons.vertical_align_top,
          autofocus: true,
          onPick: () => onPick(null),
        ),
        MenuEntry.divider,
        for (final it in pinned) _row(context, it),
      ],
      builder: (context, open) => Pressable(
        tooltip: count == 1 ? '1 pinned message' : '$count pinned messages',
        onTap: () async {
          await before?.call();
          if (context.mounted) open();
        },
        builder: (context, look) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
            color: look.hover ? Color.alphaBlend(t.hover, t.raised) : t.raised,
            shape: StadiumBorder(
              side: BorderSide(
                color: look.focus ? t.focus : t.borderStrong,
                width: look.focus ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Icon(Icons.push_pin, size: 13, color: t.accentInk),
              Text('$count', style: theme.ui(t.text, size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
