import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/shells.dart';
import 'package:nushi/side_panel.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/turn_status.dart';
import 'package:nushi/widgets.dart';

/// A chat's transcript with the composer under it, and beside them its
/// side question, a subagent's pane and [details], each when open. Escape
/// stops a running turn. What's being written, and the side question,
/// belong to the chat (its draft and side), so they outlive the view.
class ChatView extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    super.key,
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
    final replies = chat.draft.replies;
    final transcript = DropTarget(
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
                    onReply: chat.archived || chat.sessionGone
                        ? null
                        : (r) => replies.value = [...replies.value, r],
                    onSide: chat.archived || chat.sessionGone ? null : _ask,
                  ),
                ),
                TurnStatus(
                  chat,
                  what: _forking ? 'Starting a side chat' : null,
                ),
                if (chat.mcpChanged && !chat.archived)
                  _McpChanged(chat, widget.daemon),
                if (chat.archived)
                  _Archived(chat, widget.daemon)
                else if (chat.sessionGone)
                  _Expired(chat, widget.daemon)
                else
                  Composer(chat: chat, daemon: widget.daemon, folder: true),
              ],
            ),
          ),
        ),
      ),
    );
    return Previews(
      open: widget.daemon.daemonApi >= previewApi ? chat.openPreview : null,
      current: chat.preview,
      child: ListenableBuilder(
        listenable: Listenable.merge([chat.pane, chat.preview, subagentWide]),
        builder: (context, _) => _beside(transcript),
      ),
    );
  }

  /// The transcript, and beside it, left to right: the side question, a
  /// subagent's or background command's pane (or a file's preview in its
  /// place; either slides in as it opens), and [ChatView.details], each
  /// when open, at its own remembered width, each closed on its own.
  Widget _beside(Widget transcript) {
    final chat = widget.chat;
    final side = chat.archived ? null : chat.side;
    final id = chat.pane.value;
    final preview = id == null ? chat.preview.value : null;
    final wide = id != null && subagentWide.value || preview != null;
    final details = widget.details;
    return Beside(
      main: transcript,
      least: wide ? 360 : ChatView.minWidth,
      panes: [
        if (side != null)
          SidePane(
            'side',
            initial: 380,
            min: 300,
            cap: 640,
            child: SidePanel(
              key: ValueKey(side.id),
              side: side,
              daemon: widget.daemon,
              onClose: () => setState(() => widget.daemon.closeSide(chat)),
            ),
          ),
        if (id != null)
          SidePane(
            // A wide pane has a width of its own.
            wide ? 'subagent' : 'pane',
            initial: wide ? 640 : DetailsPanel.width,
            min: 220,
            cap: wide ? double.infinity : 480,
            child: Enter.slide(child: _pane(id)),
          ),
        if (preview != null)
          SidePane(
            'preview',
            initial: 560,
            min: 300,
            cap: double.infinity,
            child: Enter.slide(
              child: PreviewPane(
                key: ValueKey(preview),
                chat: chat,
                daemon: widget.daemon,
                path: preview,
                onClose: () => chat.preview.value = null,
              ),
            ),
          ),
      ],
      details: details == null
          ? null
          : SidePane(
              'details',
              initial: DetailsPanel.width,
              min: 220,
              cap: 480,
              child: details,
            ),
    );
  }

  /// A subagent's or background command's pane.
  Widget _pane(String id) {
    final chat = widget.chat;
    void onClose() => chat.pane.value = null;
    // Keyed: another subagent's pane is its own, its unsent text too.
    return chat.items.any((it) => it.id == id && it.hasShell())
        ? ShellPane(
            key: ValueKey(id),
            chat: chat,
            daemon: widget.daemon,
            id: id,
            onClose: onClose,
          )
        : SubagentPane(
            key: ValueKey(id),
            chat: chat,
            daemon: widget.daemon,
            id: id,
            onClose: onClose,
          );
  }
}

/// In place of the composer for an archived chat: it is read-only until
/// unarchived.
class _Archived extends StatelessWidget {
  const new(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
                  ? 'Archived. Unarchive it to see its history and go on.'
                  : 'Archived. Unarchive it to go on.',
              style: theme.ui(t.textSecondary),
            ),
          ),
          RunButton(
            label: 'Unarchive',
            kind: ButtonKind.primary,
            run: () =>
                daemon.client.archiveChat(ArchiveChatRequest(chatId: chat.id)),
          ),
        ],
      ),
    );
  }
}

/// Over the composer once MCP servers changed for the chat's folder: the
/// agent keeps the ones it started with until the chat reloads.
class _McpChanged extends StatelessWidget {
  const new(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
          ReloadButton(chat, daemon),
        ],
      ),
    );
  }
}

/// Reloads a chat's agent (asking first when that stops background
/// work), so it picks up changed MCP servers; disabled while it works.
class ReloadButton extends StatelessWidget {
  const new(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: chat.busy ? 'Once ${chat.agentName} is done' : '',
    child: RunButton(
      label: 'Reload',
      run: chat.busy
          ? null
          : () async {
              if (await stopsBackground(
                    context,
                    chat,
                    'Reload the chat?',
                    'Reload',
                  ) &&
                  context.mounted) {
                await daemon.client.reloadChat(
                  ReloadChatRequest(chatId: chat.id),
                );
              }
            },
    ),
  );
}

/// In place of the composer for a chat whose session its agent deleted
/// (its notice says so): it is read-only, its transcript Nushi's copy, if
/// it has one (ADR 0047). A new chat can start where it was.
class _Expired extends StatelessWidget {
  const new(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.history_toggle_off, size: 15, color: t.textMuted),
          Expanded(
            child: Text(
              chat.items.any((it) => it.kind != ItemKind.ITEM_KIND_NOTICE)
                  ? 'Read-only: Nushi’s copy of the transcript.'
                  : 'Read-only.',
              style: theme.ui(t.textSecondary),
            ),
          ),
          Button(
            label: 'Delete…',
            kind: ButtonKind.destructive,
            onPressed: () => showDeleteChat(context, chat, daemon),
          ),
          Button(
            label: 'Start a new chat here',
            kind: ButtonKind.primary,
            onPressed: () =>
                newChat(context, daemon, chat.scratch ? '' : chat.folder),
          ),
        ],
      ),
    );
  }
}
