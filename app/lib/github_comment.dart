import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The widest a pull request's or an issue's text reads at: wider, it's
/// centred in the room.
const readableWidth = 860.0;

/// Horizontal padding that centres [readableWidth] in [width], [least] at
/// least on each side.
double readablePad(double width, {double least = 20}) =>
    width - 2 * least > readableWidth ? (width - readableWidth) / 2 : least;

/// A comment or a review in the conversation: its author (marked when
/// outside the repository, or a bot), when, a review's state, its text.
/// A bot's comment (not a review) folds to one line, its first words, with
/// Show; a long text shows its first lines, with Show the whole review (or
/// comment).
///
/// In a chat's tab it can be sent to the agent ([SendToAgent]), unless
/// it's part of a thread ([sendable] false: the thread is sent whole).
class CommentEntry extends StatefulWidget {
  const new(this.comment, {required this.now, super.key, this.sendable = true});

  final GitHubComment comment;
  final DateTime now;
  final bool sendable;

  @override
  State<CommentEntry> createState() => _CommentEntryState();
}

class _CommentEntryState extends State<CommentEntry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.comment;
    final folds = c.bot && c.review.isEmpty && c.body.isNotEmpty;
    final long = !folds && longText(c.body);
    final review = switch (c.review) {
      'approved' => ('approved', t.done),
      'changes_requested' => ('requested changes', t.crashed),
      'commented' => ('reviewed', t.textSecondary),
      'dismissed' => ('review dismissed', t.textMuted),
      _ => null,
    };
    final toggle = LinkText(
      folds
          ? (_open ? 'Hide' : 'Show')
          : _open
          ? 'Show less'
          : c.review.isEmpty
          ? 'Show the whole comment'
          : 'Show the whole review',
      size: 12,
      onTap: () => setState(() => _open = !_open),
    );
    final head = Row(
      children: [
        if (c.bot) ...[
          Icon(Icons.smart_toy_outlined, size: 13, color: t.textMuted),
          const SizedBox(width: 5),
        ],
        Text(
          c.author,
          style: theme.ui(t.text, size: 12.5, weight: FontWeight.w600),
        ),
        if (c.bot) Text('  bot', style: theme.ui(t.textMuted, size: 11.5)),
        if (c.outside && !c.bot)
          Tooltip(
            message: "Not the repository's owner, a member or a collaborator",
            child: Text('  outside', style: theme.ui(t.needs, size: 11.5)),
          ),
        if (review != null)
          Text('  ${review.$1}', style: theme.ui(review.$2, size: 11.5)),
        if (folds && !_open)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                commentSummary(c.body),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          ),
        Text(
          '  ${githubAgo(c.createdMs.toInt(), widget.now)}',
          style: theme.ui(t.textMuted, size: 11.5),
        ),
        if (!folds || _open) const Spacer(),
        if (folds) ...[const SizedBox(width: 10), toggle],
        if (widget.sendable && c.body.isNotEmpty)
          SendIcon(() async => commentReply(c)),
        if (c.url.isNotEmpty)
          IconTap(
            Icons.open_in_new,
            size: 13,
            tooltip: 'Open on GitHub',
            onTap: () => openWeb(c.url),
          ),
      ],
    );
    final clamped = long && !_open;
    final body = AgentMarkdown(
      githubText(clamped ? _start(c.body) : c.body),
      images: githubImage,
    );
    return Padding(
      padding: EdgeInsets.only(top: folds ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          if (c.body.isNotEmpty && (!folds || _open))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: clamped ? _Clamped(body) : body,
            ),
          if (long)
            Padding(padding: const EdgeInsets.only(top: 4), child: toggle),
        ],
      ),
    );
  }
}

/// [child]'s first three lines or so, fading out at the foot.
class _Clamped extends StatelessWidget {
  const new(this.child);

  final Widget child;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.55, 1],
      colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    ).createShader(r),
    child: ClipRect(
      child: SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ),
  );
}

/// [body] from its first text: a heading it starts with ("## Summary")
/// would take the lines a clamped text shows.
String _start(String body) {
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
