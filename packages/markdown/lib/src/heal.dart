/// Makes a streaming message renderable while it is incomplete, so half
/// a construct never shows as raw syntax. Only the render is healed; the
/// text itself is never changed.
///
/// * An unclosed fenced code block is closed; a last line of only one or
///   two backticks or tildes (a fence still being typed) is dropped.
/// * A delimiter row being typed under a table header is completed.
/// * On the last line, if it has no line break yet: a link whose text or
///   destination is still open renders as its text, an unclosed code span
///   gets its closing backticks, and unclosed emphasis (`*`, `**`, `_`,
///   `~~`, ...) gets its closers.
String heal(String text) {
  if (text.isEmpty) return text;
  final lastBreak = text.lastIndexOf('\n');
  final head = text.substring(0, lastBreak + 1);
  final last = text.substring(lastBreak + 1);

  final closer = _openFence(text);
  if (closer != null) {
    if (_partialFence.hasMatch(last) && head.isNotEmpty) return '$head$closer';
    return '${text.endsWith('\n') ? text : '$text\n'}$closer';
  }
  if (last.isEmpty) return text;
  if (_partialFence.hasMatch(last)) return head;
  final row = _delimiterRow(head, last);
  if (row != null) return '$head$row';
  return '$head${healLine(last)}';
}

/// Heals one incomplete line of inline markdown (see [heal]).
String healLine(String line) {
  final s = _healLinks(line);
  final spans = _CodeSpans.scan(s);
  if (spans.openRun > 0) return '$s${'`' * spans.openRun}';
  return _closeEmphasis(s, spans);
}

// ---------------------------------------------------------------- fences

final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _partialFence = RegExp(r'^ {0,3}(`{1,2}|~{1,2})$');

/// The closer of the fence still open at the end of [text], or null.
String? _openFence(String text) {
  String? open;
  for (var line in text.split('\n')) {
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    final m = _fence.firstMatch(line);
    if (m == null) continue;
    final run = m[1]!;
    if (open == null) {
      // A backtick fence's info string can't hold backticks.
      if (run[0] == '`' && line.substring(m.end).contains('`')) continue;
      open = run;
    } else if (run[0] == open[0] &&
        run.length >= open.length &&
        line.substring(m.end).trim().isEmpty) {
      open = null;
    }
  }
  return open;
}

// ---------------------------------------------------------------- tables

final _delimiterChars = RegExp(r'^[ \t]*[|:\-][|:\- \t]*$');

String? _delimiterRow(String head, String last) {
  if (!_delimiterChars.hasMatch(last) || !last.contains('-')) return null;
  final lines = head.split('\n');
  if (lines.length < 2) return null;
  final header = lines[lines.length - 2];
  if (!header.contains('|')) return null;
  // The header must start its paragraph, or it is a table body row.
  final before = lines.length >= 3 ? lines[lines.length - 3] : '';
  if (before.trim().isNotEmpty) return null;
  final cells = _cellCount(header);
  if (cells == 0) return null;
  return '|${List.filled(cells, ' --- ').join('|')}|';
}

/// The number of cells in a table row: split on unescaped `|`, ignoring a
/// leading and a trailing pipe.
int _cellCount(String row) {
  var s = row.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|') && !s.endsWith(r'\|')) s = s.substring(0, s.length - 1);
  if (s.trim().isEmpty) return 0;
  var cells = 1;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      i++; // an escaped character
    } else if (c == 0x7c) {
      cells++;
    }
  }
  return cells;
}

// ---------------------------------------------------------------- code spans

class _CodeSpans {
  _CodeSpans(this.masked, this.openRun);

  /// Per code unit: true inside a code span (its backticks included).
  final List<bool> masked;

  /// The backtick run of a code span still open at the end, or 0.
  final int openRun;

  static _CodeSpans scan(String s) {
    final masked = List<bool>.filled(s.length, false);
    var i = 0;
    while (i < s.length) {
      if (s.codeUnitAt(i) == 0x5c && i + 1 < s.length) {
        i += 2;
        continue;
      }
      if (s.codeUnitAt(i) != 0x60) {
        i++;
        continue;
      }
      final open = i;
      final run = _runLength(s, i);
      final close = _findRun(s, open + run, run);
      if (close < 0) {
        masked.fillRange(open, s.length, true);
        return _CodeSpans(masked, run);
      }
      masked.fillRange(open, close + run, true);
      i = close + run;
    }
    return _CodeSpans(masked, 0);
  }

  static int _runLength(String s, int at) {
    var n = 0;
    while (at + n < s.length && s.codeUnitAt(at + n) == 0x60) {
      n++;
    }
    return n;
  }

  // The start of the next backtick run of exactly [run] from [from], or -1.
  static int _findRun(String s, int from, int run) {
    var i = from;
    while (i < s.length) {
      if (s.codeUnitAt(i) != 0x60) {
        i++;
        continue;
      }
      final n = _runLength(s, i);
      if (n == run) return i;
      i += n;
    }
    return -1;
  }
}

// ---------------------------------------------------------------- links

final _taskMarker = RegExp(r'^\s*(?:[-+*]|\d{1,9}[.)])\s+\[[ xX]\]');

String _healLinks(String line) {
  final spans = _CodeSpans.scan(line);
  final stack = <int>[];
  var lastOpen = -1; // the '[' of the last closed bracket pair
  var lastClose = -1; // its ']'
  for (var i = 0; i < line.length; i++) {
    if (spans.masked[i]) continue;
    final c = line.codeUnitAt(i);
    if (c == 0x5c) {
      i++;
    } else if (c == 0x5b) {
      stack.add(i);
    } else if (c == 0x5d && stack.isNotEmpty) {
      lastOpen = stack.removeLast();
      lastClose = i;
    }
  }
  final taskEnd = _taskMarker.firstMatch(line)?.end ?? -1;
  int start(int bracket) =>
      bracket > 0 && line[bracket - 1] == '!' ? bracket - 1 : bracket;

  if (stack.isNotEmpty) {
    // `[text` still open: drop the bracket (and an image's '!').
    final at = stack.first;
    if (at < taskEnd) return line;
    return line.substring(0, start(at)) + line.substring(at + 1);
  }
  if (lastOpen < 0 || lastClose < taskEnd) return line;
  final text = line.substring(lastOpen + 1, lastClose);
  final after = line.substring(lastClose + 1);
  // A trailing `[text]` may still become a link; `[text](partial` is one.
  if (after.isEmpty || (after.startsWith('(') && !_closed(after))) {
    return line.substring(0, start(lastOpen)) + text;
  }
  return line;
}

// Whether "(..." (a link destination and optional title) is closed.
bool _closed(String s) {
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      i++;
    } else if (c == 0x28) {
      depth++;
    } else if (c == 0x29 && --depth == 0) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------- emphasis

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d || c == 0xa0;

bool _isPunctuation(int c) =>
    (c >= 0x21 && c <= 0x2f) ||
    (c >= 0x3a && c <= 0x40) ||
    (c >= 0x5b && c <= 0x60) ||
    (c >= 0x7b && c <= 0x7e);

class _Opener {
  _Opener(this.char, this.length);
  final int char;
  int length;
}

String _closeEmphasis(String line, _CodeSpans spans) {
  final stack = <_Opener>[];
  var i = 0;
  while (i < line.length) {
    final c = line.codeUnitAt(i);
    if (spans.masked[i]) {
      i++;
      continue;
    }
    if (c == 0x5c) {
      i += 2;
      continue;
    }
    if (c != 0x2a && c != 0x5f && c != 0x7e) {
      i++;
      continue;
    }
    var n = 0;
    while (i + n < line.length && line.codeUnitAt(i + n) == c) {
      n++;
    }
    final prev = i == 0 ? 0x20 : line.codeUnitAt(i - 1);
    final next = i + n >= line.length ? 0x20 : line.codeUnitAt(i + n);
    i += n;
    if (c == 0x7e && n > 2) continue; // not strikethrough
    // CommonMark's left- and right-flanking delimiter runs.
    final left =
        !_isSpace(next) &&
        (!_isPunctuation(next) || _isSpace(prev) || _isPunctuation(prev));
    final right =
        !_isSpace(prev) &&
        (!_isPunctuation(prev) || _isSpace(next) || _isPunctuation(next));
    var canOpen = left;
    var canClose = right;
    if (c == 0x5f) {
      canOpen = left && (!right || _isPunctuation(prev));
      canClose = right && (!left || _isPunctuation(next));
    }
    if (canClose) {
      n = _matchClosers(stack, c, n);
      if (n == 0) continue;
    }
    if (canOpen) stack.add(_Opener(c, n));
  }
  if (stack.isEmpty) return line;
  final out = StringBuffer(line.trimRight());
  for (final o in stack.reversed) {
    out.write(String.fromCharCode(o.char) * o.length);
  }
  return out.toString();
}

// Matches a closing run of [n] [char]s against the stack; returns what is
// left of the run.
int _matchClosers(List<_Opener> stack, int char, int n) {
  var left = n;
  while (left > 0) {
    final at = stack.lastIndexWhere((o) => o.char == char);
    if (at < 0) break;
    final opener = stack[at];
    stack.removeRange(at + 1, stack.length);
    final used = opener.length < left ? opener.length : left;
    opener.length -= used;
    left -= used;
    if (opener.length == 0) stack.removeAt(at);
  }
  return left;
}
