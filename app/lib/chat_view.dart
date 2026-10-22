import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'daemon.dart';
import 'transcript.dart';

/// A chat's transcript with the composer under it. Escape stops a running
/// turn.
class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          stopTurn(context, chat, daemon),
    },
    child: ListenableBuilder(
      listenable: chat,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Transcript(chat: chat, daemon: daemon),
          ),
          if (chat.busy) const LinearProgressIndicator(minHeight: 2),
          Composer(chat: chat, daemon: daemon),
        ],
      ),
    ),
  );
}
