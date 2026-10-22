import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards.dart';
import 'composer.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'question_card.dart';
import 'theme/theme.dart';
import 'thinking.dart';
import 'tool_calls.dart';

/// A chat's transcript with the composer under it. Escape stops a running
/// turn.
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
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              stopTurn(context, chat, daemon),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // One selection across the transcript, messages included whole.
              child: SelectionArea(
                child: ListView.builder(
                  reverse:
                      true, // keeps the newest item in view while it streams
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[entries.length - 1 - i];
                    // Keyed here, the item's state follows it as items arrive.
                    return Padding(
                      key: ValueKey(
                        e is List<Item>
                            ? 'group ${e.first.id}'
                            : (e as Item).id,
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
            Composer(chat: chat, daemon: daemon),
          ],
        ),
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
      case ItemKind.ITEM_KIND_NOTICE:
        final (icon, color) = switch (item.status) {
          'cancelled' => (Icons.stop_circle_outlined, t.textMuted),
          'error' => (Icons.error_outline, t.crashed),
          _ => (Icons.info_outline, t.needs),
        };
        return Row(
          spacing: 6,
          children: [
            Icon(icon, size: 14, color: color),
            Expanded(
              child: Text(item.text, style: theme.ui(color, size: 12.5)),
            ),
          ],
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
