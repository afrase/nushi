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
import 'thinking.dart';
import 'tool_calls.dart';
import 'widgets.dart';

/// A chat's transcript with the composer under it.
class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  /// The items, with each run of tool calls as one list.
  static List<Object> _entries(List<Item> items) {
    final out = <Object>[];
    for (final it in items) {
      final last = out.lastOrNull;
      if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
        if (last is List<Item>) {
          last.add(it);
          continue;
        }
        if (last is Item && last.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
          out.last = [last, it];
          continue;
        }
      }
      out.add(it);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) {
      final entries = _entries(chat.items);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // One selection across the transcript, messages included whole.
            child: SelectionArea(
              child: ListView.builder(
                reverse: true, // keeps the newest item in view while it streams
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[entries.length - 1 - i];
                  // Keyed here, the item's state follows it as items arrive.
                  return Padding(
                    key: ValueKey(
                      e is List<Item> ? 'group ${e.first.id}' : (e as Item).id,
                    ),
                    padding: const EdgeInsets.only(top: 12),
                    child: e is List<Item>
                        ? ToolGroupView(e)
                        : _ItemView(
                            e as Item,
                            chat.id,
                            daemon,
                            live: chat.busy && i == 0,
                          ),
                  );
                },
              ),
            ),
          ),
          if (chat.busy) const LinearProgressIndicator(minHeight: 2),
          _Composer(chat: chat, daemon: daemon),
        ],
      );
    },
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item, this.chatId, this.daemon, {required this.live});

  final Item item;
  final String chatId;
  final Daemon daemon;

  /// The newest item while the agent works.
  final bool live;

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
              child: Text(item.text, style: theme.ui(t.text)),
            ),
          ],
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        return ToolCallView(item);
      case ItemKind.ITEM_KIND_QUESTION:
        return QuestionCard(
          item,
          onAnswer: (answer) => daemon.answerQuestion(chatId, item.id, answer),
        );
      case ItemKind.ITEM_KIND_THOUGHT:
        return ThoughtView(item, live: live);
      case ItemKind.ITEM_KIND_PLAN:
        return PlanView(item);
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

  /// The plan of the current turn (since the last prompt), if any.
  Item? get _plan {
    for (final it in widget.chat.items.reversed) {
      if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return null;
      if (it.kind == ItemKind.ITEM_KIND_PLAN) return it;
    }
    return null;
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
          if (_plan case final plan? when chat.busy) PlanStatus(plan),
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
