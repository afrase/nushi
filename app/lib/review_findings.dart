import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A finding a review bot asks to address: where (a file, its lines; no
/// path when it names none), what it says (Markdown), and whose review.
typedef ReviewFinding = ({
  String path,
  int start,
  int end,
  String text,
  GitHubComment from,
});

/// A heading that opens a review's findings to address: "Must address",
/// "Must fix", "Blocking", "Blockers", "Critical", "Required changes",
/// "Needs to be fixed", "High priority", "Key findings · must address".
final _mustHeading = RegExp(
  r'must[ -]?(address|fix|have|change)|\bblock(ing|ers?)\b|\bcritical\b|'
  'required changes|needs? (to be )?(fixed|addressed)|high[ -]priority',
  caseSensitive: false,
);

final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');

/// A line that is only bold text (with a colon): a heading too, under any
/// `#` heading.
final _boldHeading = RegExp(r'^\*\*([^*]+)\*\*:?\s*$');

final _item = RegExp(r'^\s{0,3}([-*+]|\d{1,3}[.)])\s+(.*)$');

/// A file and its lines in a finding: `path/to/file.rb:12` or `:12-14`
/// (in code or bold, or bare).
final _where = RegExp(
  r'`?((?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z0-9]{1,8}):(\d+)(?:\s*[-–]\s*(\d+))?`?',
);

/// The findings to address in a review bot's comment or review [c]: the
/// list items under a heading that says they must be addressed (Markdown
/// `#` headings or a bold line), each with the file and lines it names
/// first. A guess at the common shapes; when none is found, the review
/// shows only in the conversation.
List<ReviewFinding> reviewFindings(GitHubComment c) {
  if (!c.bot || c.body.isEmpty) return const [];
  final out = <ReviewFinding>[];
  int? level; // the open section's heading level; 7 for a bold line's
  final item = StringBuffer();
  void flush() {
    final text = item.toString().trim();
    item.clear();
    if (text.isEmpty) return;
    out.add(_finding(text, c));
  }

  for (final line in c.body.split('\n')) {
    final h = _heading.firstMatch(line.trim());
    final b = h == null ? _boldHeading.firstMatch(line.trim()) : null;
    if (h != null || b != null) {
      final lv = h?[1]!.length ?? 7;
      final words = h?[2] ?? b![1]!;
      if (level != null && lv <= level) {
        flush();
        level = null;
      }
      if (level == null && _mustHeading.hasMatch(words)) level = lv;
      continue;
    }
    if (level == null) continue;
    final m = _item.firstMatch(line);
    if (m != null && !line.startsWith('    ')) {
      flush();
      item.write(m[2]);
    } else if (item.isNotEmpty && line.trim().isNotEmpty) {
      item.write(' ${line.trim()}');
    } else if (line.trim() == '---') {
      flush();
      level = null;
    }
  }
  flush();
  return out;
}

ReviewFinding _finding(String text, GitHubComment from) {
  final head = text.length > 160 ? text.substring(0, 160) : text;
  final w = _where.firstMatch(head);
  if (w == null) {
    return (path: '', start: 0, end: 0, text: text, from: from);
  }
  final start = int.parse(w[2]!);
  final end = w[3] == null ? start : int.parse(w[3]!);
  // The place said first ("**`a.rb:12`**: …") isn't said again.
  var rest = text;
  final lead = RegExp(
    r'^(\*\*)?\s*' + RegExp.escape(w[0]!) + r'\s*(\*\*)?\s*[:—–-]?\s*',
  ).firstMatch(text);
  if (lead != null) rest = text.substring(lead.end);
  return (
    path: w[1]!,
    start: start,
    end: end < start ? start : end,
    text: rest.isEmpty ? text : rest,
    from: from,
  );
}

/// Whether [f] is about the lines [x] is on: the same file (one path the
/// other's end) and a line in its range.
bool sameSpot(ReviewFinding f, GitHubThread x) {
  if (f.path.isEmpty || x.path.isEmpty) return false;
  final file = x.path.endsWith(f.path) || f.path.endsWith(x.path);
  final line = x.outdated ? x.originalLine : x.line;
  return file && line >= f.start && line <= f.end;
}

/// Where [f] is, as a row names it: `path:12` or `path:12–14`.
String findingPlace(ReviewFinding f) => f.path.isEmpty
    ? ''
    : f.end > f.start
    ? '${f.path}:${f.start}–${f.end}'
    : '${f.path}:${f.start}';
