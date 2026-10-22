import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'question_card.dart';

/// A chat's transcript with a prompt box under it.
class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.chat, required this.daemon});

  final Chat chat;
  final Daemon daemon;

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
            itemBuilder: (context, i) {
              final item = chat.items[chat.items.length - 1 - i];
              return _ItemView(item, daemon, key: ValueKey(item.id));
            },
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
        _Composer(onSend: daemon.sendPrompt, enabled: !chat.busy),
      ],
    ),
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item, this.daemon, {super.key});

  final Item item;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    if (item.kind == ItemKind.ITEM_KIND_USER_MESSAGE) {
      final scheme = Theme.of(context).colorScheme;
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
    if (item.kind == ItemKind.ITEM_KIND_TOOL_CALL) return _ToolCallView(item);
    if (item.kind == ItemKind.ITEM_KIND_QUESTION) {
      return QuestionCard(
        item,
        onAnswer: (answer) => daemon.answerQuestion(item.id, answer),
      );
    }
    if (item.kind == ItemKind.ITEM_KIND_PERMISSION) {
      return PermissionCard(
        item,
        onAnswer: (option) => daemon.answerPermission(item.id, option),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AgentMarkdown(item.text),
    );
  }
}

/// A tool call: one line with its kind, title and status, and its output
/// when expanded.
class _ToolCallView extends StatelessWidget {
  const _ToolCallView(this.item);

  final Item item;

  static const _icons = {
    'read': Icons.description_outlined,
    'edit': Icons.edit_outlined,
    'delete': Icons.delete_outline,
    'move': Icons.drive_file_move_outline,
    'search': Icons.search,
    'execute': Icons.terminal,
    'think': Icons.psychology_outlined,
    'fetch': Icons.language,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = switch (item.status) {
      'completed' => Icon(Icons.check, size: 16, color: scheme.primary),
      'failed' => Icon(Icons.close, size: 16, color: scheme.error),
      _ => const SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    };
    return ExpansionTile(
      dense: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 32, bottom: 8),
      expandedAlignment: Alignment.centerLeft,
      shape: const Border(),
      leading: Icon(_icons[item.toolKind] ?? Icons.build_outlined, size: 18),
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          status,
        ],
      ),
      children: [
        item.text.isEmpty
            ? Text('No output', style: TextStyle(color: scheme.outline))
            : AgentMarkdown(item.text),
      ],
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
