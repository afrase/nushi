import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/turn_status.dart';
import 'package:nushi/widgets.dart';

/// A side chat: a forked session beside the chat, which knows the
/// conversation so far but doesn't add to it; you can go back and forth in
/// it. Closing it ends it.
class SideChat extends StatelessWidget {
  const new({
    required this.side,
    required this.daemon,
    required this.onClose,
    super.key,
  });

  final ChatState side;
  final Daemon daemon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            PaneHeader(
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, size: 14, color: t.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Side chat',
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
                    tooltip: 'End the side chat',
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
            TurnStatus(side),
            Composer(chat: side, daemon: daemon, hint: 'Ask in the side chat'),
          ],
        ),
      ),
    );
  }
}

/// Opens [chat]'s side chat ([Daemon.openSide]), with [selection] quoted
/// in its box when given: from a selection's "Side chat", the palette or
/// ⇧⌘B (Claude Code's /btw).
Future<void> askAside(
  BuildContext context,
  Daemon daemon,
  ChatState chat, [
  String selection = '',
]) async {
  try {
    await daemon.openSide(chat);
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
  }
  if (selection.isNotEmpty) chat.side.value?.draft.quote.value = selection;
}
