import 'package:flutter/material.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Background tasks widget, as Claude Code's rail lists them:
/// the chat's running subagents and background commands, a row each (its
/// icon, its task or command, how long it has run, its Stop); then "n
/// finished", which opens the others, the latest first: they stay, to go
/// back into what one did. A row's tooltip says what it's doing, or how it
/// ended. Null (no widget) before the chat has any.
PanelWidget? backgroundTasksWidget(ChatState chat, Daemon daemon) {
  final subs = subagentsOf(chat.withRunning);
  final commands = backgroundCommandsOf(chat.withRunning);
  final running = [
    for (final s in subs.where(subagentRunning)) _AgentRow(chat, daemon, s),
    for (final it in commands.where(commandRunning))
      _CommandRow(chat, daemon, it),
  ];
  final rest = [
    for (final s in subs.reversed.where((s) => !subagentRunning(s)))
      _AgentRow(chat, daemon, s),
    for (final it in commands.reversed.where((it) => !commandRunning(it)))
      _CommandRow(chat, daemon, it),
  ];
  if (running.isEmpty && rest.isEmpty) return null;
  // A command whose end isn't known didn't finish, as far as Nushi knows.
  final unknown = commands.any((it) => it.backgroundCommand.state == 'started');
  final more = '${rest.length} ${unknown ? 'earlier' : 'finished'}';
  return PanelWidget(
    title: 'Background tasks',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text(
          running.isEmpty ? more : '${running.length} running',
          style: theme.ui(theme.t.textMuted),
        );
      },
    ),
    rows: [
      for (final r in running) (null, r),
      if (rest.isNotEmpty) (null, MoreRows(more, rest, open: false)),
    ],
  );
}

/// A row's room for its Stop, kept on a finished one too, so the times
/// line up.
const _stopRoom = 22.0;

/// A task's row: [icon], [name] (which takes what's left), what [after] it
/// (a worktree's tag), [time], and [stop] while it runs; a click opens its
/// pane ([open]).
Widget _row(
  BuildContext context, {
  required IconData icon,
  required Widget name,
  required Widget time,
  required VoidCallback open,
  required String tooltip,
  Widget? after,
  Widget? stop,
}) {
  final t = NushiTheme.of(context).t;
  return Tap(
    onTap: open,
    tooltip: tooltip,
    tint: false,
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: SizedBox(
      height: _stopRoom,
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 15, color: t.textMuted),
          Expanded(child: name),
          ?after,
          time,
          SizedBox.square(
            dimension: _stopRoom,
            child: Center(child: stop),
          ),
        ],
      ),
    ),
  );
}

/// How long a task ran (or runs, ticking), from its [started] to its
/// [ended] (ms since the epoch, 0 when not seen); its [state] instead once
/// it ended otherwise than done, in red when it failed.
Widget _time(
  BuildContext context, {
  required int started,
  required int ended,
  required String state,
  required bool runs,
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  String text() {
    final since = msTime(started);
    final end = runs ? clock() : msTime(ended);
    if (!runs && state != 'done' && state != 'completed') return state;
    return since == null || end == null ? '' : elapsed(end.difference(since));
  }

  return LiveText(
    text,
    live: runs,
    style: theme.ui(state == 'failed' ? t.crashed : t.textMuted),
  );
}

/// A background command: the command, how long it ran; a click opens its
/// pane.
class _CommandRow extends StatelessWidget {
  const new(this.chat, this.daemon, this.it);

  final ChatState chat;
  final Daemon daemon;
  final Item it;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final sh = it.backgroundCommand;
    final runs = commandRunning(it);
    final last = lastLine(it);
    return _row(
      context,
      icon: Icons.terminal,
      name: Text(
        it.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.code(theme.t.text, size: 12),
      ),
      time: _time(
        context,
        started: sh.started.toInt(),
        ended: sh.ended.toInt(),
        // "done" with its exit code: the code says how it went.
        state: sh.state == 'done' || sh.state == 'running' ? 'done' : sh.state,
        runs: runs,
      ),
      open: () => chat.pane.value = it.id,
      tooltip: [commandState(it), if (last.isNotEmpty) last].join('\n'),
      stop: runs ? stopButton(context, daemon, chat, it.id) : null,
    );
  }
}

/// A subagent: its task, the branch of the worktree it works in, if it has
/// one, how long it ran; a click opens its pane.
class _AgentRow extends StatelessWidget {
  const new(this.chat, this.daemon, this.s);

  final ChatState chat;
  final Daemon daemon;
  final SubagentRun s;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final runs = subagentModel(chat, s);
    final sa = s.call.subagent;
    final tag = chat.related.tagFor(s.call.id);
    return _row(
      context,
      icon: Icons.smart_toy_outlined,
      name: Text(
        s.call.title.isEmpty ? s.call.agent : s.call.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.ui(theme.t.text),
      ),
      after: tag.isEmpty
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: WorktreeTag(tag),
            ),
      time: _time(
        context,
        started: sa.started.toInt(),
        ended: sa.ended.toInt(),
        state: sa.state,
        runs: subagentRunning(s),
      ),
      open: () => chat.pane.value = s.call.id,
      tooltip: [
        if (s.call.agent.isNotEmpty) s.call.agent,
        subagentState(s),
        'Model ${settingText(runs.model)}, effort ${settingText(runs.effort)}',
      ].join('\n'),
      stop: subagentStoppable(s)
          ? stopButton(context, daemon, chat, s.call.id)
          : null,
    );
  }
}

/// "n finished", a chevron before it, which opens to list them, [open] to
/// start with.
class MoreRows extends StatefulWidget {
  const new(this.label, this.rows, {required this.open, super.key});

  final String label;
  final List<Widget> rows;
  final bool open;

  @override
  State<MoreRows> createState() => _MoreRowsState();
}

class _MoreRowsState extends State<MoreRows> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          tint: false,
          padding: const EdgeInsets.symmetric(vertical: PanelType.rowGap),
          child: Row(
            spacing: 8,
            children: [
              SizedBox(width: 15, child: Chevron(open: _open)),
              Text(widget.label, style: theme.ui(t.textSecondary)),
            ],
          ),
        ),
        if (_open) ...widget.rows,
      ],
    );
  }
}
