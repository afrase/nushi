import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'chat.dart';
import 'gen/nushi/v1/nushi.pb.dart';

/// A chat's transcript with a prompt box under it.
class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.chat, required this.onSend});

  final Chat chat;
  final Future<void> Function(String text) onSend;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) => Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true, // keeps the newest item in view while it streams
            padding: const EdgeInsets.all(16),
            itemCount: chat.items.length,
            itemBuilder: (context, i) =>
                _ItemView(chat.items[chat.items.length - 1 - i]),
          ),
        ),
        if (chat.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              chat.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (chat.busy) const LinearProgressIndicator(minHeight: 2),
        _Composer(onSend: onSend, enabled: !chat.busy),
      ],
    ),
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item);

  final Item item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (item.kind == ItemKind.ITEM_KIND_USER_MESSAGE) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(item.text),
        ),
      );
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: MarkdownBody(
        data: item.text,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          code: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
          codeblockDecoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend, required this.enabled});

  final Future<void> Function(String text) onSend;
  final bool enabled;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _text.clear();
    try {
      await widget.onSend(text);
    } on Object catch (e) {
      _text.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: CallbackShortcuts(
      // Enter sends; Shift+Enter starts a new line.
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
      child: TextField(
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        minLines: 1,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: widget.enabled
              ? 'Message the agent'
              : 'The agent is working…',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: widget.enabled ? _send : null,
          ),
        ),
      ),
    ),
  );
}
