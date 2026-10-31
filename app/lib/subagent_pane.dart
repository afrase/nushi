import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/widgets.dart';

/// A subagent beside the chat, left of the details panel: its prompt
/// (folded), its model and state, then its steps as they come, and its
/// result. Stop stops it while it runs; × closes it.
class SubagentPane extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.id,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String id; // the subagent's call
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final s = subagentsOf(chat.items)
            .where((s) => s.call.id == id)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaneHeader(
              child: Row(
                children: [
                  Expanded(
                    child: s == null
                        ? const SizedBox.shrink()
                        : subagentName(context, s, size: 12),
                  ),
                  if (s != null && subagentStoppable(s))
                    stopButton(context, daemon, chat, id),
                  const WideToggle(),
                  IconTap(
                    Icons.close,
                    tooltip: 'Close',
                    size: 15,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: s == null
                  ? Center(
                      child: Text(
                        'This subagent is no longer in the chat.',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    )
                  : Transcript(
                      key: ValueKey(id),
                      chat: chat,
                      daemon: daemon,
                      onReply: null,
                      items: subagentSteps(s),
                      live: subagentRunning(s),
                      header: _Head(chat, s),
                      footer: _result(context, s),
                    ),
            ),
            if (s != null && s.call.agentId.isNotEmpty && !chat.archived)
              _ToSubagentBox(
                key: ValueKey(s.call.id),
                chat: chat,
                daemon: daemon,
                s: s,
              ),
          ],
        );
      },
    );
  }

  Widget? _result(BuildContext context, SubagentRun s) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final result = s.call.subagent.result;
    if (subagentRunning(s) || result.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Result',
            style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
          ),
          AgentMarkdown(result),
        ],
      ),
    );
  }
}

/// The subagent's prompt in a box, folded to a few lines, then its model
/// and state; and, when its steps weren't kept, a line saying so.
class _Head extends StatefulWidget {
  const new(this.chat, this.s);

  final ChatState chat;
  final SubagentRun s;

  @override
  State<_Head> createState() => _HeadState();
}

class _HeadState extends State<_Head> {
  static const _folded = 5; // lines
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final s = widget.s;
    final call = s.call;
    final small = theme.ui(t.textMuted, size: 12);
    final runs = subagentModel(widget.chat, s);
    // A replayed subagent (the daemon didn't see it start) with no steps:
    // the agent didn't send them again.
    final unknown =
        call.subagent.started == 0 &&
        !subagentRunning(s) &&
        subagentSteps(s)
            .every((it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (call.prompt.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: box(t.borderSubtle, fill: t.raised),
              child: LayoutBuilder(
                builder: (context, box) {
                  final style = theme.ui(t.text, size: 12.5);
                  final painter = TextPainter(
                    text: TextSpan(text: call.prompt, style: style),
                    maxLines: _folded,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: box.maxWidth);
                  final folds = painter.didExceedMaxLines;
                  painter.dispose();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.prompt,
                        style: style,
                        maxLines: _open ? null : _folded,
                        overflow: _open ? null : TextOverflow.fade,
                      ),
                      if (folds)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: LinkText(
                            _open ? 'Show less' : 'Show more',
                            size: 12,
                            onTap: () => setState(() => _open = !_open),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Model ', style: small),
                  TextSpan(text: settingText(runs.model)),
                  TextSpan(text: '  ·  Effort ', style: small),
                  TextSpan(text: settingText(runs.effort)),
                ],
              ),
              style: theme.ui(t.text, size: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              spacing: 6,
              children: [
                Flexible(
                  child: subagentShine(s, SubagentState(s, style: small)),
                ),
                subagentMark(s),
              ],
            ),
          ),
          if (unknown)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Its steps${call.subagent.result.isEmpty ? ' and report' : ''} '
                'weren’t kept: the chat reopened after it ran.',
                style: small,
              ),
            ),
        ],
      ),
    );
  }
}

/// A box for a message to the subagent. The agent passes it on (Claude's
/// SendMessage), which runs a finished subagent again: as any message,
/// it goes into a running turn, or starts one.
class _ToSubagentBox extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.s,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final SubagentRun s;

  @override
  State<_ToSubagentBox> createState() => _ToSubagentBoxState();
}

class _ToSubagentBoxState extends State<_ToSubagentBox> {
  // On the chat's draft: kept when the pane closes, and on disk.
  late final TextEditingController _text = widget.chat.draft.subagentBox(
    widget.s.call.id,
  );
  bool _sending = false;

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await tryOrShow(context, () async {
      await widget.daemon.sendPrompt(
        SendPromptRequest(
          chatId: widget.chat.id,
          text: text,
          queue: true,
          toSubagent: widget.s.call.id,
        ),
      );
      _text.clear();
    });
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: EnterSends(
              controller: _text,
              onEnter: _send,
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 6,
                style: theme.ui(t.text),
                decoration: InputDecoration.collapsed(
                  hintText:
                      'Message ${widget.s.call.agent} through '
                      '${widget.chat.agentName}',
                  hintStyle: theme.ui(t.textMuted),
                ),
              ),
            ),
          ),
          IconTap(
            Icons.arrow_upward,
            tooltip: 'Send',
            size: 15,
            onTap: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
