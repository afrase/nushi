import 'package:flutter/material.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/tool_calls.dart';

/// One item of a transcript, by its kind.
class ItemView extends StatelessWidget {
  const new(
    this.item,
    this.chat,
    this.daemon, {
    required this.live,
    required this.still,
    super.key,
    this.onRewind,
  });

  final Item item;
  final ChatState chat;
  final Daemon daemon;

  /// The newest item while the agent works.
  final bool live;

  /// The agent waits on the user (a tool call isn't running then).
  final bool still;

  /// Rewinds the chat to just before this user message, if it can be.
  final VoidCallback? onRewind;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    switch (item.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE:
        return RewindTarget(
          onRewind: onRewind,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              // A message the agent was asked to pass to a subagent.
              _who(
                theme,
                item.relayTo.isEmpty
                    ? 'You'
                    : 'You → ${item.relayTo}, through ${chat.agentName}',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: box(t.borderSubtle, fill: t.raised),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    if (item.images.isNotEmpty) Thumbnails(item.images),
                    if (item.text.isNotEmpty) UserMessageText(item.text),
                  ],
                ),
              ),
            ],
          ),
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        return ToolCallView(item, still: still);
      case ItemKind.ITEM_KIND_QUESTION:
        return QuestionCard(
          item,
          agent: chat.agentName,
          onAnswer: (answer) => daemon.client.answerQuestion(
            AnswerQuestionRequest(
              chatId: chat.id,
              itemId: item.id,
              decline: answer == null,
              answers: answer,
            ),
          ),
        );
      case ItemKind.ITEM_KIND_THOUGHT:
        return ThoughtView(item, live: live);
      case ItemKind.ITEM_KIND_PLAN:
        return PlanView(item);
      case ItemKind.ITEM_KIND_NOTICE:
        final (icon, color) = switch (item.status) {
          'cancelled' => (Icons.stop_circle_outlined, t.textMuted),
          'taken_back' => (Icons.undo, t.textMuted),
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
          onAnswer: (option) => daemon.client.answerPermission(
            AnswerPermissionRequest(
              chatId: chat.id,
              itemId: item.id,
              optionId: option,
            ),
          ),
        );
      // The agent's messages, and kinds a newer daemon sends: ItemKind is
      // a protobuf enum, so a switch on it can't be exhaustive.
      // ignore: no_default_cases
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _who(theme, chat.agentName),
            AgentMarkdown(item.text, live: live),
            if (item.images.isNotEmpty) Thumbnails(item.images, size: 240),
          ],
        );
    }
  }
}

/// The small header above a message: who wrote it.
Widget _who(NushiTheme theme, String name) => Text(
  name,
  style: theme.ui(theme.t.textSecondary, size: 12, weight: FontWeight.w600),
);
