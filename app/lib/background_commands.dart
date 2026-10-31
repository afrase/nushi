import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The tool calls that left a command running in the background, in order.
List<Item> backgroundCommandsOf(List<Item> items) => [
  for (final it in items)
    if (it.hasBackgroundCommand()) it,
];

bool commandRunning(Item it) => it.backgroundCommand.state == 'running';

/// A background command's state in a few words: "running · 12s", "done ·
/// exited with code 0 · 15s", "stopped", or "started" (and how
/// long ago, when the daemon saw it) when its end can't be known.
String commandState(Item it) {
  final sh = it.backgroundCommand;
  final since = msTime(sh.started.toInt());
  final end = commandRunning(it) ? DateTime.now() : msTime(sh.ended.toInt());
  return switch (sh.state) {
    'started' => [
      'started',
      if (since != null) '${elapsed(clock().difference(since))} ago',
    ].join(' '),
    _ => [
      sh.state,
      if (sh.end.isNotEmpty && sh.state != 'stopped') sh.end,
      if (since != null && end != null) elapsed(end.difference(since)),
    ].join(' · '),
  };
}

/// The command's last line of output, if it wrote any.
String lastLine(Item it) =>
    it.backgroundCommand.output.trimRight().split('\n').last.trim();

/// The command's [TaskMark]: room while it runs (its words shine), a check
/// that draws as it's done, a red mark when it failed.
Widget commandMark(Item it) => TaskMark(it.backgroundCommand.state);

/// [commandState] in [style], red once it failed, ticking and shining while
/// it runs.
Widget commandStateText(BuildContext context, Item it, TextStyle style) =>
    Align(
      alignment: Alignment.centerLeft,
      child: Shine(
        on: commandRunning(it),
        child: LiveText(
          () => commandState(it),
          live: commandRunning(it),
          style: it.backgroundCommand.state == 'failed'
              ? style.copyWith(color: NushiTheme.of(context).t.crashed)
              : style,
        ),
      ),
    );

/// A background command beside the chat, left of the details panel: the
/// command, its state, and its output as far as the daemon has read it.
/// Stop stops it while it runs; × closes it.
class BackgroundCommandPane extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.id,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String id; // the tool call that started it
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final it = backgroundCommandsOf(chat.items)
            .where((it) => it.id == id)
            .firstOrNull;
        final small = theme.ui(t.textMuted, size: 12);
        final code = theme.code(t.text, size: 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaneHeader(
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 14, color: t.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      it?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: code,
                    ),
                  ),
                  if (it != null && commandRunning(it))
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
              child: it == null
                  ? Center(
                      child: Text(
                        'This command is no longer in the chat.',
                        style: small,
                      ),
                    )
                  : SelectionArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: box(t.borderSubtle, fill: t.raised),
                            child: Text('\$ ${it.title}', style: code),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            spacing: 6,
                            children: [
                              Flexible(
                                child: commandStateText(context, it, small),
                              ),
                              commandMark(it),
                            ],
                          ),
                          if (it.backgroundCommand.state == 'started')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'It may still run: its agent stopped first.',
                                style: small,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            commandRunning(it) ? 'Output so far' : 'Output',
                            style: theme.ui(
                              t.textSecondary,
                              size: 12,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: box(t.borderSubtle, fill: t.base),
                            child: Text(
                              it.backgroundCommand.output.isNotEmpty
                                  ? it.backgroundCommand.output
                                  : commandRunning(it)
                                  ? 'None yet.'
                                  : 'None.',
                              style: it.backgroundCommand.output.isEmpty
                                  ? small
                                  : code,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
