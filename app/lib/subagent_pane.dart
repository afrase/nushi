import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'settings.dart';
import 'subagents.dart';
import 'theme/theme.dart';
import 'transcript.dart';
import 'widgets.dart';

/// A subagent beside the chat, in place of the details panel: its prompt
/// (folded), its model and state, then its steps as they come, and its
/// result. Back ([onBack], when the panel was showing) returns to the
/// panel's cards; × closes the side panel.
class SubagentPane extends StatelessWidget {
  const new({
    super.key,
    required this.chat,
    required this.daemon,
    required this.id,
    required this.onBack,
    required this.onClose,
  });

  final ChatState chat;
  final Daemon daemon;
  final String id; // the subagent's call
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return ListenableBuilder(
      listenable: Listenable.merge([chat, subagentWide]),
      builder: (context, _) {
        final s = subagentsOf(chat.items)
            .where((s) => s.call.id == id)
            .firstOrNull;
        final wide = subagentWide.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 34,
              padding: EdgeInsets.only(left: onBack == null ? 14 : 4, right: 4),
              decoration: BoxDecoration(
                color: t.raised,
                border: Border(bottom: BorderSide(color: t.borderSubtle)),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconTap(
                      Icons.arrow_back,
                      tooltip: 'Back to the panel',
                      size: 15,
                      onTap: onBack,
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: s == null
                        ? const SizedBox.shrink()
                        : subagentName(context, s, size: 12),
                  ),
                  IconTap(
                    wide ? Icons.close_fullscreen : Icons.open_in_full,
                    tooltip: wide ? 'Narrower' : 'Wider',
                    size: 13,
                    onTap: () => subagentWide.value = !wide,
                  ),
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
              _Relay(chat: chat, daemon: daemon, s: s),
          ],
        );
      },
    );
  }

  Widget? _result(BuildContext context, SubagentRun s) {
    final theme = NushiTheme.of(context), t = theme.t;
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
    final theme = NushiTheme.of(context), t = theme.t;
    final s = widget.s, call = s.call;
    final small = theme.ui(t.textMuted, size: 12);
    final runs = subagentModel(widget.chat, s);
    // A replayed subagent (the daemon didn't see it start) with no steps:
    // the agent didn't send them again.
    final unknown =
        call.subagent.started == 0 &&
        !subagentRunning(s) &&
        subagentSteps(s).isEmpty;
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
                  final folds = (TextPainter(
                    text: TextSpan(text: call.prompt, style: style),
                    maxLines: _folded,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: box.maxWidth)).didExceedMaxLines;
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
                        Tap(
                          onTap: () => setState(() => _open = !_open),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _open ? 'Show less' : 'Show more',
                            style: theme.ui(t.accent, size: 12),
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
                Flexible(child: SubagentState(s, style: small)),
                subagentMark(context, s),
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
class _Relay extends StatefulWidget {
  const new({required this.chat, required this.daemon, required this.s});

  final ChatState chat;
  final Daemon daemon;
  final SubagentRun s;

  @override
  State<_Relay> createState() => _RelayState();
}

class _RelayState extends State<_Relay> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await tryOrShow(context, () async {
      await widget.daemon.client.sendPrompt(
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
    final theme = NushiTheme.of(context), t = theme.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _send,
              },
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
