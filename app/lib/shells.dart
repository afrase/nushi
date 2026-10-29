import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The tool calls that left a command running in the background, in order.
List<Item> shellsOf(List<Item> items) => [
  for (final it in items)
    if (it.hasShell()) it,
];

bool shellRunning(Item it) => it.shell.state == 'running';

DateTime? _time(int ms) =>
    ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

/// A background command's state in a few words: "running · 12s", "done ·
/// exited with code 0 · 15s", "stopped", or "started" (and how
/// long ago, when the daemon saw it) when its end can't be known.
String shellState(Item it) {
  final sh = it.shell;
  final since = _time(sh.started.toInt());
  final end = shellRunning(it) ? DateTime.now() : _time(sh.ended.toInt());
  return switch (sh.state) {
    'started' => [
      'started',
      if (since != null) '${elapsed(DateTime.now().difference(since))} ago',
    ].join(' '),
    _ => [
      sh.state,
      if (sh.end.isNotEmpty && sh.state != 'stopped') sh.end,
      if (since != null && end != null) elapsed(end.difference(since)),
    ].join(' · '),
  };
}

/// The command's last line of output, if it wrote any.
String lastLine(Item it) => it.shell.output.trimRight().split('\n').last.trim();

/// The command's [TaskMark]: room while it runs (its words shine), a check
/// that draws as it's done, a red mark when it failed.
Widget shellMark(Item it) => TaskMark(it.shell.state);

/// [shellState] in [style], red once it failed, ticking and shining while
/// it runs.
Widget shellStateText(BuildContext context, Item it, TextStyle style) => Align(
  alignment: Alignment.centerLeft,
  child: Shine(
    on: shellRunning(it),
    child: LiveText(
      () => shellState(it),
      live: shellRunning(it),
      style: it.shell.state == 'failed'
          ? style.copyWith(color: NushiTheme.of(context).t.crashed)
          : style,
    ),
  ),
);

/// A background command beside the chat, left of the details panel: the
/// command, its state, and its output as far as the daemon has read it.
/// Stop stops it while it runs; × closes it.
class ShellPane extends StatelessWidget {
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
      listenable: Listenable.merge([chat, subagentWide]),
      builder: (context, _) {
        final it = shellsOf(chat.items).where((it) => it.id == id).firstOrNull;
        final wide = subagentWide.value;
        final small = theme.ui(t.textMuted, size: 12);
        final code = theme.code(t.text, size: 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: t.raised,
                border: Border(bottom: BorderSide(color: t.borderSubtle)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
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
                  if (it != null && shellRunning(it))
                    stopButton(context, daemon, chat, id),
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
                                child: shellStateText(context, it, small),
                              ),
                              shellMark(it),
                            ],
                          ),
                          if (it.shell.state == 'started')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'It may still run: its agent stopped first.',
                                style: small,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            shellRunning(it) ? 'Output so far' : 'Output',
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
                              it.shell.output.isNotEmpty
                                  ? it.shell.output
                                  : shellRunning(it)
                                  ? 'None yet.'
                                  : 'None.',
                              style: it.shell.output.isEmpty ? small : code,
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
