import 'package:nushi/theme/theme.dart';

// GitHub's text as the pull request's parts show it: its first words,
// its start, plain, its tables' empty columns gone; and the column it
// reads in.

/// The widest a pull request's or an issue's text reads at: wider, it's
/// centred in the room. On the Mac a transcript's text keeps it too, at the
/// left, under the chat's title (ADR 0072).
const readableWidth = 860.0;

/// Horizontal padding that centres [readableWidth] in [width], [least] at
/// least on each side.
double readablePad(double width, {double least = NushiTheme.gutter}) =>
    width - 2 * least > readableWidth ? (width - readableWidth) / 2 : least;

/// [body] from its first text: a heading it starts with ("## Summary")
/// would take the lines a clamped text shows.
String textStart(String body) {
  final lines = body.trimLeft().split('\n');
  var i = 0;
  while (i < lines.length &&
      (lines[i].trim().isEmpty || lines[i].trimLeft().startsWith('#'))) {
    i++;
  }
  return i == lines.length ? body : lines.skip(i).join('\n');
}

/// Whether [body] is long enough to show only its start: more than six
/// lines (a table's or a list's), or more than 480 characters.
bool longText(String body) {
  final lines = body.trim().split('\n').where((l) => l.trim().isNotEmpty);
  return lines.length > 6 || body.length > 480;
}

final _delimiter = RegExp(r'^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$');

/// A comment's first words, as one plain line: its first line of text that
/// isn't a table's head or delimiter, without Markdown's marks (a table
/// row's cells joined by " · ", links as their text, images and `:emoji:`
/// codes dropped); 200 characters at most.
String commentSummary(String body) {
  final lines = body.split('\n').map((l) => l.trim()).toList();
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    if (l.isEmpty || _delimiter.hasMatch(l)) continue;
    // A table's head, when its delimiter follows: its first row says more.
    if (l.startsWith('|') &&
        i + 1 < lines.length &&
        _delimiter.hasMatch(lines[i + 1])) {
      continue;
    }
    if (l.startsWith('|')) {
      l = _cells(l).where((c) => c.trim().isNotEmpty).join(' · ');
    }
    l = _plain(l);
    if (l.isEmpty) continue;
    return l.length > 200 ? '${l.substring(0, 199)}…' : l;
  }
  return '';
}

/// [body] as one plain line: each line without Markdown's marks, joined.
String plainText(String body) => [
  for (final l in body.split('\n'))
    if (_plain(l.trim()) case final p when p.isNotEmpty) p,
].join(' ');

/// [line] without Markdown's marks.
String _plain(String line) => line
    .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll(RegExp(':[a-z0-9_+-]+:'), '')
    .replaceAll(
      RegExp(r'^(#{1,6}\s+|>\s*|[-*+]\s+(\[[ xX]\]\s*)?|\d+\.\s+)'),
      '',
    )
    .replaceAll(RegExp(r'\*\*|__|`'), '')
    .replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]()#+\-.!|<>~])'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[\s·:]+|[\s·]+$'), '')
    .trim();

/// A table row's cells: split at each `|` not escaped, the outer ones
/// dropped.
List<String> _cells(String row) {
  var r = row.trim();
  if (r.startsWith('|')) r = r.substring(1);
  if (r.endsWith('|') && !r.endsWith(r'\|')) r = r.substring(0, r.length - 1);
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 0; i < r.length; i++) {
    if (r[i] == r'\' && i + 1 < r.length) {
      cell.write(r.substring(i, i + 2));
      i++;
    } else if (r[i] == '|') {
      cells.add(cell.toString());
      cell.clear();
    } else {
      cell.write(r[i]);
    }
  }
  return cells..add(cell.toString());
}

/// GitHub's Markdown as the pull request's parts show it: a table's
/// columns with nothing in them (head or cells) dropped, so the rest get
/// their width.
String githubText(String body) {
  if (!body.contains('|')) return body;
  final lines = body.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final head = lines[i].trim();
    if (!head.startsWith('|') ||
        i + 1 >= lines.length ||
        !_delimiter.hasMatch(lines[i + 1].trim())) {
      out.add(lines[i]);
      continue;
    }
    var end = i + 2;
    while (end < lines.length && lines[end].trim().startsWith('|')) {
      end++;
    }
    final rows = [
      for (var j = i; j < end; j++)
        if (j != i + 1) _cells(lines[j]),
    ];
    final width = rows.first.length;
    final keep = [
      for (var c = 0; c < width; c++)
        if (rows.any((r) => c < r.length && r[c].trim().isNotEmpty)) c,
    ];
    if (keep.length == width || keep.isEmpty) {
      out.addAll(lines.sublist(i, end));
    } else {
      String row(List<String> cells) =>
          '|${[for (final c in keep)
            if (c < cells.length) cells[c] else ''].join('|')}|';
      out
        ..add(row(rows.first))
        ..add('|${List.filled(keep.length, ' --- ').join('|')}|')
        ..addAll(rows.skip(1).map(row));
    }
    i = end - 1;
  }
  return out.join('\n');
}
