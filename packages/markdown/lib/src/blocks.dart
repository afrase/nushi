/// Where streaming Markdown can be cut so that what comes before is
/// finished, and parses the same alone as in the whole: the start of a line
/// after a blank line, outside any fence, that starts a block of its own.
/// Not an indented line (a list item's paragraph or an indented code
/// block going on), not a list item right after a list (a loose list going
/// on), and only a line that has ended (its first characters could still
/// become another block). The last such place in [text] after [from] (a
/// place found before), or null.
///
/// Text with a reference definition (`[x]: url`) is never cut: a link
/// anywhere may refer to it.
int? lastBoundary(String text, {int from = 0}) {
  if (hasReferences(text)) return null;
  int? cut;
  String? fence; // the open fence's run of backticks or tildes
  var blank = false; // the line before was blank
  var list = false; // the block so far is a list
  var at = from;
  while (at < text.length) {
    final end = text.indexOf('\n', at);
    if (end < 0) break; // the last line, still being written
    var line = text.substring(at, end);
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    final next = end + 1;
    if (fence != null) {
      final m = _fence.firstMatch(line);
      if (m != null &&
          m[1]![0] == fence[0] &&
          m[1]!.length >= fence.length &&
          line.substring(m.end).trim().isEmpty) {
        fence = null;
      }
      at = next;
      continue;
    }
    if (line.trim().isEmpty) {
      blank = true;
      at = next;
      continue;
    }
    final item = _item.hasMatch(line);
    final indented = line.startsWith(' ') || line.startsWith('\t');
    if (blank && !indented) {
      if (at > from && !(item && list)) cut = at;
      list = item;
    } else if (item && !indented) {
      list = true;
    }
    if (_fence.firstMatch(line) case final m?) {
      // A backtick fence's info string can't hold backticks.
      if (m[1]![0] != '`' || !line.substring(m.end).contains('`')) {
        fence = m[1];
      }
    }
    blank = false;
    at = next;
  }
  return cut;
}

/// Whether [text] has a reference definition (`[x]: url`), which a link
/// anywhere may refer to.
bool hasReferences(String text) => _reference.hasMatch(text);

final _fence = RegExp('^ {0,3}(`{3,}|~{3,})');
final _item = RegExp(r'^ {0,3}(?:[-+*]|\d{1,9}[.)])(?:[ \t]|$)');
final _reference = RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true);
