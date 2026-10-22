import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'pickers.dart';
import 'question_card.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A chat's transcript with the composer under it.
class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true, // keeps the newest item in view while it streams
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            itemCount: chat.items.length,
            itemBuilder: (context, i) {
              final item = chat.items[chat.items.length - 1 - i];
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ItemView(item, chat.id, daemon, key: ValueKey(item.id)),
              );
            },
          ),
        ),
        if (chat.busy) const LinearProgressIndicator(minHeight: 2),
        _Composer(chat: chat, daemon: daemon),
      ],
    ),
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item, this.chatId, this.daemon, {super.key});

  final Item item;
  final String chatId;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    switch (item.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Who('You'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.raised,
                border: Border.all(color: t.borderSubtle),
                borderRadius: BorderRadius.circular(NushiTheme.card),
              ),
              child: SelectableText(item.text, style: theme.ui(t.text)),
            ),
          ],
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        return _ToolCallView(item);
      case ItemKind.ITEM_KIND_QUESTION:
        return QuestionCard(
          item,
          onAnswer: (answer) => daemon.answerQuestion(chatId, item.id, answer),
        );
      case ItemKind.ITEM_KIND_PERMISSION:
        return PermissionCard(
          item,
          onAnswer: (option) =>
              daemon.answerPermission(chatId, item.id, option),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Who('Claude'),
            const SizedBox(height: 4),
            AgentMarkdown(item.text),
          ],
        );
    }
  }
}

/// The small header above a message: who wrote it.
class _Who extends StatelessWidget {
  const _Who(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Text(
      name,
      style: theme.ui(theme.t.textSecondary, size: 12, weight: FontWeight.w600),
    );
  }
}

/// A tool call: a one-line header with its kind, title and status, and
/// its output when opened.
class _ToolCallView extends StatefulWidget {
  const _ToolCallView(this.item);

  final Item item;

  @override
  State<_ToolCallView> createState() => _ToolCallViewState();
}

class _ToolCallViewState extends State<_ToolCallView> {
  bool _open = false;

  static const _icons = {
    'read': Icons.description_outlined,
    'edit': Icons.edit_outlined,
    'delete': Icons.delete_outline,
    'move': Icons.drive_file_move_outline,
    'search': Icons.search,
    'execute': Icons.terminal,
    'think': Icons.psychology_outlined,
    'fetch': Icons.public,
  };

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final item = widget.item;
    final meta = theme.ui(t.textMuted, size: 12);
    final status = switch (item.status) {
      'completed' => Text('done', style: meta),
      'failed' => Text('failed', style: meta.copyWith(color: t.crashed)),
      'pending' => Text('pending', style: meta),
      _ => Text('running…', style: meta),
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              height: 28,
              color: t.raised,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    _open ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: t.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _icons[item.toolKind] ?? Icons.build_outlined,
                    size: 13,
                    color: t.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.code(t.text, size: 12).copyWith(height: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  status,
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.all(10),
              child: item.text.isEmpty
                  ? Text('No output', style: meta)
                  : AgentMarkdown(item.text),
            ),
        ],
      ),
    );
  }
}

/// The prompt box, with the agent's pickers and Send under it.
class _Composer extends StatefulWidget {
  const _Composer({required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

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
    if (text.isEmpty || widget.chat.busy) return;
    _text.clear();
    try {
      await widget.daemon.sendPrompt(widget.chat.id, text);
    } on Object catch (e) {
      _text.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(NushiTheme.control),
      borderSide: BorderSide(color: c, width: w),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chat.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(chat.error, style: theme.ui(t.crashed, size: 12)),
            ),
          CallbackShortcuts(
            // Enter sends; Shift+Enter starts a new line.
            bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
            child: TextField(
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              minLines: 2,
              maxLines: 8,
              style: theme.ui(t.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: chat.busy
                    ? 'Claude is working…'
                    : 'Message Claude   ⏎ send · ⇧⏎ newline',
                hintStyle: theme.ui(t.textMuted),
                filled: true,
                fillColor: t.base,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: border(t.borderStrong, 1),
                focusedBorder: border(t.focus, 2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Pickers(
                    options: chat.config,
                    onPick: (id, value) =>
                        widget.daemon.setConfigOption(chat.id, id, value),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Button(
                label: 'Send',
                hint: '⏎',
                kind: ButtonKind.primary,
                height: 24,
                onPressed: chat.busy ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
