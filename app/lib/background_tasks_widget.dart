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
/// icon, its task or command, how long it has run, its Stop), [shownTasks]
/// of them and "Show more" for the rest; then "n finished", a row of its
/// own, which opens the others, the latest first: they stay, to go back
/// into what one did. A row's tooltip says what it's doing, or how it
/// ended, and the worktree it works in. Null (no widget) before the chat
/// has any.
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
      for (final r in running.take(shownTasks)) (null, r),
      if (running.length > shownTasks)
        (
          null,
          ShowMore(
            running.skip(shownTasks).toList(),
            key: const ValueKey('running'),
          ),
        ),
      if (rest.isNotEmpty)
        (
          null,
          MoreRows(
            more,
            rest,
            open: false,
            icon: Icons.task_alt,
            key: const ValueKey('finished'),
          ),
        ),
    ],
  );
}

/// How many running tasks show before "Show more", as Claude's rail has it.
const shownTasks = 4;

/// A row's room for its Stop, kept on a finished one too, so the times
/// line up.
const _stopRoom = 22.0;

/// A task's row: [icon], [name] (which takes what's left), [time], and
/// [stop] while it runs; a click opens its pane ([open]).
Widget _row(
  BuildContext context, {
  required IconData icon,
  required Widget name,
  required Widget time,
  required VoidCallback open,
  required String tooltip,
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

/// A subagent: its task, how long it ran, and in its tooltip the branch of
/// the worktree it works in, if it has one (the name keeps the row's room,
/// as Claude's); a click opens its pane.
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
        if (tag.isNotEmpty) 'In the worktree $tag',
      ].join('\n'),
      stop: subagentStoppable(s)
          ? stopButton(context, daemon, chat, s.call.id)
          : null,
    );
  }
}

/// "n finished" (or "n more"), which opens to list them, [open] to start
/// with: a row as a task's, its [icon] where a task's is, or else a
/// chevron before it. The rows it opens keep a task row's room.
class MoreRows extends StatefulWidget {
  const new(this.label, this.rows, {required this.open, super.key, this.icon});

  final String label;
  final List<Widget> rows;
  final bool open;
  final IconData? icon;

  @override
  State<MoreRows> createState() => _MoreRowsState();
}

class _MoreRowsState extends State<MoreRows> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final icon = widget.icon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          tint: false,
          padding: EdgeInsets.symmetric(
            vertical: icon == null ? PanelType.rowGap : 1,
          ),
          child: SizedBox(
            height: icon == null ? null : _stopRoom,
            child: Row(
              spacing: 8,
              children: [
                SizedBox(
                  width: 15,
                  child: icon == null
                      ? Chevron(open: _open)
                      : Icon(icon, size: 15, color: t.textMuted),
                ),
                Text(
                  widget.label,
                  style: theme.ui(icon == null ? t.textSecondary : t.text),
                ),
              ],
            ),
          ),
        ),
        if (_open) ..._spaced(widget.rows),
      ],
    );
  }
}

/// [rows], each with the room the panel gives a row of its own.
Iterable<Widget> _spaced(List<Widget> rows) => [
  for (final r in rows)
    Padding(
      padding: const EdgeInsets.only(top: 2 * PanelType.rowGap),
      child: r,
    ),
];

/// The rows past the first few, shown by "Show more" in place and folded
/// again by "Show less", as Claude's rail and the Artifacts widget have it.
class ShowMore extends StatefulWidget {
  const new(this.rows, {super.key});

  final List<Widget> rows;

  @override
  State<ShowMore> createState() => _ShowMoreState();
}

class _ShowMoreState extends State<ShowMore> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_open) ...[
          for (final r in widget.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 2 * PanelType.rowGap),
              child: r,
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: () => setState(() => _open = !_open),
            tint: false,
            child: Text(
              _open ? 'Show less' : 'Show more',
              style: theme.ui(theme.t.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
