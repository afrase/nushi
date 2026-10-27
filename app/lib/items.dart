import 'package:flutter/material.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/findings.dart';
import 'package:nushi/findings_card.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/marks.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';

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
        // A band across the transcript, the heading of the agent's work
        // that follows it; the right keeps room for Rewind.
        return RewindTarget(
          onRewind: onRewind,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 36, 12),
            decoration: BoxDecoration(
              color: t.userBand,
              border: Border.symmetric(
                horizontal: BorderSide(color: t.userBandBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                if (item.relayTo.isNotEmpty) _Relayed(item, chat),
                if (item.images.isNotEmpty) Thumbnails(item.images),
                if (item.text.isNotEmpty) UserMessageText(item.text),
              ],
            ),
          ),
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        if (item.hasFindings()) return FindingsCard(item.findings, chat);
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
      case ItemKind.ITEM_KIND_NOTICE
          when item.status == 'compacted' || item.status == 'history_differs':
        return HistoryMark(item, agent: chat.agentName);
      case ItemKind.ITEM_KIND_NOTICE:
        final (icon, color) = switch (item.status) {
          'cancelled' => (Icons.stop_circle_outlined, t.textMuted),
          'taken_back' => (Icons.undo, t.textMuted),
          // The agent working on its own: a chapter without a message.
          'own_turn' => (Icons.update, t.textMuted),
          // Nushi named the worktree's branch after the chat.
          'branch_renamed' => (Icons.account_tree_outlined, t.textMuted),
          'error' ||
          'not_ready' ||
          'folder_gone' ||
          'reopen_failed' => (Icons.error_outline, t.crashed),
          // Its agent deleted the session: nothing broke.
          'session_gone' => (Icons.history_toggle_off, t.textMuted),
          _ => (Icons.info_outline, t.needs),
        };
        // A reopen that failed: what helps.
        final fix = switch (item.status) {
          'not_ready' => (
            'Set up…',
            () => daemon.openSettings(
              section: SettingsSection.agents,
              agent: chat.agent,
            ),
          ),
          'folder_gone' => (
            'Move…',
            () => moveChat(context, daemon, chat, gone: true),
          ),
          'reopen_failed' => ('Try again', () => daemon.reopen(chat)),
          // A session gone: the bar in the composer's place has Delete….
          _ => null,
        };
        return Row(
          spacing: 6,
          children: [
            Icon(icon, size: 14, color: color),
            Expanded(
              child: Text(item.text, style: theme.ui(color, size: 12.5)),
            ),
            if (fix case (final label, final onPressed))
              Button(label: label, onPressed: chat.busy ? null : onPressed),
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
        // A review's findings written as JSON show as their card, unless
        // a card above showed them already in this turn (Claude reported
        // them, then printed them too): then only what's around them, and
        // the JSON folded.
        final found = findingsInText(item.text);
        final again =
            found != null &&
            findingIds(found.findings.items)
                .toSet()
                .difference(
                  findingsShownBefore(chat.items, chat.items.indexOf(item)),
                )
                .isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            if (found == null)
              AgentMarkdown(item.text, live: live)
            else ...[
              if (found.before.isNotEmpty) AgentMarkdown(found.before),
              if (again)
                FindingsAgain(found.json)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FindingsCard(
                    found.findings,
                    chat,
                    json: found.json,
                    key: const ValueKey('findings'),
                  ),
                ),
              if (found.after.isNotEmpty)
                AgentMarkdown(found.after, live: live),
            ],
            if (item.images.isNotEmpty) Thumbnails(item.images, size: 240),
          ],
        );
    }
  }
}

/// Which subagent a message was for (the agent was asked to pass it on, or
/// to stop it or a background command), and how that went: the band's
/// marker, in the chat's transcript and in the subagent's pane, where it
/// shows among the subagent's steps. A click opens the subagent's pane.
class _Relayed extends StatelessWidget {
  const new(this.item, this.chat);

  final Item item;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final agent = chat.agentName;
    final stop = item.relayStop;
    final (state, color) = switch (item.relayState) {
      'sending' when stop => ('waiting for $agent to stop it', t.userBandMuted),
      'relayed' when stop => ('stopped', t.userBandMuted),
      'failed' when stop => ('$agent didn’t stop it', t.crashed),
      'sending' => ('waiting for $agent to pass it on', t.userBandMuted),
      'relayed' => ('passed on', t.userBandMuted),
      'failed' => ('$agent didn’t pass it on', t.crashed),
      _ => ('', t.userBandMuted),
    };
    final shell = chat.items.any(
      (it) => it.id == item.relayCall && it.hasShell(),
    );
    final target = shell ? '\$ ${item.relayTo}' : item.relayTo;
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: stop ? 'Stop $target' : '→ $target',
            style: theme.ui(t.userBandMuted, size: 12, weight: FontWeight.w600),
          ),
          TextSpan(
            text: ', through $agent${state.isEmpty ? '' : ' · $state'}',
            style: theme.ui(color, size: 12),
          ),
        ],
      ),
    );
    if (item.relayCall.isEmpty) return label;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tap(
        onTap: () => chat.pane.value = item.relayCall,
        tooltip: 'Open ${item.relayTo}’s steps',
        child: label,
      ),
    );
  }
}
