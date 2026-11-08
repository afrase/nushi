import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';
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

/// [code], a fenced block of [language] in an agent's message, with ▷ to
/// run it in a terminal of [chat]'s when it's a shell's; null otherwise.
Widget? runnableBlock(
  String language,
  String code,
  MarkdownStyle style,
  ChatState chat,
  Daemon daemon,
) {
  final script = runnableScript(language, code);
  if (script == null) return null;
  return RunnableBlock(
    language: language,
    code: code,
    script: script,
    style: style,
    chat: chat,
    daemon: daemon,
  );
}

/// A shell block: ▷ in its bar types it into a terminal of the chat's,
/// a spinner while it runs (✕ under the pointer stops it), and under it a
/// line with its newest output, its exit once it ends, and `>_`, which
/// shows its terminal (ADR 0084).
class RunnableBlock extends StatelessWidget {
  const new({
    required this.language,
    required this.code,
    required this.script,
    required this.style,
    required this.chat,
    required this.daemon,
    super.key,
  });

  final String language;
  final String code;

  /// What ▷ types ([runnableScript]).
  final String script;
  final MarkdownStyle style;
  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final run = chat.runs.of(code);
    final terms = daemon.terminals;
    return ListenableBuilder(
      listenable: Listenable.merge([run, terms]),
      builder: (context, _) {
        final term = terms
            .of(chat.id)
            ?.where((t) => t.id == run.terminalId)
            .firstOrNull;
        final busy = run.busy(term);
        return CodeBlockView(
          language: language,
          code: code,
          style: style,
          actions: [
            if (busy)
              IconTap.working(
                (size, color) => SizedBox.square(
                  dimension: size - 2,
                  child: Spinner(color: color),
                ),
                Icons.close,
                size: 13,
                padding: 4,
                color: style.muted,
                tooltip: 'Running — click to cancel',
                onTap: () =>
                    tryOrShow(context, () => chat.runs.stop(terms, run)),
              )
            else
              IconTap(
                Icons.play_arrow,
                size: 15,
                padding: 3,
                color: style.muted,
                tooltip:
                    'Run, and send its output to ${chat.agentName} with '
                    'your next message',
                onTap: () => tryOrShow(
                  context,
                  () => chat.runs.start(terms, run, script),
                ),
              ),
          ],
          footer: run.state == RunState.idle
              ? null
              : _RunLine(run, busy: busy, chat: chat, daemon: daemon),
        );
      },
    );
  }
}

/// A run's output waiting in the composer, to go with the next message:
/// "Output of `cmd` · exit 0 · 42 lines"; hovering it shows a button that
/// removes it.
class OutputCard extends StatelessWidget {
  const new(this.output, {required this.onRemove, super.key});

  final RunOutput output;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final o = output;
    final muted = theme.ui(t.textMuted, size: 11.5);
    return Hover(
      builder: (context, {required hover}) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            decoration: box(
              t.borderSubtle,
              fill: t.raised,
              radius: NushiTheme.control,
            ),
            // The command shortened to fit, never how it went.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Output of ', style: muted),
                Flexible(
                  child: Text(
                    o.command,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.code(t.text, size: 11.5),
                  ),
                ),
                Text(
                  ' · exit ${o.exit} · ${o.lines} '
                  '${o.lines == 1 ? 'line' : 'lines'}',
                  style: muted,
                ),
              ],
            ),
          ),
          if (hover) RemoveBadge(onRemove),
        ],
      ),
    );
  }
}

/// The line under a run's block: its newest output, its exit, `>_`.
class _RunLine extends StatelessWidget {
  const new(
    this.run, {
    required this.busy,
    required this.chat,
    required this.daemon,
  });

  final CodeRun run;
  final bool busy;
  final ChatState chat;
  final Daemon daemon;

  void _show() {
    if (run.terminalId.isEmpty) return;
    daemon.terminals.show(chat.id, run.terminalId);
    if (!terminalChats.value.contains(chat.id)) toggleTerminal(chat.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.code(t.textMuted, size: 11.5);
    final exit = run.exit;
    final line = run.lastLine.isNotEmpty
        ? run.lastLine
        : busy
        ? 'Running…'
        : 'No output';
    return SelectionContainer.disabled(
      child: Container(
        height: 26,
        padding: const EdgeInsets.only(left: 10, right: 2),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.borderSubtle)),
        ),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                line,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            if (exit != null && !busy)
              Text(
                'exit $exit',
                style: exit == 0 ? muted : muted.copyWith(color: t.crashed),
              ),
            if (run.terminalId.isNotEmpty)
              IconTap.line(
                LineIcon.terminal,
                size: 13,
                padding: 4,
                tooltip: 'Show in the terminal',
                onTap: _show,
              ),
          ],
        ),
      ),
    );
  }
}
