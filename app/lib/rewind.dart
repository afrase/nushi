import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'menu.dart';
import 'theme/theme.dart';
import 'widgets.dart';

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
  await tryOrShow(context, () async {
    final r = await daemon.client.rewindChat(
      RewindChatRequest(chatId: chat.id, itemId: item.id),
    );
    chat.takeBack.value = r.message;
  });
}

/// A user message with "Rewind to here" on hover (top right) and in its
/// context menu, when [onRewind] is set.
class RewindTarget extends StatefulWidget {
  const new({super.key, required this.child, this.onRewind});

  final Widget child;
  final VoidCallback? onRewind;

  @override
  State<RewindTarget> createState() => _RewindTargetState();
}

class _RewindTargetState extends State<RewindTarget> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.onRewind;
    if (run == null) return widget.child;
    return Menu(
      entries: [MenuEntry('Rewind to here', onPick: run)],
      builder: (context, open) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onSecondaryTapUp: (d) => open(d.localPosition),
          child: Stack(
            children: [
              widget.child,
              if (_hover)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconTap(
                    Icons.history,
                    size: 15,
                    color: NushiTheme.of(context).t.textMuted,
                    tooltip: 'Rewind to here',
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
