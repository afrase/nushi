import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/turn_status.dart';
import 'package:nushi/widgets.dart';

/// A side chat: a forked session beside the chat, which knows the
/// conversation so far but doesn't add to it; you can go back and forth in
/// it. ⇧⌘B or its − hides it ([toggleSide]), alive all the same; its ×
/// ends it ([endSide]), the only way to.
class SideChat extends StatelessWidget {
  const new({
    required this.side,
    required this.daemon,
    required this.onHide,
    required this.onClose,
    super.key,
  });

  final ChatState side;
  final Daemon daemon;
  final VoidCallback onHide;
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
                    Icons.remove,
                    tooltip: 'Hide the side chat   ${keyLabel(sideChatKey)}',
                    size: 15,
                    onTap: onHide,
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
  showSide(chat);
  if (selection.isNotEmpty) chat.side.value?.draft.quote.value = selection;
}

/// ⇧⌘B: opens [chat]'s side chat when it has none, else hides it or shows
/// it again.
Future<void> toggleSide(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  if (chat.side.value == null) {
    await askAside(context, daemon, chat);
  } else if (chat.sideHidden.value) {
    showSide(chat);
  } else {
    chat.sideHidden.value = true;
  }
}

/// Shows [chat]'s side chat if hidden; what ended while it was is seen.
void showSide(ChatState chat) {
  chat.sideHidden.value = false;
  chat.side.value?.done = null;
}

/// Ends [chat]'s side chat ([Daemon.closeSide]): its ×, the one way the
/// user ends one. Ending deletes its session for good and nothing of it
/// reaches the chat, so one with anything in it asks first; an empty one
/// just goes.
Future<void> endSide(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  final side = chat.side.value;
  if (side == null) return;
  if (side.items.isNotEmpty &&
      !await confirm(
        context,
        'End the side chat?',
        'Its conversation is deleted; nothing from it is added to the chat.',
        'End',
        destructive: true,
      )) {
    return;
  }
  // It may have ended meanwhile (the daemon's doing) or been replaced.
  if (chat.side.value == side) daemon.closeSide(chat);
}

/// The header's chip while [chat]'s side chat is hidden: it shows it
/// again; its dot says when the side chat works, waits on the user, or
/// ended a turn not seen yet.
class SideChip extends StatelessWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  /// About how wide it is with its gap, for the header's room.
  static const width = 100.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final side = chat.side.value;
    if (side == null || !chat.sideHidden.value) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: side,
      builder: (context, _) {
        final phase = side.phase;
        final marked = const [
          ChatPhase.waiting,
          ChatPhase.working,
          ChatPhase.background,
          ChatPhase.done,
        ].contains(phase);
        return Tap(
          tooltip:
              '${marked ? '${phaseWord(phase, t).$1}. ' : ''}'
              'Show the side chat   ${keyLabel(sideChatKey)}',
          onTap: () => showSide(chat),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 13, color: t.textSecondary),
              const SizedBox(width: 5),
              Text('Side chat', style: theme.ui(t.textSecondary, size: 12)),
              if (marked) ...[const SizedBox(width: 4), ChatDot(chat: side)],
            ],
          ),
        );
      },
    );
  }
}
