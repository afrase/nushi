import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'composer_parts.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'status.dart';
import 'theme/theme.dart';
import 'transcript.dart';
import 'widgets.dart';

/// A side question: a forked session beside the chat, which knows the
/// conversation so far but doesn't add to it. Closing it ends it.
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.side,
    required this.daemon,
    required this.onClose,
  });

  final ChatState side;
  final Daemon daemon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            stopTurn(context, side, daemon),
      },
      child: ListenableBuilder(
        listenable: side,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: t.raised,
                border: Border(bottom: BorderSide(color: t.borderSubtle)),
              ),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, size: 14, color: t.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Side question',
                    style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'not added to the chat',
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                  ),
                  IconTap(
                    Icons.close,
                    tooltip: 'End the side question',
                    size: 15,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transcript(
                chat: side,
                daemon: daemon,
                onReply: (r) =>
                    side.draft.replies.value = [...side.draft.replies.value, r],
              ),
            ),
            if (side.busy) TurnStatus(side),
            Composer(chat: side, daemon: daemon, hint: 'Ask on the side'),
          ],
        ),
      ),
    );
  }
}

/// Side questions' end.
extension SideChats on Daemon {
  /// Ends [chat]'s side question, if it has one.
  void closeSide(ChatState chat) {
    final side = chat.side;
    if (side == null) return;
    chat.side = null;
    sides.remove(side.id);
    client.closeSideChat(CloseSideChatRequest(chatId: side.id)).ignore();
  }
}
