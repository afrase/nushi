import 'package:flutter/material.dart';

import 'chat.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';
import 'status.dart';
import 'subagents.dart';
import 'theme/theme.dart';
import 'widgets.dart';

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

/// A spinner while it runs, a check once done, nothing otherwise.
Widget shellMark(BuildContext context, Item it) {
  final t = NushiTheme.of(context).t;
  return switch (it.shell.state) {
    'running' => const SizedBox.square(
      dimension: 10,
      child: CircularProgressIndicator(strokeWidth: 1.5),
    ),
    'done' => Icon(Icons.check, size: 13, color: t.done),
    _ => const SizedBox.shrink(),
  };
}

/// [shellState] in [style], red once it failed, ticking while it runs.
Widget shellStateText(BuildContext context, Item it, TextStyle style) =>
    LiveText(
      () => shellState(it),
      live: shellRunning(it),
      style: it.shell.state == 'failed'
          ? style.copyWith(color: NushiTheme.of(context).t.crashed)
          : style,
    );

/// A background command beside the chat, in place of the details panel:
/// the command, its state, and its output as far as the daemon has read
/// it. Back and × as in SubagentPane.
class ShellPane extends StatelessWidget {
  const new({
    super.key,
    required this.chat,
    required this.id,
    required this.onBack,
    required this.onClose,
  });

  final ChatState chat;
  final String id; // the tool call that started it
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
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
                              shellMark(context, it),
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
