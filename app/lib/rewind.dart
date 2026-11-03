import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/widgets.dart';

/// Whether the chat can be rewound to just before [item], a user message,
/// as the daemon says.
bool canRewindTo(ChatState chat, Item item) =>
    chat.canRewind && !chat.busy && !chat.archived && item.rewindable;

/// The longest the composer stays locked: past the minute the daemon gives
/// a rewind. A Stop that takes a message back has no limit of its own (an
/// agent can ignore the cancel), and a wedged agent mustn't take the box
/// with it; a message that comes after this goes after what was typed.
const rewindLockLimit = Duration(seconds: 90);

/// Runs [wait], for a message coming back to the box, with [chat]'s
/// composer locked ([ChatState.rewinding]); however it ends, the box opens.
Future<void> whileRewinding(
  ChatState chat,
  Future<void> Function() wait,
) async {
  chat.rewinding.value = true;
  final limit = Timer(rewindLockLimit, () => chat.rewinding.value = false);
  try {
    await wait();
  } finally {
    limit.cancel();
    chat.rewinding.value = false;
  }
}

/// Whether a Stop may take [chat]'s last message back: the agent hasn't
/// answered it with text or a tool call, as the daemon's Stop reads it.
bool unanswered(ChatState chat) {
  for (final it in chat.items.reversed) {
    if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return true;
    if (it.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE ||
        it.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
      return false;
    }
  }
  return false;
}

/// Asks, then cuts the chat back to just before [item] and puts the message
/// in the composer to edit.
Future<void> rewind(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  Item item,
) async {
  if (!await confirm(
        context,
        'Rewind to here?',
        '${chat.agentName} forgets everything from this message on; the '
            'message goes back in the box.\n\nFiles aren’t rewound: '
            '${chat.agentName}’s changes since then stay.',
        'Rewind',
      ) ||
      !context.mounted) {
    return;
  }
  await rewindTo(context, daemon, chat, item);
}

/// Cuts the chat back to just before [item], without asking, and puts the
/// message in the composer to edit. One at a time: the box stays locked
/// for the first.
Future<void> rewindTo(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  Item item,
) async {
  if (chat.rewinding.value) return;
  await tryOrShow(
    context,
    () => whileRewinding(chat, () async {
      final r = await daemon.client.rewindChat(
        RewindChatRequest(chatId: chat.id, itemId: item.id),
      );
      chat.takeBack.value = r.message;
    }),
  );
}

/// A user message with "Rewind to here" in its context menu, when
/// [onRewind] is set; its hover row has it too, and Esc Esc in the box
/// lists them all (`rewind_picker.dart`).
class RewindTarget extends StatelessWidget {
  const new({required this.child, super.key, this.onRewind});

  final Widget child;
  final VoidCallback? onRewind;

  @override
  Widget build(BuildContext context) {
    final run = onRewind;
    if (run == null) return child;
    return Menu(
      entries: [MenuEntry('Rewind to here', onPick: run)],
      builder: (context, open) => GestureDetector(
        onSecondaryTapUp: (d) => open(d.localPosition),
        child: child,
      ),
    );
  }
}
