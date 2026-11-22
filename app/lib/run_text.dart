import 'dart:convert';

import 'package:nushi/code_runs.dart';

/// The fences whose blocks run: a shell's.
const shellLanguages = {'bash', 'sh', 'shell', 'zsh', 'console', 'terminal'};

final _prompt = RegExp(r'^[$%] ');

/// Whether [code] holds what a block may not hide: typed into a shell, a
/// control character is a key (⏎, ⌃C, ⌃U, an escape), and a
/// bidirectional override reorders what shows; either would run
/// something other than what the block shows.
bool _hides(String code) => code.runes.any(
  (r) =>
      (r < 0x20 && r != 0x09 && r != 0x0a) ||
      (r >= 0x7f && r <= 0x9f) ||
      r == 0x200e ||
      r == 0x200f ||
      (r >= 0x202a && r <= 0x202e) ||
      (r >= 0x2066 && r <= 0x2069),
);

/// What a shell block of [language] types into a terminal: its lines, a
/// leading `$ ` or `% ` prompt off those that have one (in a `console`
/// block the lines without one are output, left out); null for another
/// language, when nothing is left, or when it holds a character that
/// would type something it doesn't show.
String? runnableScript(String language, String code) {
  final lang = language.toLowerCase();
  if (!shellLanguages.contains(lang) || _hides(code)) return null;
  final script = [
    for (final line in code.split('\n'))
      if (_prompt.matchAsPrefix(line) != null)
        line.substring(2)
      else if (lang != 'console')
        line,
  ].join('\n').trim();
  return script.isEmpty ? null : script;
}

/// A run's output in the composer, sent with the next message once it's
/// done: what names it (`key`: a block's code, or a command's own key),
/// its command (the whole script), how it exited, how many lines it
/// wrote, and the text sent ([keptOutput]); its `run` is a command's
/// run typed after `!`, which shows in the card while it goes and is sent
/// only once its state is `RunState.ended`; null for a ▷ run's, which
/// comes ended.
typedef RunOutput = ({
  String key,
  String command,
  int exit,
  int lines,
  String text,
  CodeRun? run,
});

/// Whether [o] is done and goes with the next message: not a command
/// still running.
bool outputDone(RunOutput o) => o.run == null || o.run!.state == RunState.ended;

const _keptLines = 400;
const int _keptBytes = 32 << 10;

/// [lines] as a run's output is sent: the last 400 lines, 32 KB at most.
/// Nothing says how many were left out: the agent gets bare tags and what
/// the command printed, no words of Nushi's; the card says it.
String keptOutput(List<String> lines) {
  var bytes = 0;
  var from = lines.length;
  while (from > 0 && lines.length - from < _keptLines) {
    bytes += utf8.encode(lines[from - 1]).length + 1;
    if (bytes > _keptBytes) break;
    from--;
  }
  return lines.skip(from).join('\n');
}

const _input = '<bash-input>';
const _inputEnd = '</bash-input>';
const _stdout = '<bash-stdout>';
const _stdoutEnd = '</bash-stdout><bash-stderr>';
const _stderrEnd = '</bash-stderr>';
final _exitTag = RegExp(r'<bash-exit-code>(-?\d+)</bash-exit-code>');

/// A command and its output as they go to the agent: the tags Claude Code
/// writes for its own `!` command, and nothing else (no words of Nushi's;
/// ADR 0084, amended). A terminal merges the two streams, so stderr's is
/// empty.
String commandTags(String command, String output, int exit) =>
    '$_input$command$_inputEnd\n'
    '$_stdout$output$_stdoutEnd$_stderrEnd'
    '<bash-exit-code>$exit</bash-exit-code>';

/// [message] with [outputs] after it, each a command's tags
/// ([commandTags]), a blank line between.
String withOutputs(String message, List<RunOutput> outputs) => [
  if (message.isNotEmpty) message,
  for (final o in outputs) commandTags(o.command, o.text, o.exit),
].join('\n\n');

/// A command read back from a sent message ([splitCommands]): its text
/// ('' when the message held only its output, as Claude Code's second
/// message of a `!` does), its output with its stderr after it (null when
/// it held only the command, Claude's first), and its exit when written.
typedef SentCommand = ({String command, String? output, int? exit});

/// [commands], read back from a message taken back, as the cards they
/// were, done, each named by its command.
List<RunOutput> sentOutputs(List<SentCommand> commands) => [
  for (final c in commands)
    if (c.output case final text? when c.command.isNotEmpty)
      (
        key: c.command,
        command: c.command,
        exit: c.exit ?? 0,
        lines: text.isEmpty ? 0 : '\n'.allMatches(text).length + 1,
        text: text,
        run: null,
      ),
];

/// The commands [message] ends with, and the text before them
/// ([withOutputs] backwards; also Claude Code's own two messages of a `!`
/// command, one holding `<bash-input>`, the next the output's tags). An
/// output may hold the tags' own text (a `cat` of a transcript): of the
/// ways to read the message, the one whose commands start first and whose
/// outputs end first is taken, so what follows a tag inside an output
/// stays in it unless the rest of the message reads as commands too. A
/// message without them comes back as it is, with none.
(String, List<SentCommand>) splitCommands(String message) {
  final end = message.trimRight().length;
  // What reads from each place (null: nothing does), found once: without
  // it a message whose end doesn't read tries every split of its blocks.
  final memo = <int, List<SentCommand>?>{};
  for (var i = 0; i < end; i++) {
    i = _nextStart(message, i);
    if (i < 0 || i >= end) break;
    if (i > 0 && (i < 2 || !message.startsWith('\n\n', i - 2))) continue;
    final read = _blocks(message, i, end, memo);
    if (read != null) return (message.substring(0, i).trimRight(), read);
  }
  return (message, const []);
}

/// Where the next tag that can start a command is, from [from]; -1 for
/// none.
int _nextStart(String s, int from) {
  final a = s.indexOf(_input, from);
  final b = s.indexOf(_stdout, from);
  if (a < 0) return b;
  if (b < 0) return a;
  return a < b ? a : b;
}

/// The commands from [p] to [end], each after a blank line, or null when
/// that part doesn't read as commands to its end; [memo] holds what each
/// place read before.
List<SentCommand>? _blocks(
  String s,
  int p,
  int end,
  Map<int, List<SentCommand>?> memo,
) {
  if (memo.containsKey(p)) return memo[p];
  List<SentCommand>? read;
  for (final (cmd, at) in _block(s, p, end)) {
    if (at == end) {
      read = [cmd];
      break;
    }
    if (!s.startsWith('\n\n', at)) continue;
    if (_blocks(s, at + 2, end, memo) case final more?) {
      read = [cmd, ...more];
      break;
    }
  }
  return memo[p] = read;
}

/// Each way a command can be read at [p], with where it ends, the
/// shortest first.
Iterable<(SentCommand, int)> _block(String s, int p, int end) sync* {
  if (s.startsWith(_stdout, p)) {
    for (final (out, exit, at) in _output(s, p + _stdout.length, end)) {
      yield ((command: '', output: out, exit: exit), at);
    }
    return;
  }
  if (!s.startsWith(_input, p)) return;
  final from = p + _input.length;
  for (
    var q = s.indexOf(_inputEnd, from);
    q >= 0 && q < end;
    q = s.indexOf(_inputEnd, q + 1)
  ) {
    final command = s.substring(from, q);
    // A command never holds the tag that starts one: what has it is an
    // output's text and the next command's start.
    if (command.contains(_input)) break;
    final after = q + _inputEnd.length;
    if (s.startsWith('\n$_stdout', after)) {
      final out = after + 1 + _stdout.length;
      for (final (text, exit, at) in _output(s, out, end)) {
        yield ((command: command, output: text, exit: exit), at);
      }
    }
    yield ((command: command, output: null, exit: null), after);
  }
}

/// Each way an output can be read from [p], just after its stdout tag:
/// its text (stderr after stdout), its exit, and where it ends; the
/// shortest first, and of those ending at one stderr tag the one with the
/// shortest stderr (a terminal's is always empty).
Iterable<(String, int?, int)> _output(String s, int p, int end) sync* {
  for (
    var m = s.indexOf(_stderrEnd, p);
    m >= 0 && m < end;
    m = s.indexOf(_stderrEnd, m + 1)
  ) {
    if (m - _stdoutEnd.length < p) continue;
    final k = s.lastIndexOf(_stdoutEnd, m - _stdoutEnd.length);
    if (k < p) continue;
    final out = s.substring(p, k);
    final err = s.substring(k + _stdoutEnd.length, m);
    final text = err.isEmpty
        ? out
        : out.isEmpty
        ? err
        : '$out\n$err';
    final after = m + _stderrEnd.length;
    // A code past an int (a forged tag, in an output) is no exit tag.
    if (_exitTag.matchAsPrefix(s, after) case final x?
        when int.tryParse(x[1]!) != null) {
      yield (text, int.parse(x[1]!), x.end);
    }
    yield (text, null, after);
  }
}
