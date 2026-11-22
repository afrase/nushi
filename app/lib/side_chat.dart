import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/pane_title.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/side_toast.dart';
import 'package:nushi/status.dart';
import 'package:nushi/text_width.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/top_notices.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/turn_status.dart';
import 'package:nushi/widgets.dart';

/// A side chat: a forked session beside the chat, which knows the
/// conversation so far but doesn't add to it; you can go back and forth in
/// it. ⇧⌘B or its − hides it ([toggleSide]), alive all the same; its ×
/// ends it ([endSide]: archived, with Undo), the only way to, unless Keep
/// as chat makes it a chat of its own ([keepSide]).
class SideChat extends StatelessWidget {
  const new({
    required this.side,
    required this.daemon,
    required this.onHide,
    required this.onClose,
    required this.onKeep,
    super.key,
  });

  final ChatState side;
  final Daemon daemon;
  final VoidCallback onHide;
  final VoidCallback onClose;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
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
              end: PaneHeader.buttonsEnd,
              child: _Row(
                side: side,
                daemon: daemon,
                onHide: onHide,
                onClose: onClose,
                onKeep: onKeep,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transcript(
                      chat: side,
                      daemon: daemon,
                      onReply: side.draft.addReply,
                    ),
                  ),
                  if (side.items.isEmpty) const _Empty(),
                ],
              ),
            ),
            // The update card stands above them where it's over this pane
            // ([CardFloor], ADR 0128).
            UnderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TurnStatus(side),
                  Composer(
                    chat: side,
                    daemon: daemon,
                    hint: 'Ask in the side chat',
                    commands: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [chat]'s side chat ([DaemonSides.openSide]), with [selection] quoted
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

/// The API that archives a side chat its × ends (ADR 0115).
const archiveSideApi = 117;

/// Ends [chat]'s side chat: its ×, the one way the user ends one. It goes
/// at once; the daemon archives one with messages ([DaemonSides.archiveSide])
/// and a toast says so, with Undo ([showArchivedSide]). A daemon older
/// than [archiveSideApi], or one that can't archive it (its agent can't
/// reopen sessions), deletes it instead ([DaemonSides.closeSide]), so one
/// with anything in it asks first.
Future<void> endSide(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  final side = chat.side.value;
  if (side == null) return;
  String? why; // why it couldn't be archived
  if (daemon.daemonApi >= archiveSideApi) {
    final toast = Toasts.maybeOf(context);
    try {
      final archived = await daemon.archiveSide(chat);
      if (archived.isNotEmpty && toast != null) {
        showArchivedSide(toast, daemon, chat, archived, was: side);
      }
      return;
    } on Object catch (e) {
      why = errorText(e);
    }
    if (!context.mounted || chat.side.value != side) return;
  }
  if ((side.items.isNotEmpty || why != null) &&
      !await confirm(
        context,
        'End the side chat?',
        [
          if (why != null) "It can't be archived: $why.",
          'Its conversation is deleted; nothing from it is added to the chat.',
        ].join(' '),
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
          tooltip: withKey(
            '${marked ? '${phaseWord(phase, t).$1}. ' : ''}Show the side chat',
            keyLabel(sideChatKey),
          ),
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

/// The side chat's top row: its name, what it is, Keep as chat, hide and
/// end. Narrowed for a narrow window (ADR 0123) it shortens its words, then
/// Keep as chat is its icon alone, never its buttons cut.
class _Row extends StatelessWidget {
  const new({
    required this.side,
    required this.daemon,
    required this.onHide,
    required this.onClose,
    required this.onKeep,
  });

  final ChatState side;
  final Daemon daemon;
  final VoidCallback onHide;
  final VoidCallback onClose;
  final VoidCallback onKeep;

  /// Under this, Keep as chat's words leave the name no room: its icon.
  static const wordsFrom = 240.0;

  /// Under this, the row's own icon leaves its three buttons no room.
  static const iconFrom = 140.0;

  /// An icon button's box here: its 15 and [IconTap.header] each side.
  static const double _button = 15 + 2 * IconTap.header;

  /// Keep as chat's words' width, as its [Tap] draws them.
  static double _keepWidth(BuildContext context, TextStyle style) =>
      textWidth(context, 'Keep as chat', style).ceilToDouble() + 12;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final can = canKeepSide(daemon, side);
    const keep = 'Keep as chat: a chat of its own in the sidebar';
    final keepStyle = theme.ui(can ? t.textSecondary : t.textMuted, size: 12);
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth;
        final icon = room >= iconFrom;
        // Its words while they leave the name its least, as measured.
        final words =
            room >=
            max(
              wordsFrom,
              (icon ? 22 : 0) +
                  PaneTitle.titleLeast +
                  _keepWidth(context, keepStyle) +
                  2 * _button,
            );
        return Row(
          children: [
            // Squeezed in a narrow window (ADR 0123), its buttons keep their
            // room and its icon goes; narrower than its three buttons, hide
            // goes (its key stays), then Keep as chat.
            if (icon) ...[
              Icon(Icons.forum_outlined, size: 14, color: t.textSecondary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: PaneTitle(
                title: Text(
                  'Side chat',
                  style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                ),
                caption: Text(
                  'not added to the chat',
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ),
            ),
            if (daemon.daemonApi >= forkApi && words)
              Tap(
                tooltip: keep,
                onTap: can ? onKeep : null,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text('Keep as chat', style: keepStyle),
              )
            else if (daemon.daemonApi >= forkApi && room >= 2 * _button)
              IconTap(
                Icons.open_in_new,
                tooltip: keep,
                size: 15,
                padding: IconTap.header,
                onTap: can ? onKeep : null,
              ),
            if (room >= 3 * _button)
              IconTap(
                Icons.remove,
                tooltip: withKey('Hide the side chat', keyLabel(sideChatKey)),
                size: 15,
                padding: IconTap.header,
                onTap: onHide,
              ),
            IconTap(
              Icons.close,
              tooltip: 'End the side chat',
              size: 15,
              padding: IconTap.header,
              onTap: onClose,
            ),
          ],
        );
      },
    );
  }
}

/// What an empty side chat says it's for (issue 61).
const sideChatEmpty =
    'Ask about this chat here: the side chat knows the conversation so far, '
    'and nothing you say here is added to it.';

/// [sideChatEmpty] where the side chat's messages will be, until the first
/// is in.
class _Empty extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                sideChatEmpty,
                textAlign: TextAlign.center,
                style: theme.ui(theme.t.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
