import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/shells.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Background tasks card: the chat's running subagents, each
/// with its state and current step, and its running background commands;
/// then a quiet "n finished" line that opens the others. Null (no card)
/// when the chat never had one.
PanelCard? agentsCard(ChatState chat) {
  final subs = subagentsOf(chat.items), shells = shellsOf(chat.items);
  if (subs.isEmpty && shells.isEmpty) return null;
  final running = [
    for (final s in subs.where(subagentRunning)) _AgentRow(chat, s),
    for (final it in shells.where(shellRunning)) _ShellRow(chat, it),
  ];
  final rest = [
    for (final s in subs.where((s) => !subagentRunning(s))) _AgentRow(chat, s),
    for (final it in shells.where((it) => !shellRunning(it)))
      _ShellRow(chat, it),
  ];
  // A command whose end isn't known didn't finish, as far as Nushi knows.
  final unknown = shells.any((it) => it.shell.state == 'started');
  final more = '${rest.length} ${unknown ? 'earlier' : 'finished'}';
  return PanelCard(
    title: 'Background tasks',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text(
          running.isEmpty ? more : '${running.length} running',
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [
      for (final r in running) (null, r),
      if (rest.isNotEmpty) (null, _Finished(more, rest)),
    ],
  );
}

/// A background command: the command, its state, and the last line it
/// wrote; a click opens its pane.
class _ShellRow extends StatelessWidget {
  const new(this.chat, this.it);

  final ChatState chat;
  final Item it;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final last = lastLine(it);
    return Tap(
      onTap: () => chat.pane.value = it.id,
      tooltip: 'Open its output',
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\$ ${it.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.text, size: 11.5),
          ),
          shellStateText(context, it, theme.ui(t.textMuted, size: 11.5)),
          if (last.isNotEmpty)
            Text(
              last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.code(t.textMuted, size: 10.5),
            ),
        ],
      ),
    );
  }
}

/// A subagent: its type and task, and its state under them; a click opens
/// its pane.
class _AgentRow extends StatelessWidget {
  const new(this.chat, this.s);

  final ChatState chat;
  final SubagentRun s;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final runs = subagentModel(chat, s);
    return Tap(
      onTap: () => chat.pane.value = s.call.id,
      tooltip:
          'Model ${settingText(runs.model)}, effort '
          '${settingText(runs.effort)}',
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Expanded(
                child: Text(
                  '${s.call.agent}: ${s.call.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, size: 12),
                ),
              ),
              // Its model and effort, as a tag.
              Text(
                [
                  for (final v in [runs.model, runs.effort])
                    if (v.name.isNotEmpty) v.name,
                ].join(' · '),
                style: theme.code(t.textMuted, size: 10.5),
              ),
            ],
          ),
          SubagentState(s, style: theme.ui(t.textMuted, size: 11.5)),
        ],
      ),
    );
  }
}

/// "n finished", which opens to list them.
class _Finished extends StatefulWidget {
  const new(this.label, this.rows);

  final String label;
  final List<Widget> rows;

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
              Text(widget.label, style: theme.ui(t.textMuted, size: 12)),
              Chevron(open: _open),
            ],
          ),
        ),
        if (_open) ...widget.rows,
      ],
    );
  }
}
