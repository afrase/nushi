import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'composer_parts.dart';
import 'daemon.dart';
import 'details_panel.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'panes.dart';
import 'side_panel.dart';
import 'status.dart';
import 'theme/theme.dart';
import 'transcript.dart';
import 'widgets.dart';

/// A chat's transcript with the composer under it, and beside them a side
/// question when one is open, or else [details]. Escape stops a running
/// turn. What's being written, and the side question, belong to the chat
/// (its draft and side), so they outlive the view.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.chat,
    required this.daemon,
    this.details,
  });

  final ChatState chat;
  final Daemon daemon;
  final Widget? details;

  /// The narrowest the transcript gets beside a panel.
  static const minWidth = 556.0;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  bool _dragging = false; // files are dragged over the chat
  bool _forking = false;

  Future<void> _ask(String selection) async {
    final chat = widget.chat;
    if (chat.side == null && !_forking) {
      setState(() => _forking = true);
      try {
        chat.side = await widget.daemon.forkChat(chat);
      } on Object catch (e) {
        if (mounted) showError(context, e);
      } finally {
        if (mounted) setState(() => _forking = false);
      }
    }
    chat.side?.draft.quote.value = selection;
  }

  /// Attaches the images dropped on the chat.
  Future<void> _drop(DropDoneDetails d) async {
    setState(() => _dragging = false);
    final paths = d.files.map((f) => f.path).where(isImageFile).toList();
    if (paths.isEmpty || widget.chat.archived) return;
    if (!widget.chat.canImages) {
      showError(
        context,
        '${widget.chat.agentName} doesn’t take images in this chat',
      );
      return;
    }
    await tryOrShow(context, () => widget.chat.draft.images.addFiles(paths));
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final side = chat.side;
    final replies = chat.draft.replies;
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: _drop,
              child: Container(
                foregroundDecoration: _dragging
                    ? BoxDecoration(
                        border: Border.all(
                          color: NushiTheme.of(context).t.focus,
                          width: 2,
                        ),
                      )
                    : null,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        stopTurn(context, chat, widget.daemon),
                  },
                  child: ListenableBuilder(
                    listenable: chat,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Transcript(
                            chat: chat,
                            daemon: widget.daemon,
                            onReply: chat.archived
                                ? null
                                : (r) => replies.value = [...replies.value, r],
                            onSide: chat.archived ? null : _ask,
                          ),
                        ),
                        if (chat.busy || _forking)
                          TurnStatus(
                            chat,
                            what: _forking ? 'Starting a side chat' : null,
                          ),
                        if (chat.mcpChanged && !chat.archived)
                          _McpChanged(chat, widget.daemon),
                        if (chat.archived)
                          _Archived(chat, widget.daemon)
                        else
                          Composer(
                            chat: chat,
                            daemon: widget.daemon,
                            folder: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (side != null && !chat.archived)
            Resizable(
              name: 'side',
              initial: 380,
              min: 300,
              max: min(640, box.maxWidth - ChatView.minWidth),
              left: true,
              child: SidePanel(
                key: ValueKey(side.id),
                side: side,
                daemon: widget.daemon,
                onClose: () => setState(() => widget.daemon.closeSide(chat)),
              ),
            )
          else if (widget.details != null)
            Resizable(
              name: 'details',
              initial: DetailsPanel.width,
              min: 220,
              max: min(480, box.maxWidth - ChatView.minWidth),
              left: true,
              child: widget.details!,
            ),
        ],
      ),
    );
  }
}

/// In place of the composer for an archived chat: it is read-only until
/// unarchived.
class _Archived extends StatelessWidget {
  const _Archived(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chat.items.isEmpty
                  ? 'Archived. Unarchive it to bring back its history and keep chatting.'
                  : 'Archived: read-only. Unarchive it to keep chatting.',
              style: theme.ui(t.textSecondary),
            ),
          ),
          Button(
            label: 'Unarchive',
            kind: ButtonKind.primary,
            onPressed: () => tryOrShow(
              context,
              () => daemon.client.archiveChat(
                ArchiveChatRequest(chatId: chat.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Over the composer once MCP servers changed for the chat's folder: the
/// agent keeps the ones it started with until the chat reloads.
class _McpChanged extends StatelessWidget {
  const _McpChanged(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 13, color: t.textMuted),
          const SizedBox(width: 6),
          Text(
            'MCP servers changed. Reload to use them.',
            style: theme.ui(t.textSecondary, size: 12),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: chat.busy
                ? 'Once ${chat.agentName} is done'
                : 'Reopens the chat with the servers as they are now',
            child: Button(
              label: 'Reload',
              kind: ButtonKind.ghost,
              height: 22,
              onPressed: chat.busy
                  ? null
                  : () => tryOrShow(
                      context,
                      () => daemon.client.reloadChat(
                        ReloadChatRequest(chatId: chat.id),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
