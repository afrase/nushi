import 'package:flutter/material.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_cards.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/findings.dart';
import 'package:nushi/findings_card.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/marks.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/plan_view.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/stop_label.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/turn_retry.dart';
import 'package:nushi/widgets.dart';

/// The widest a user message's bubble goes (ADR 0076).
const _bubbleWidth = 640.0;

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
    this.onFork,
    this.pinned = false,
    this.onPin,
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

  /// Forks a new chat up to this agent message, if it can be.
  final VoidCallback? onFork;

  /// The message is pinned (ADR 0085): its pin action shows held down.
  final bool pinned;

  /// Pins or unpins it, if it can be: one of the agent's messages.
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    switch (item.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE:
        final phone = TouchTargets.of(context);
        if (!phone) return _bubble(context);
        // On the phone a band across the transcript, the heading of the
        // agent's work that follows it.
        return RewindTarget(
          onRewind: onRewind,
          child: LayoutBuilder(
            builder: (context, box) => Container(
              padding: EdgeInsets.fromLTRB(
                chatSides(context, box.maxWidth).left,
                12,
                36,
                12,
              ),
              alignment: Alignment.topLeft,
              decoration: BoxDecoration(
                color: t.userBand,
                border: Border.symmetric(
                  horizontal: BorderSide(color: t.userBandBorder),
                ),
              ),
              child: _contents(context),
            ),
          ),
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        if (item.hasFindings()) return FindingsCard(item.findings, chat);
        return ToolCallView(item, still: still, refs: _refs);
      case ItemKind.ITEM_KIND_QUESTION:
        return QuestionCard(
          item,
          agent: chat.agentName,
          draft: chat.answers.putIfAbsent(item.id, QuestionDraft.new),
          onAnswer: (answer) async {
            await daemon.client.answerQuestion(
              AnswerQuestionRequest(
                chatId: chat.id,
                itemId: item.id,
                decline: answer == null,
                answers: answer,
              ),
            );
            chat.answers.remove(item.id); // sent: nothing to keep
          },
        );
      case ItemKind.ITEM_KIND_THOUGHT:
        return ThoughtView(item, live: live);
      case ItemKind.ITEM_KIND_PLAN:
        return PlanView(item, chat);
      case ItemKind.ITEM_KIND_NOTICE
          when item.status == 'compacted' || item.status == 'history_differs':
        return HistoryMark(item, agent: chat.agentName);
      case ItemKind.ITEM_KIND_NOTICE:
        final (icon, color) = switch (item.status) {
          'cancelled' => (Icons.stop_circle_outlined, t.textMuted),
          'taken_back' => (Icons.undo, t.textMuted),
          // The agent working on its own: a chapter without a message.
          'own_turn' => (Icons.update, t.textMuted),
          // Nushi named the worktree's branch after the chat, or the
          // folder was switched to another branch.
          'branch_renamed' ||
          'branch_switched' => (Icons.account_tree_outlined, t.textMuted),
          'error' ||
          'turn_failed' ||
          'not_ready' ||
          'folder_gone' ||
          'reopen_failed' => (Icons.error_outline, t.crashed),
          // Its agent deleted the session: nothing broke.
          'session_gone' => (Icons.history_toggle_off, t.textMuted),
          // The agent's own notice, not its model's words (Claude Code's),
          // or what a command Nushi ran in its place did (Claude's /plan).
          'agent_notice' || 'command' => (Icons.info_outline, t.textMuted),
          'agent_warning' => (Icons.warning_amber_rounded, t.needs),
          _ => (Icons.info_outline, t.needs),
        };
        // A reopen or a turn that failed: what helps.
        final again = failedTurnRetry(chat, item);
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
          // Continue when the turn got somewhere, else Try again.
          'turn_failed' when again != null => (
            again.label,
            () => tryOrShow(context, () async {
              // Its images, if they came as references, go whole.
              final r = again.request;
              final images = await daemon.images.whole(chat.id, r.images);
              await daemon.sendPrompt(
                r.deepCopy()
                  ..images.clear()
                  ..images.addAll(images),
              );
            }),
          ),
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
      case ItemKind.ITEM_KIND_AGENT_MESSAGE
          when item.status == 'stopped_by_safeguards':
        return StoppedView(item);
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
        final message = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            if (found == null)
              LinkedMarkdown(item.text, chat, daemon, live: live)
            else ...[
              if (found.before.isNotEmpty)
                LinkedMarkdown(found.before, chat, daemon, live: false),
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
                LinkedMarkdown(found.after, chat, daemon, live: live),
            ],
            if (item.images.isNotEmpty)
              Thumbnails(item.images, size: 240, refs: _refs),
          ],
        );
        if (TouchTargets.of(context)) return message;
        return MessageActions(
          actions: () => [
            // As Claude's: Copy, Fork, then the pin.
            CopyAction(item.text),
            if (onFork case final fork?)
              IconTap(
                Icons.call_split,
                size: 15,
                color: t.textMuted,
                tooltip: 'Fork from here: a new chat up to this message',
                onTap: fork,
              ),
            if (onPin case final pin?) PinAction(pinned: pinned, onTap: pin),
            if (item.sent != 0) MessageTime(item.sent.toInt()),
          ],
          child: message,
        );
    }
  }

  /// Where the item's images that came as references come from.
  ImageRefs get _refs => (images: daemon.images, chatId: chat.id);

  /// Whether something of the agent's follows this message: it read it.
  bool get _answered => chat.items
      .skip(chat.items.indexOf(item) + 1)
      .any(
        (i) => i.kind != ItemKind.ITEM_KIND_USER_MESSAGE && i.parent.isEmpty,
      );

  /// A user message on the Mac: a bubble at the column's right, its actions
  /// under it on hover.
  Widget _bubble(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return MessageActions(
      end: true,
      actions: () => [
        ReadMark(read: _answered, agent: chat.agentName),
        if (item.sent != 0) MessageTime(item.sent.toInt()),
        CopyAction(item.text),
        if (onRewind case final rewind?)
          IconTap(
            Icons.history,
            size: 15,
            color: t.textMuted,
            tooltip: 'Rewind to here (Esc Esc)',
            onTap: rewind,
          ),
      ],
      child: RewindTarget(
        onRewind: onRewind,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _bubbleWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.userBand,
              borderRadius: BorderRadius.circular(NushiTheme.panelWas14),
            ),
            child: _contents(context),
          ),
        ),
      ),
    );
  }

  /// A user message's contents, in its band or its bubble.
  Widget _contents(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 6,
    children: [
      if (item.toSubagentName.isNotEmpty) _ToSubagentMark(item, chat),
      if (item.images.isNotEmpty) Thumbnails(item.images, refs: _refs),
      ?messageFiles(context, item, chat),
      if (item.text.isNotEmpty) UserMessageText(item.text),
    ],
  );
}

/// Which subagent a message was for (the agent was asked to pass it on, or
/// to stop it or a background command), and how that went: the band's
/// marker, in the chat's transcript and in the subagent's pane, where it
/// shows among the subagent's steps. A click opens the subagent's pane.
class _ToSubagentMark extends StatelessWidget {
  const new(this.item, this.chat);

  final Item item;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final agent = chat.agentName;
    final stop = item.toSubagentStop;
    final (state, color) = switch (item.toSubagentState) {
      'sending' when stop => ('waiting for $agent to stop it', t.userBandMuted),
      'relayed' when stop => ('stopped', t.userBandMuted),
      'failed' when stop => ('$agent didn’t stop it', t.crashed),
      'sending' => ('waiting for $agent to pass it on', t.userBandMuted),
      'relayed' => ('passed on', t.userBandMuted),
      'failed' => ('$agent didn’t pass it on', t.crashed),
      _ => ('', t.userBandMuted),
    };
    // A stop is one line, as it was queued (stopLabel); the command it
    // stops can be many.
    final label = stop
        ? Text.rich(
            TextSpan(
              children: [
                stopLabel(
                  theme,
                  t.userBandMuted,
                  chat,
                  name: item.toSubagentName,
                  call: item.toSubagent,
                ),
                if (state.isNotEmpty)
                  TextSpan(text: ' · $state', style: theme.ui(color, size: 12)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '→ ${item.toSubagentName}',
                  style: theme.ui(
                    t.userBandMuted,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ', through $agent${state.isEmpty ? '' : ' · $state'}',
                  style: theme.ui(color, size: 12),
                ),
              ],
            ),
          );
    if (item.toSubagent.isEmpty) return label;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tap(
        onTap: () => chat.pane.value = item.toSubagent,
        tooltip: 'Open ${stopCommand(item.toSubagentName)}’s steps',
        child: label,
      ),
    );
  }
}
