import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/picker.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/theme/theme.dart';

// Esc Esc in the prompt box, as in Claude Code: a list of your messages to
// rewind the chat to.

/// How soon a second Esc must follow the first.
// design: a double press, as macOS times one
const escEscWithin = Duration(milliseconds: 500);

/// Lists [chat]'s messages that can be rewound to ([RewindPicker]) and
/// rewinds to just before the one picked, without asking again: the list
/// is the confirmation. The message goes back in the box.
Future<void> pickRewind(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  final item = await showDialog<Item>(
    context: context,
    builder: (_) => RewindPicker(chat: chat, daemon: daemon),
  );
  if (item == null || !context.mounted) return;
  await rewindTo(context, daemon, chat, item);
}

/// Your messages in [chat] that it can be rewound to, newest first, then
/// those in [earlier] (items before what it has loaded).
List<Item> rewindChoices(ChatState chat, [List<Item> earlier = const []]) {
  final have = {for (final it in chat.items) it.id};
  return [
    for (final it in [
      ...earlier.where((it) => !have.contains(it.id)),
      ...chat.items,
    ].reversed)
      if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE && canRewindTo(chat, it))
        it,
  ];
}

/// A message in one line: its first line of text (after any replies'
/// quotes), else a reply's, else a command's it carried, else its images.
String rewindLine(Item it) {
  final (body, commands) = splitCommands(it.text);
  final (replies, text) = splitReplies(body);
  for (final t in [
    text,
    for (final r in replies) r.text,
    for (final c in commands)
      if (c.command.isEmpty) 'Output' else '! ${c.command}',
  ]) {
    for (final l in t.split('\n')) {
      if (l.trim().isNotEmpty) return l.trim();
    }
  }
  return switch (it.images.length) {
    0 => it.text.trim(),
    1 => 'An image',
    final n => '$n images',
  };
}

/// The rewind list: a field that filters, your messages under it (one line
/// each and when it was sent), and the warning that files stay as they
/// are. ↑↓ move, ⏎ or a click picks (the dialog pops with the message),
/// Esc closes. While a turn runs it says to stop it first, and lists the
/// messages once it has stopped. Those above a long chat's loaded part
/// come from [daemon] as it lists, into the list only: the transcript
/// would lay them all out (ADR 0026).
class RewindPicker extends StatefulWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<RewindPicker> createState() => _RewindPickerState();
}

class _RewindPickerState extends State<RewindPicker> {
  List<Item> _earlier = const []; // before the chat's loaded items
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }

  /// The items before the chat's loaded ones, a page of as many as the
  /// daemon gives at a time, until the start or the list closes. A page
  /// that fails leaves the list as it is.
  Future<void> _fetch() async {
    final chat = widget.chat;
    var older = chat.older;
    var first = chat.items.firstOrNull?.id;
    try {
      while (older > 0 && first != null) {
        final page = await widget.daemon.client.getChatItems(
          GetChatItemsRequest(
            chatId: chat.id,
            before: first,
            limit: 500,
            imageRefs: true,
          ),
        );
        if (_gone || !mounted || page.items.isEmpty) return;
        setState(() => _earlier = [...page.items, ..._earlier]);
        older = page.older;
        first = page.items.first.id;
      }
    } on Object {
      return;
    }
  }

  /// A message's row: one line, a time's height and padding.
  static const rowHeight = 26.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.chat, // a turn ending lists the messages
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final chat = widget.chat;
      final rows = rewindChoices(chat, _earlier);
      final now = clock();
      return PickBox<Item>(
        rows: rows,
        rank: (rows, query) => [
          for (final it in rows)
            if (matchesWords(it.text, query)) it,
        ],
        hint: 'Rewind to before…',
        icon: Icons.history,
        rowHeight: rowHeight,
        rowPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        status: switch (chat) {
          _ when chat.busy && chat.stopping => 'Stopping the turn…',
          _ when chat.busy => 'Stop the turn first',
          _ when !chat.canRewind || chat.archived =>
            '${chat.agentName} can’t rewind this chat',
          _ when rows.isEmpty => 'No message to rewind to',
          _ => null,
        },
        empty: 'No message matches',
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: Text(
            'Files aren’t rewound: ${chat.agentName}’s changes since '
            'then stay.',
            style: theme.ui(t.textMuted, size: 12),
          ),
        ),
        row: (context, it) {
          final sent = DateTime.fromMillisecondsSinceEpoch(it.sent.toInt());
          return Row(
            children: [
              Expanded(
                child: Text(
                  rewindLine(it),
                  style: theme.ui(t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (it.sent > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    ago(now.difference(sent), sent),
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
