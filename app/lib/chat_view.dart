import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'composer_parts.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'replies.dart';
import 'side_panel.dart';
import 'theme/theme.dart';
import 'transcript.dart';
import 'widgets.dart';

/// A chat's transcript with the composer under it, and beside them a side
/// question when one is open, or else [details]. Escape stops a running
/// turn.
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

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final Replies _replies = ValueNotifier(const []);
  final Replies _sideReplies = ValueNotifier(const []);
  final _sideQuote = ValueNotifier<String?>(null);
  final _images = Attachments();
  bool _dragging = false; // files are dragged over the chat
  ChatState? _side;
  bool _forking = false;
  late String _folder = widget.chat.folder;

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_moved);
  }

  /// A side question ends when the chat moves: it ran on the old agent.
  void _moved() {
    if (_folder == widget.chat.folder) return;
    _folder = widget.chat.folder;
    setState(_closeSide);
  }

  @override
  void dispose() {
    widget.chat.removeListener(_moved);
    _closeSide();
    _replies.dispose();
    _sideReplies.dispose();
    _images.dispose();
    _sideQuote.dispose();
    super.dispose();
  }

  Future<void> _ask(String selection) async {
    if (_side == null && !_forking) {
      setState(() => _forking = true);
      try {
        final side = await widget.daemon.forkChat(widget.chat);
        if (mounted) setState(() => _side = side);
      } on Object catch (e) {
        if (mounted) showError(context, e);
      } finally {
        if (mounted) setState(() => _forking = false);
      }
    }
    _sideQuote.value = selection;
  }

  /// Attaches the images dropped on the chat.
  Future<void> _drop(DropDoneDetails d) async {
    setState(() => _dragging = false);
    final paths = d.files.map((f) => f.path).where(isImageFile).toList();
    if (paths.isEmpty || widget.chat.archived) return;
    if (!widget.chat.canImages) {
      showError(context, 'Claude doesn’t take images in this chat');
      return;
    }
    await tryOrShow(context, () => _images.addFiles(paths));
  }

  void _closeSide() {
    final side = _side;
    if (side == null) return;
    _side = null;
    widget.daemon.closeSide(side).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final side = _side;
    return Row(
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
                              : (r) => _replies.value = [..._replies.value, r],
                          onSide: chat.archived ? null : _ask,
                        ),
                      ),
                      if (chat.busy || _forking)
                        const LinearProgressIndicator(minHeight: 2),
                      if (chat.archived)
                        _Archived(chat, widget.daemon)
                      else
                        Composer(
                          chat: chat,
                          daemon: widget.daemon,
                          replies: _replies,
                          attachments: _images,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (side != null && !chat.archived)
          SidePanel(
            side: side,
            daemon: widget.daemon,
            quote: _sideQuote,
            replies: _sideReplies,
            onClose: () => setState(_closeSide),
          )
        else if (widget.details != null)
          widget.details!,
      ],
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
