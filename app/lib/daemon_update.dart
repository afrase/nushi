import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

extension SendPrompt on Daemon {
  /// Sends a prompt. One the daemon refused because it's restarting into a
  /// newer build goes again once the new one answers (a minute at most).
  Future<SendPromptResponse> sendPrompt(SendPromptRequest r) async {
    try {
      return await client.sendPrompt(r);
    } on connect.ConnectException catch (e) {
      if (e.code != connect.Code.unavailable ||
          !refusedFor(e, 'restarting', (m) => m.contains('restarting'))) {
        rethrow;
      }
      final before = daemonBuild;
      for (var i = 0; i < 300 && !(connected && daemonBuild != before); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return await client.sendPrompt(r);
    }
  }
}

/// What Continue sends: the words Claude Code's users type to have the
/// agent pick up where a failed turn left off.
const continuePrompt = 'Continue.';

/// What a failed turn's notice offers: its button's label and what it
/// sends.
typedef TurnRetry = ({String label, SendPromptRequest request});

/// What [notice], a failed turn's, offers to send. When the turn got
/// somewhere ([madeProgress]), Continue: [continuePrompt] as a plain
/// message, since the agent has the message and the work in its history
/// and sending the message again has it start over (or say it already
/// did). Else Try again: the chat's last message once more, with its
/// images, as a new one, to a subagent as it went.
///
/// Null unless the notice is the transcript's last item, the chat isn't
/// archived and no rewind is on its way; and for Try again, unless the
/// message can go again: not a subagent's task stopped (it has nothing to
/// send), nor a message for a subagent whose tool call a replay no longer
/// tells.
TurnRetry? failedTurnRetry(ChatState chat, Item notice) {
  final items = chat.items;
  if (notice.status != 'turn_failed' ||
      chat.archived ||
      chat.rewinding.value ||
      items.lastOrNull?.id != notice.id) {
    return null;
  }
  if (madeProgress(items, notice)) {
    return (
      label: 'Continue',
      request: SendPromptRequest(chatId: chat.id, text: continuePrompt),
    );
  }
  final message = items.reversed
      .where((it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE)
      .firstOrNull;
  if (message == null ||
      message.toSubagentStop ||
      message.toSubagentName.isNotEmpty && message.toSubagent.isEmpty ||
      message.text.isEmpty && message.images.isEmpty) {
    return null;
  }
  return (
    label: 'Try again',
    request: SendPromptRequest(
      chatId: chat.id,
      text: message.text,
      images: message.images,
      toSubagent: message.toSubagent,
    ),
  );
}

/// Whether the turn [notice] (the transcript's last item) ended got
/// anywhere after the last user message: the agent said, thought or did
/// something of its own between the two. That is a message with text or
/// images (not one that only repeats the failure, as Claude's "API Error:
/// …" does), a thought, a tool call (a subagent's start among them), a
/// plan, a permission prompt or a question; at the top level, and not a
/// subagent's report, since a subagent started earlier may add those to
/// any turn. Notices aren't the agent's. A message steered into the turn
/// is part of it: the turn's work before it counts, and the agent has the
/// message already. It reads only what a reopen keeps too (kinds, text and
/// Nushi's copy's steered mark, no times or live state), so it holds after
/// the daemon restarts.
bool madeProgress(List<Item> items, Item notice) {
  for (final it in items.reversed.skip(1)) {
    if (it.parent.isNotEmpty || it.report) continue;
    switch (it.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE when !it.steered:
        return false;
      case ItemKind.ITEM_KIND_AGENT_MESSAGE:
        final text = it.text.trim();
        if (it.images.isNotEmpty ||
            text.isNotEmpty && !notice.text.contains(text)) {
          return true;
        }
      case ItemKind.ITEM_KIND_THOUGHT ||
          ItemKind.ITEM_KIND_TOOL_CALL ||
          ItemKind.ITEM_KIND_PLAN ||
          ItemKind.ITEM_KIND_PERMISSION ||
          ItemKind.ITEM_KIND_QUESTION:
        return true;
      // Notices, and kinds a newer daemon sends.
      // ignore: no_default_cases
      default:
    }
  }
  return false;
}

/// Over the app while the daemon is older than the bundled one and
/// restarts into it by itself once nothing runs (Daemon.updatesWhenIdle),
/// with a way to restart now. A daemon too old for that gets
/// [OutdatedScreen].
class DaemonUpdateBar extends StatelessWidget {
  const new(this.daemon, {super.key, this.start = 16});

  final Daemon daemon;

  /// Where its text starts: past the traffic lights, with the sidebar hidden.
  final double start;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      color: t.raised,
      padding: EdgeInsets.fromLTRB(start, 4, 16, 4),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: daemon,
              builder: (context, _) => _Waiting(daemon),
            ),
          ),
          ListenableBuilder(
            listenable: daemon,
            builder: (context, _) => Button(
              label: daemon.restarting ? 'Restarting…' : 'Restart now',
              // What it stops is asked first.
              onPressed: daemon.restarting
                  ? null
                  : () => restartDaemonAsking(context, daemon),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Nushi will update its daemon when the chats are idle.", then what it
/// waits for, each a link to its chat: "Waiting for: Fix the login
/// redirect (working), a terminal running npm run dev in Release notes".
class _Waiting extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.ui(t.textSecondary, size: 12);
    final holds = [
      for (final h in daemon.restartHolds)
        if (daemon.chats[h.chatId] case final c?) (h, c),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'Nushi will update its daemon when the chats are idle.',
          style: style,
        ),
        if (holds.isNotEmpty) Text('Waiting for:', style: style),
        for (final (i, (h, c)) in holds.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (h.terminal) Text('a terminal ${h.why} in ', style: style),
              LinkText(
                c.shownTitle,
                size: 12,
                tooltip: 'Show the chat',
                onTap: () => daemon.select(c.id),
              ),
              Text(
                '${h.terminal ? '' : ' (${h.why})'}'
                '${i < holds.length - 1 ? ',' : ''}',
                style: style,
              ),
            ],
          ),
      ],
    );
  }
}

/// Says the daemon is older than the app and doesn't restart by itself,
/// with a way to restart it: the app shows nothing else until it has.
class OutdatedScreen extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The daemon is older than this app. Restarting it stops '
              'running turns and closes terminals; chats reopen as you open '
              'them.',
              textAlign: TextAlign.center,
              style: theme.ui(t.textSecondary),
            ),
            const SizedBox(height: 14),
            if (daemon.bundled != null)
              ListenableBuilder(
                listenable: daemon,
                builder: (context, _) => Button(
                  label: daemon.restarting ? 'Restarting…' : 'Restart daemon',
                  kind: ButtonKind.primary,
                  onPressed: daemon.restarting
                      ? null
                      : () => tryOrShow(context, daemon.restartDaemon),
                ),
              )
            else
              Text('make stop daemon', style: theme.code(t.textMuted)),
          ],
        ),
      ),
    );
  }
}
