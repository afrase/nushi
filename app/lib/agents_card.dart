import 'package:flutter/material.dart';

import 'chat.dart';
import 'panel_cards.dart';
import 'subagents.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The panel's Agents card: the chat's running subagents, each with its
/// state and current step, then a quiet "n finished" line that opens the
/// finished ones. Null (no card) when the chat never had one.
PanelCard? agentsCard(ChatState chat) {
  final subs = subagentsOf(chat.items);
  if (subs.isEmpty) return null;
  final running = subs.where(subagentRunning).toList();
  final done = subs.where((s) => !subagentRunning(s)).toList();
  return PanelCard(
    title: 'Agents',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text(
          running.isEmpty
              ? '${done.length} finished'
              : '${running.length} running',
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [
      for (final s in running) (null, _AgentRow(chat, s)),
      if (done.isNotEmpty) (null, _Finished(chat, done)),
    ],
  );
}

/// A subagent: its type and task, and its state under them; a click shows
/// it in the chat.
class _AgentRow extends StatelessWidget {
  const _AgentRow(this.chat, this.s);

  final ChatState chat;
  final SubagentRun s;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Tap(
      onTap: () => chat.reveal.value = s.call.id,
      tooltip: 'Show it in the chat',
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.call.agent}: ${s.call.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, size: 12),
          ),
          Text(
            subagentState(s),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(
              s.call.status == 'failed' ? t.crashed : t.textMuted,
              size: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// "n finished", which opens to list them.
class _Finished extends StatefulWidget {
  const _Finished(this.chat, this.done);

  final ChatState chat;
  final List<SubagentRun> done;

  @override
  State<_Finished> createState() => _FinishedState();
}

class _FinishedState extends State<_Finished> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            spacing: 4,
            children: [
              Text(
                '${widget.done.length} finished',
                style: theme.ui(t.textMuted, size: 12),
              ),
              Chevron(_open),
            ],
          ),
        ),
        if (_open)
          for (final s in widget.done) _AgentRow(widget.chat, s),
      ],
    );
  }
}
