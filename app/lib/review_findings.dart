import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A finding a review bot asks to address: where (a file, its lines; no
/// path when it names none, no line when it names only the file), what it
/// says (Markdown), and whose review.
typedef ReviewFinding = ({
  String path,
  int start,
  int end,
  String text,
  GitHubComment from,
});

/// Which reviews findings are read from, and the headings that start
/// them: Settings › GitHub's Findings from review bots.
typedef FindingsSetup = ({List<String> bots, List<String> headings});

/// [bots] and [headings] as Settings has them: comma-separated, any case.
FindingsSetup findingsSetup(String bots, String headings) {
  List<String> words(String s) => [
    for (final w in s.split(','))
      if (w.trim().isNotEmpty) w.trim().toLowerCase(),
  ];
  return (bots: words(bots), headings: words(headings));
}

/// Whether [c] is a review bot's, as [setup] names them (a login with or
/// without `[bot]`).
bool isFindingsBot(GitHubComment c, FindingsSetup setup) {
  if (!c.bot) return false;
  final login = c.author.toLowerCase().replaceFirst(RegExp(r'\[bot\]$'), '');
  return setup.bots.contains(login);
}

/// What a review's findings are: `found` false when it has no heading that
/// starts them; `findings` empty with `found` true when its section says
/// none, or when its shape doesn't parse cleanly (`clean` false): then it
/// shows only in Activity rather than in pieces.
typedef ReadFindings = ({bool found, bool clean, List<ReviewFinding> findings});

final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');

/// A line that is only bold text (with a colon): a heading too.
final _boldHeading = RegExp(r'^\*\*([^*]+?):?\*\*:?\s*$');

final _item = RegExp(r'^( *)([-*+]|\d{1,3}[.)])\s+(.*)$');
final _fence = RegExp(r'^\s*(```|~~~)');
final _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');

/// A finding saying there are none: "None.", "Nothing blocking", "N/A".
final _none = RegExp(
  r'^[*_]*(none|nothing|n/a|no (blocking|blockers|must|issues|findings))\b',
  caseSensitive: false,
);

/// The text ends mid-sentence: a list item that is one clause of a
/// sentence the list spells out ("… hop;", "…, and").
final _clause = RegExp(r'([;,]|\b(and|or))\**\s*$');

/// A block of a section: a paragraph's text, or a list's items.
sealed class _Block;

class _Para extends _Block {
  new(this.text);
  final String text;
}

class _List extends _Block {
  final items = <String>[];
}

/// The findings in a review bot's comment or review [c]: under the
/// nearest heading (a Markdown `#` heading or a bold line) that has one of
/// [setup]'s headings' words, one finding per list item or paragraph,
/// never cut inside a sentence (a list whose items end in `;` is one
/// sentence, with the paragraph leading into it), each with the file and
/// lines it starts with. A paragraph after a list is the reviewer's note,
/// not a finding. A finding left mid-sentence, or a list after such a
/// note, means the shape isn't one this reads: then none at all.
ReadFindings readFindings(GitHubComment c, FindingsSetup setup) {
  const nothing = (found: false, clean: true, findings: <ReviewFinding>[]);
  if (c.body.isEmpty || setup.headings.isEmpty) return nothing;
  final sections = <List<String>>[];
  List<String>? open;
  var fenced = false;
  for (final line in c.body.split('\n')) {
    if (_fence.hasMatch(line)) fenced = !fenced;
    final words = fenced ? null : _headingWords(line);
    if (words != null) {
      final starts = setup.headings.any(words.toLowerCase().contains);
      open = starts ? <String>[] : null;
      if (open != null) sections.add(open);
      continue;
    }
    if (!fenced && _rule.hasMatch(line)) {
      open = null;
      continue;
    }
    open?.add(line);
  }
  if (sections.isEmpty) return nothing;
  final out = <ReviewFinding>[];
  for (final s in sections) {
    final texts = _sectionFindings(_blocks(s));
    if (texts == null) return (found: true, clean: false, findings: const []);
    out.addAll(texts.map((t) => _finding(t, c)));
  }
  return (found: true, clean: true, findings: out);
}

/// A heading's words, or null when [line] isn't one.
String? _headingWords(String line) {
  final l = line.trim();
  if (_heading.firstMatch(l) case final h?) return h[2];
  if (_boldHeading.firstMatch(l) case final b?) return b[1];
  return null;
}

/// A section's lines as paragraphs and lists: an item takes the lines
/// under it (indented, or straight after it), its own nested items
/// joined in; a blank line then a line not indented ends a list.
List<_Block> _blocks(List<String> lines) {
  final out = <_Block>[];
  final para = <String>[];
  _List? list;
  StringBuffer? item;
  var topIndent = 0;
  var blank = false;
  var fenced = false;

  void endItem() {
    if (item case final i?) list!.items.add(i.toString().trim());
    item = null;
  }

  void endPara() {
    if (para.isNotEmpty) out.add(_Para(para.join(' ').trim()));
    para.clear();
  }

  for (final line in lines) {
    if (_fence.hasMatch(line) || fenced) {
      if (_fence.hasMatch(line)) fenced = !fenced;
      // Code stays as written, in the item or paragraph it's in.
      if (item case final i?) {
        i.write('\n${line.trimLeft()}');
      } else {
        para.add(line);
      }
      blank = false;
      continue;
    }
    if (line.trim().isEmpty) {
      blank = true;
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    final m = _item.firstMatch(line);
    if (m != null &&
        (list == null || item == null || indent <= topIndent + 1)) {
      if (m[1]!.length > 3 && list == null) {
        para.add(line.trim()); // code by indentation, not a list
        blank = false;
        continue;
      }
      endPara();
      if (list == null || (blank && item == null)) {
        list = _List();
        out.add(list);
        topIndent = indent;
      }
      endItem();
      item = StringBuffer(m[3]!);
    } else if (item != null && (!blank || indent >= 2)) {
      // Under the item: its text, or a nested item's, joined in.
      item!.write(' ${m != null ? m[3] : line.trim()}');
    } else {
      endItem();
      list = null;
      if (blank) endPara();
      para.add(line.trim());
    }
    blank = false;
  }
  endItem();
  endPara();
  return out;
}

/// The findings' texts in a section's [blocks], null when its shape
/// isn't clean.
List<String>? _sectionFindings(List<_Block> blocks) {
  final out = <String>[];
  var listed = false; // a list came: a paragraph now is the reviewer's note
  var noted = false;
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final next = i + 1 < blocks.length ? blocks[i + 1] : null;
    switch (b) {
      case _Para(:final text):
        if (listed) {
          noted = true;
          continue;
        }
        // A paragraph leading into a list ("As written:") is its start.
        if (text.endsWith(':') && next is _List) continue;
        out.add(text);
      case _List(:final items):
        if (noted) return null; // a list after the note: not a shape known
        listed = true;
        final before = i > 0 ? blocks[i - 1] : null;
        final lead = before is _Para && before.text.endsWith(':')
            ? before.text
            : null;
        final sentence =
            items.length > 1 &&
            items.take(items.length - 1).every(_clause.hasMatch);
        if (sentence) {
          out.add([?lead, ...items].join(' '));
        } else {
          out.addAll(items);
        }
    }
  }
  if (out.isNotEmpty && _none.hasMatch(out.first)) return const [];
  if (out.any((t) => _clause.hasMatch(t) || t.isEmpty)) return null;
  return out;
}

/// A file and its lines starting a finding: `path:12:`, `path:12-14 —`,
/// `` `path` ``, `` **`path:12`**: ``.
final _place = RegExp(
  r'^(\*\*)?\s*(`)?((?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z0-9]{1,8}|(?:[\w.@-]+/)+[\w.@-]+)'
  r'(?::(\d+)(?:\s*[-–]\s*(\d+))?)?(`)?\s*(\*\*)?\s*([:—–]|\s-\s)?\s*',
);

ReviewFinding _finding(String text, GitHubComment from) {
  final none = (path: '', start: 0, end: 0, text: text, from: from);
  final w = _place.firstMatch(text);
  if (w == null) return none;
  final ticked = w[2] != null && w[6] != null;
  final line = w[4] != null;
  final said = w[8] != null || (w[1] != null && w[7] != null);
  // A path:line, or a path in code; then what's said of it.
  if (!(ticked || (line && said))) return none;
  if (w[1] != null && w[7] == null) return none; // bold that goes on
  final start = line ? int.parse(w[4]!) : 0;
  final end = w[5] == null ? start : int.parse(w[5]!);
  final rest = said ? text.substring(w.end) : text;
  return (
    path: w[3]!,
    start: start,
    end: end < start ? start : end,
    text: rest.isEmpty ? text : rest,
    from: from,
  );
}

/// Whether [f] is about the lines [x] is on: the same file (one path the
/// other's end) and a line in its range.
bool sameSpot(ReviewFinding f, GitHubThread x) {
  if (f.path.isEmpty || f.start == 0 || x.path.isEmpty) return false;
  final file = x.path.endsWith(f.path) || f.path.endsWith(x.path);
  final line = x.outdated ? x.originalLine : x.line;
  return file && line >= f.start && line <= f.end;
}

/// Where [f] is, as a row names it: `path:12`, `path:12–14`, or `path`.
String findingPlace(ReviewFinding f) => f.path.isEmpty
    ? ''
    : f.start == 0
    ? f.path
    : f.end > f.start
    ? '${f.path}:${f.start}–${f.end}'
    : '${f.path}:${f.start}';

/// [login]'s, in English: "mona's", "github-actions'".
String possessive(String login) => login.endsWith('s') ? "$login'" : "$login's";
