import 'dart:convert';

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

/// A run's output waiting in the composer, sent with the next message:
/// the block it ran (`key`, its code), its command's first line, how it
/// exited, how many lines it wrote, and the text sent ([keptOutput]).
typedef RunOutput = ({
  String key,
  String command,
  int exit,
  int lines,
  String text,
});

const _keptLines = 400;
const int _keptBytes = 32 << 10;

/// [lines] as a run's output is sent: the last 400 lines, 32 KB at most,
/// after a line saying how many earlier ones are left out.
String keptOutput(List<String> lines) {
  var bytes = 0;
  var from = lines.length;
  while (from > 0 && lines.length - from < _keptLines) {
    bytes += utf8.encode(lines[from - 1]).length + 1;
    if (bytes > _keptBytes) break;
    from--;
  }
  return [
    if (from > 0) '… $from earlier lines left out',
    ...lines.skip(from),
  ].join('\n');
}

/// [message] with [outputs] after it, each a line naming its command and
/// exit, then a fenced block of its output.
String withOutputs(String message, List<RunOutput> outputs) => [
  if (message.isNotEmpty) message,
  for (final o in outputs)
    [
      _lead(o, _ticks(o.command, 1)),
      '',
      _ticks(o.text, 3),
      o.text,
      _ticks(o.text, 3),
    ].join('\n'),
].join('\n\n');

/// Backticks enough to fence [s]: one more than its longest run, and at
/// least [least].
String _ticks(String s, int least) {
  final most = RegExp('`+')
      .allMatches(s)
      .fold(0, (n, m) => m[0]!.length > n ? m[0]!.length : n);
  return '`' * (most + 1 > least ? most + 1 : least);
}

/// The line over an output's block: its command as inline code between
/// [ticks] (spaced when it starts or ends with a backtick), and its exit.
String _lead(RunOutput o, String ticks) {
  final c = o.command;
  final code = c.startsWith('`') || c.endsWith('`')
      ? '$ticks $c $ticks'
      : '$ticks$c$ticks';
  return 'Output of $code (exit ${o.exit}):';
}
