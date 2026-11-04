import 'package:markdown_view/src/fence.dart';

/// Where streaming Markdown can be cut so that what comes before is
/// finished, and parses the same alone as in the whole: the start of a line
/// after a blank line, outside any fence or HTML block that runs past blank
/// lines ([_htmlOpens]), that starts a block of its own.
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
  RegExp? html; // the end of the open HTML block that blank lines don't end
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
      if (closesFence(line, fence)) fence = null;
      at = next;
      continue;
    }
    if (html != null) {
      if (html.hasMatch(line)) html = null;
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
    fence = openingFence(line);
    if (fence == null) html = _htmlOpens(line);
    blank = false;
    at = next;
  }
  return cut;
}

/// Whether [text] has a reference definition (`[x]: url`), which a link
/// anywhere may refer to.
bool hasReferences(String text) => _reference.hasMatch(text);

final _item = RegExp(r'^ {0,3}(?:[-+*]|\d{1,9}[.)])(?:[ \t]|$)');
final _reference = RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true);

/// The end of the HTML block [line] starts, when it's one that blank lines
/// don't end and it doesn't end on that line; else null. CommonMark's
/// types 1 to 5: `<pre>`, `<script>`, `<style>` or `<textarea>`, a comment,
/// `<?…?>`, a declaration (`<!DOCTYPE …>`) and CDATA. Each end is looked
/// for in the whole line, its start too, as package:markdown does.
RegExp? _htmlOpens(String line) {
  for (final (start, end) in _htmlBlocks) {
    if (start.hasMatch(line)) return end.hasMatch(line) ? null : end;
  }
  return null;
}

final _htmlBlocks = [
  (
    RegExp(
      r'^ {0,3}<(?:pre|script|style|textarea)(?:\s|>|$)',
      caseSensitive: false,
    ),
    RegExp('</(?:pre|script|style|textarea)>', caseSensitive: false),
  ),
  (RegExp('^ {0,3}<!--'), RegExp('-->')),
  (RegExp(r'^ {0,3}<\?'), RegExp(r'\?>')),
  (RegExp(r'^ {0,3}<!\[CDATA\['), RegExp(r'\]\]>')),
  (RegExp('^ {0,3}<![A-Za-z]'), RegExp('>')),
];

final _htmlStart = RegExp('^ {0,3}<[A-Za-z/!?]');

/// Which lines of streaming Markdown are code, read line by line as the
/// text grows (each whole line once): a fenced block's lines, its fences
/// too; an indented line; an HTML block's lines, blank lines and all in
/// one that they don't end ([_htmlOpens]). Give it one text and more of
/// it, at places that only move on.
class CodeLines {
  int _line = 0; // the start of the next line to read
  String? _fence; // the fence open at [_line]
  bool _html = false; // [_line] goes on an HTML block
  RegExp? _until; // the end of the one that blank lines don't end, open

  /// Reads the whole lines of [text] that end before [at].
  void _read(String text, int at) {
    while (true) {
      final nl = text.indexOf('\n', _line);
      if (nl < 0 || nl >= at) return;
      final line = text.substring(_line, nl);
      final next = _next(line);
      _fence = next.fence;
      _html = next.html;
      _until = next.until;
      _line = nl + 1;
    }
  }

  /// [line] at [_line]: whether it's code, and the state after it.
  ({bool code, String? fence, bool html, RegExp? until}) _next(String line) {
    if (_fence case final f?) {
      final fence = closesFence(line, f) ? null : f;
      return (code: true, fence: fence, html: false, until: null);
    }
    if (_until case final u?) {
      final until = u.hasMatch(line) ? null : u;
      return (code: true, fence: null, html: false, until: until);
    }
    if (line.trim().isEmpty) {
      return (code: false, fence: null, html: false, until: null);
    }
    if (openingFence(line) case final f?) {
      return (code: true, fence: f, html: false, until: null);
    }
    final until = _html ? null : _htmlOpens(line);
    final html = _html || _htmlStart.hasMatch(line);
    final indented = line.startsWith('    ') || line.startsWith('\t');
    return (code: html || indented, fence: null, html: html, until: until);
  }

  String _lineAt(String text) {
    final nl = text.indexOf('\n', _line);
    return text.substring(_line, nl < 0 ? text.length : nl);
  }

  /// Whether the line that [at] falls in, in [text], is code.
  bool inCode(String text, int at) {
    _read(text, at);
    return _next(_lineAt(text)).code;
  }

  /// When [at] falls in a fenced block in [text] (its fences too): where
  /// the block ends, after its closing fence's line, or [text]'s end while
  /// it's open. Else null.
  int? fenceEnd(String text, int at) {
    _read(text, at);
    var fence = _fence;
    var from = _line;
    if (fence == null) {
      fence = openingFence(_lineAt(text));
      if (fence == null) return null;
      final nl = text.indexOf('\n', _line);
      if (nl < 0) return text.length;
      from = nl + 1;
    }
    while (from < text.length) {
      final nl = text.indexOf('\n', from);
      final end = nl < 0 ? text.length : nl;
      if (closesFence(text.substring(from, end), fence)) {
        return nl < 0 ? text.length : nl + 1;
      }
      from = end + 1;
    }
    return text.length;
  }
}
