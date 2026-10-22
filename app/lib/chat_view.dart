import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'daemon.dart';
import 'side_panel.dart';
import 'transcript.dart';

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

  @override
  void dispose() {
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
                      onReply: (s) => _quote.value = s,
                      onSide: _ask,
                    ),
                  ),
                  if (chat.busy || _forking)
                    const LinearProgressIndicator(minHeight: 2),
                  Composer(chat: chat, daemon: widget.daemon, quote: _quote),
                ],
              ),
            ),
          ),
        ),
        if (side != null)
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
