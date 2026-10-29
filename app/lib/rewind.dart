import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Whether the chat can be rewound to just before [item], a user message,
/// as the daemon says.
bool canRewindTo(ChatState chat, Item item) =>
    chat.canRewind && !chat.busy && !chat.archived && item.rewindable;

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
/// message in the composer to edit.
Future<void> rewindTo(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  Item item,
) => tryOrShow(context, () async {
  final r = await daemon.client.rewindChat(
    RewindChatRequest(chatId: chat.id, itemId: item.id),
  );
  chat.takeBack.value = r.message;
});

/// A user message with "Rewind to here" on hover (top right) and in its
/// context menu, when [onRewind] is set; Esc Esc in the box lists them all
/// (`rewind_picker.dart`).
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
      builder: (context, open) => Hover(
        builder: (context, {required hover}) => GestureDetector(
          onSecondaryTapUp: (d) => open(d.localPosition),
          // Passthrough: the message keeps its row's width (a band spans
          // the transcript) rather than shrinking to its text.
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              child,
              if (hover)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconTap(
                    Icons.history,
                    size: 15,
                    color: NushiTheme.of(context).t.textMuted,
                    tooltip: 'Rewind to here (Esc Esc)',
                    onTap: run,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
