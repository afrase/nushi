import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer.dart';
import 'daemon.dart';
import 'theme/theme.dart';
import 'transcript.dart';

/// A side question: a forked session beside the chat, which knows the
/// conversation so far but doesn't add to it. Closing it ends it.
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.side,
    required this.daemon,
    required this.quote,
    required this.onClose,
  });

  final ChatState side;
  final Daemon daemon;
  final ValueNotifier<String?> quote;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      width: 380,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.borderSubtle)),
      ),
      child: CallbackShortcuts(
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
                    Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: t.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Side question',
                      style: theme.ui(
                        t.text,
                        size: 12,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'not added to the chat',
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close and end the side question',
                      iconSize: 15,
                      color: t.textSecondary,
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transcript(
                  chat: side,
                  daemon: daemon,
                  onReply: (s) => quote.value = s,
                ),
              ),
              if (side.busy) const LinearProgressIndicator(minHeight: 2),
              Composer(
                chat: side,
                daemon: daemon,
                quote: quote,
                hint: 'Ask on the side',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
