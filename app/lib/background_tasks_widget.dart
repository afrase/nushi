import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/shells.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Background tasks widget: the chat's running subagents, each
/// with its state and current step, and its running background commands;
/// then a quiet "n finished" line that opens the others. Under the pointer,
/// a running one shows its Stop. Null (no widget) while none runs: those
/// that ended are in the transcript.
PanelWidget? backgroundTasksWidget(ChatState chat, Daemon daemon) {
  final subs = subagentsOf(chat.items);
  final shells = shellsOf(chat.items);
  final running = [
    for (final s in subs.where(subagentRunning)) _AgentRow(chat, daemon, s),
    for (final it in shells.where(shellRunning)) _ShellRow(chat, daemon, it),
  ];
  if (running.isEmpty) return null;
  final rest = [
    for (final s in subs.where((s) => !subagentRunning(s)))
      _AgentRow(chat, daemon, s),
    for (final it in shells.where((it) => !shellRunning(it)))
      _ShellRow(chat, daemon, it),
  ];
  // A command whose end isn't known didn't finish, as far as Nushi knows.
  final unknown = shells.any((it) => it.backgroundCommand.state == 'started');
  final more = '${rest.length} ${unknown ? 'earlier' : 'finished'}';
  return PanelWidget(
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

/// A row's first line, [first], with a Stop at its end when [stop].
Widget _line(Widget first, Widget? stop) => Row(
  spacing: 6,
  children: [
    Expanded(child: first),
    ?stop,
  ],
);

/// A background command: the command, its state, and the last line it
/// wrote; a click opens its pane.
class _ShellRow extends StatelessWidget {
  const new(this.chat, this.daemon, this.it);

  final ChatState chat;
  final Daemon daemon;
  final Item it;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final last = lastLine(it);
    return Hover(
      builder: (context, {required hover}) => Tap(
        onTap: () => chat.pane.value = it.id,
        tooltip: 'Open its output',
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              Text(
                '\$ ${it.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.text, size: 11.5),
              ),
              hover && shellRunning(it)
                  ? stopButton(context, daemon, chat, it.id, size: 12)
                  : null,
            ),
            shellStateText(context, it, theme.ui(t.textMuted, size: 11.5)),
            if (last.isNotEmpty)
              Shine(
                on: shellRunning(it),
                child: Text(
                  last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.textMuted, size: 10.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A subagent: its type and task, and its state under them; a click opens
/// its pane.
class _AgentRow extends StatelessWidget {
  const new(this.chat, this.daemon, this.s);

  final ChatState chat;
  final Daemon daemon;
  final SubagentRun s;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final runs = subagentModel(chat, s);
    return Hover(
      builder: (context, {required hover}) => Tap(
        onTap: () => chat.pane.value = s.call.id,
        tooltip:
            'Model ${settingText(runs.model)}, effort '
            '${settingText(runs.effort)}',
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
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
              hover && subagentStoppable(s)
                  ? stopButton(context, daemon, chat, s.call.id, size: 12)
                  : null,
            ),
            SubagentState(s, style: theme.ui(t.textMuted, size: 11.5)),
          ],
        ),
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
