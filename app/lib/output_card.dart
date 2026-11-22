import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/images.dart' show RemoveBadge;
import 'package:nushi/run_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A run's output in the composer, to go with the next message: a ▷ run's
/// ("Output of `cmd` · exit 0 · 42 lines") or a command's typed after `!`
/// ("! cmd"), which shows from its start: running, the spinner, Show
/// (its terminal) and ✕ (stops it, and the card goes); done, its exit and
/// lines; failed (an exit not 0), on the failed state's fill with its mark
/// and its exit in red. A click on one done shows what goes; hovering it
/// shows a button that removes it.
class OutputCard extends StatelessWidget {
  const new(
    this.output, {
    required this.onRemove,
    required this.chat,
    required this.daemon,
    super.key,
  });

  final RunOutput output;
  final VoidCallback onRemove;
  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => switch (output.run) {
    null => _card(context),
    final run => ListenableBuilder(
      listenable: run,
      builder: (context, _) => _card(context),
    ),
  };

  void _show(CodeRun run) {
    run.shown = true;
    daemon.terminals.show(chat.id, run.terminalId);
    if (!terminalChats.value.contains(chat.id)) toggleTerminal(chat.id);
  }

  Widget _card(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final o = output;
    final run = o.run;
    final running = !outputDone(o);
    final failed = !running && o.exit != 0;
    final muted = theme.ui(t.textMuted, size: 11.5);
    final command = Text(
      o.command.split('\n').first,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.code(t.text, size: 11.5),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (running)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox.square(
              dimension: 12,
              child: Spinner(color: t.accent),
            ),
          )
        else if (failed)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(Icons.error, size: 13, color: t.crashed),
          ),
        if (run == null)
          Text('Output of ', style: muted)
        else
          Text('! ', style: theme.code(t.textMuted, size: 11.5)),
        // The command shortened to fit, never how it went.
        Flexible(child: command),
        if (running && run != null) ...[
          const SizedBox(width: 6),
          if (run.terminalId.isNotEmpty)
            IconTap.line(
              LineIcon.terminal,
              size: 13,
              padding: 3,
              tooltip: 'Show in the terminal',
              onTap: () => _show(run),
            ),
          IconTap(
            Icons.close,
            size: 13,
            padding: 3,
            tooltip: 'Stop',
            onTap: () => tryOrShow(
              context,
              () => chat.runs.stopCommand(daemon.terminals, run),
            ),
          ),
        ] else ...[
          Text(' · ', style: muted),
          Text(
            'exit ${o.exit}',
            style: failed
                ? theme.ui(t.crashed, size: 11.5, weight: FontWeight.w600)
                : muted,
          ),
          Text(
            ' · ${o.lines} ${o.lines == 1 ? 'line' : 'lines'}',
            style: muted,
          ),
        ],
      ],
    );
    final box = Container(
      key: ValueKey('output-${o.key}'),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: failed ? t.crashedSoft : t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: running
          ? Padding(padding: const EdgeInsets.fromLTRB(8, 2, 3, 2), child: row)
          : Tap(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _OutputDialog(o),
              ),
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
              child: row,
            ),
    );
    if (running) return box;
    return Hover(
      builder: (context, {required hover}) => Stack(
        clipBehavior: Clip.none,
        children: [box, if (hover) RemoveBadge(onRemove)],
      ),
    );
  }
}

/// What a done card sends: its command, and its output as it goes.
class _OutputDialog extends StatelessWidget {
  const new(this.output);

  final RunOutput output;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final o = output;
    final sent = o.text.isEmpty ? 0 : '\n'.allMatches(o.text).length + 1;
    return nushiDialog(
      'Output',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            '${o.run == null ? r'$' : '!'} ${o.command}',
            style: theme.code(t.text, size: 12),
          ),
          if (sent < o.lines)
            Text(
              'Only its last $sent of ${o.lines} lines go with your message.',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.codeBlock,
                borderRadius: BorderRadius.circular(NushiTheme.control),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: SelectableText(
                  o.text.isEmpty ? 'No output' : o.text,
                  style: theme.code(
                    o.text.isEmpty ? t.textMuted : t.text,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      [
        Button(
          label: 'Close',
          kind: ButtonKind.primary,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
