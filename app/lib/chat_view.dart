import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'composer.dart';
import 'daemon.dart';
import 'side_panel.dart';
import 'theme/theme.dart';
import 'transcript.dart';
import 'widgets.dart';

/// A chat's transcript with the composer under it, and a side question in a
/// panel beside them when one is open. Escape stops a running turn.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _quote = ValueNotifier<String?>(null);
  final _sideQuote = ValueNotifier<String?>(null);
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
    _quote.dispose();
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
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        if (mounted) setState(() => _forking = false);
      }
    }
    _sideQuote.value = selection;
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
                      onReply: chat.archived ? null : (s) => _quote.value = s,
                      onSide: chat.archived ? null : _ask,
                    ),
                  ),
                  if (chat.busy || _forking)
                    const LinearProgressIndicator(minHeight: 2),
                  if (chat.archived)
                    _Archived(chat, widget.daemon)
                  else
                    Composer(chat: chat, daemon: widget.daemon, quote: _quote),
                ],
              ),
            ),
          ),
        ),
        if (side != null && !chat.archived)
          SidePanel(
            side: side,
            daemon: widget.daemon,
            quote: _sideQuote,
            onClose: () => setState(_closeSide),
          ),
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
              () => daemon.archiveChat(chat.id, archived: false),
            ),
          ),
        ],
      ),
    );
  }
}
