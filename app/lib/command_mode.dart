import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/preview.dart' show baseName;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Command mode (ADR 0148): a box whose text starts with `!` runs the rest
/// as a command in a terminal of the chat's, its output in a card over the
/// box for the next message, rather than sending it. The desktop app's
/// only: on the phone (a touch screen, the web build) `!x` is a message,
/// as before.

/// Whether the box in [context] has a command mode: the desktop app's.
bool commandsHere(BuildContext context) => !kIsWeb && !TouchTargets.of(context);

/// Whether [text] puts a box that has a command mode in it: its first
/// character is `!` (a space before it makes it a message).
bool isCommandText(String text) => text.startsWith('!');

/// [text], a sent message's, as it goes back in a box with a command mode
/// (Up, a message taken back): one starting with `!` went as a message (a
/// space before it, trimmed as it was sent, or from the phone), so it gets
/// a space first and stays one, never a command run by the send key.
String asMessage(String text) => isCommandText(text) ? ' $text' : text;

/// The command in [text], a box's in command mode: what follows the `!`,
/// trimmed; empty for `!` alone or with spaces, which runs nothing.
String commandIn(String text) => text.substring(1).trim();

/// Whether [daemon] can run a command (`commandTerminalApi`): an older one
/// has no command terminal, and the box runs nothing there.
bool canRunCommands(Daemon daemon) => daemon.daemonApi >= commandTerminalApi;

/// What the box says when its daemon is too old to run a command: mostly
/// one an update left running until things are idle (ADR 0056), so it
/// names the daemon, not an update of Nushi the user just made.
const oldDaemonWords = 'Running commands needs a newer daemon';

/// Runs the command in [chat]'s box: out of the box, into a card over it
/// (`CommandRuns.command`), at once, whether or not the agent works. An
/// empty command runs nothing; a daemon too old for it runs nothing and
/// says so. The rest of the draft stays for the next message. Should the
/// terminal not open, the command goes back in the box, if it's empty.
Future<void> runBoxCommand(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  final box = chat.draft.text;
  final typed = box.text;
  final command = commandIn(typed);
  if (command.isEmpty) return;
  if (!canRunCommands(daemon)) {
    showError(context, oldDaemonWords);
    return;
  }
  box.clear();
  try {
    await chat.runs.command(daemon.terminals, command);
  } on Object catch (e) {
    if (box.text.isEmpty) {
      box.value = TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      );
    }
    if (context.mounted) showError(context, e);
  }
}

/// The text of a box in command mode: its `!` drawn as the mark that says
/// "command" (a chip on the accent with a terminal glyph, in the `!`'s
/// place, as tall as a line at most, so the box keeps its height), the
/// command in the code font. One span per character of the text, so the
/// caret and the selection go where they would.
TextSpan commandSpan(BuildContext context, String text, TextStyle? style) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final base = style ?? const TextStyle();
  final mono = TextStyle(
    fontFamily: theme.codeFamily,
    fontFamilyFallback: theme.codeFallback,
    fontSize: (base.fontSize ?? 13) * 0.92,
    color: t.text,
    fontFeatures: const [
      FontFeature.disable('liga'),
      FontFeature.disable('calt'),
    ],
  );
  return TextSpan(
    style: style,
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: CommandMark(t),
        ),
      ),
      TextSpan(text: text.substring(1), style: mono),
    ],
  );
}

/// The mark at a command's start: a terminal's glyph on the accent's
/// solid fill.
class CommandMark extends StatelessWidget {
  const new(this.t, {super.key});

  final Tokens t;

  @override
  Widget build(BuildContext context) => Container(
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: t.accent,
      borderRadius: BorderRadius.circular(NushiTheme.tag),
    ),
    child: Icon(Icons.terminal, size: 13, color: t.onAccent),
  );
}

/// The box's look in command mode, over its own: code's sunk fill and a
/// ring in the accent all round, drawn inside its edge so nothing in it
/// moves.
({Color fill, Decoration ring}) commandBoxLook(Tokens t) => (
  fill: t.codeBlock,
  ring: BoxDecoration(
    borderRadius: BorderRadius.circular(NushiTheme.panel),
    border: Border.all(color: t.accent, width: 2),
  ),
);

/// What the box's row says in command mode, in the pickers' place: where
/// the command runs and the key that runs it; with a daemon too old for
/// commands, that it can't.
class CommandLine extends StatelessWidget {
  const new(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    if (!canRunCommands(daemon)) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: NotePill(oldDaemonWords, tone: NoteTone.needs),
      );
    }
    return Row(
      spacing: 8,
      children: [
        Flexible(
          child: Text(
            'Runs in ${baseName(chat.folder)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textSecondary, weight: FontWeight.w500),
          ),
        ),
        keyHint(context, sendKeyLabel),
      ],
    );
  }
}

/// The box's Run, in Send's place in command mode, while a turn runs too:
/// round on the accent, a run's ▷; off for an empty command or a daemon
/// too old for one.
Widget runButton(String text, Daemon daemon, VoidCallback onRun) => RoundButton(
  kind: RoundKind.primary,
  tooltip: withKey('Run', sendKeyLabel),
  onPressed: commandIn(text).isEmpty || !canRunCommands(daemon) ? null : onRun,
  glyph: (color) => Icon(Icons.play_arrow, size: 18, color: color),
);
