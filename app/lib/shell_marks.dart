/// A shell's output read for its OSC 133 marks (shell integration: fish 4
/// sends them, zsh and bash with an integration script): where a prompt
/// starts (A) and ends (B), where a command's output starts (C) and where
/// it ends, with its exit code (D). Only read, never drawn.
library;

/// One of a shell's OSC 133 marks: its letter, and for D the exit code
/// (null when the shell didn't say).
typedef ShellMark = ({String kind, int? exit});

/// A piece of a shell's output: text, or a mark between texts.
typedef ShellPiece = ({String text, ShellMark? mark});

/// Splits a shell's output, as it comes in chunks, into text and marks. A
/// mark cut between two chunks is kept until the rest of it comes.
class ShellMarks {
  String _carry = '';

  /// Whether any mark has been seen: the shell sends them.
  bool seen = false;

  /// [chunk]'s pieces, in order: text and marks.
  List<ShellPiece> feed(String chunk) {
    var s = _carry + chunk;
    _carry = '';
    final out = <ShellPiece>[];
    var from = 0;
    while (true) {
      final i = s.indexOf('\x1b]133;', from);
      if (i < 0) {
        // An escape near the end may start a mark.
        final esc = s.lastIndexOf('\x1b');
        if (esc >= from &&
            s.length - esc < 6 &&
            '\x1b]133;'.startsWith(s.substring(esc))) {
          _carry = s.substring(esc);
          s = s.substring(0, esc);
        }
        if (s.length > from) out.add((text: s.substring(from), mark: null));
        return out;
      }
      if (i > from) out.add((text: s.substring(from, i), mark: null));
      final body = i + 6;
      final bel = s.indexOf('\x07', body);
      final st = s.indexOf('\x1b\\', body);
      final end = bel < 0 ? st : (st < 0 ? bel : (bel < st ? bel : st));
      if (end < 0) {
        // Unfinished: wait for its end, unless it's no mark at all.
        if (s.length - i < 4096) _carry = s.substring(i);
        return out;
      }
      final parts = s.substring(body, end).split(';');
      final kind = parts.first;
      if (kind.isNotEmpty) {
        seen = true;
        out.add((
          text: '',
          mark: (
            kind: kind,
            exit: kind == 'D' && parts.length > 1
                ? int.tryParse(parts[1])
                : null,
          ),
        ));
      }
      from = end + (end == bel ? 1 : 2);
    }
  }
}

final _escapes = RegExp(
  // OSC and DCS strings, CSI sequences, then two-character escapes.
  r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?'
  r'|\x1bP[^\x1b]*(?:\x1b\\)?'
  r'|\x1b\[[0-?]*[ -/]*[@-~]'
  r'|\x1b[ -/]*[0-~]',
);

final _controls = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');

/// Terminal output as plain lines: escapes out, and of a line rewritten
/// with carriage returns (a progress bar) only what was written last.
List<String> plainLines(String output) => [
  for (final line in output.replaceAll(_escapes, '').split('\n'))
    _lastWrite(line.endsWith('\r') ? line.substring(0, line.length - 1) : line)
        .replaceAll(_controls, '')
        .trimRight(),
];

String _lastWrite(String line) {
  final cr = line.lastIndexOf('\r');
  return cr < 0 ? line : line.substring(cr + 1);
}
