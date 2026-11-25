import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/blame.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart' show agoShort, agoShortLongest, dateTime;
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';
import 'package:re_editor/re_editor.dart';

// The Blame gutter left of a file's line numbers (issue #78): on each
// run's first line who last changed it and how long ago, in muted text,
// a hairline over each run but the first; the same look in the read-only
// source (a cell a line, built as the line is) and the editor (painted
// over the lines re_editor laid out). In a narrow pane it shows the ages
// alone, so the code keeps its room; the names are in the hovers.

/// The room the gutter's words take, at the text's size: a name cut to
/// fit and its age's column. One width whatever the lines say, so the
/// code moves once, as Blame turns on.
const double blameRoom = 156;

/// The narrow gutter's room: an age's column ([agoShortLongest]).
const double blameAgeRoom = 32;

/// The room between the gutter and the line numbers.
const double blameGap = 12;

/// The least the code keeps beside the full gutter: a pane that would
/// leave it less shows the narrow one.
const double blameCodeLeast = 320;

/// About what a source's insets, numbers and marks take beside its code:
/// a fixed guess, so the gutter's width hangs on the pane's alone.
const double _besideCode = 64;

/// What a line not committed says in the narrow gutter.
const _notCommittedShort = 'new';

/// The room between a name and its age.
const double _ageGap = 8;

/// What a view's Blame shows: its answer, and what a press on a line's
/// entry does with the commit's id.
@immutable
final class BlameShown {
  const new(this.blamed, {required this.onOpen});

  final Blamed blamed;
  final ValueChanged<String> onOpen;
}

/// How the gutter draws, for one build: its tokens, its words' style and
/// scale, the time its ages count to, and whether it's narrow, ages alone,
/// for a pane `pane` wide: one the full gutter would leave less than
/// [blameCodeLeast] of code.
final class BlameLook {
  new(
    BuildContext context, {
    required double pane,
    this.scaler = TextScaler.noScaling,
  }) : theme = NushiTheme.of(context),
       now = clock(),
       narrow =
           pane - scaler.scale(blameRoom) - blameGap - _besideCode <
           blameCodeLeast;

  final NushiTheme theme;
  final TextScaler scaler;
  final DateTime now;
  final bool narrow;

  /// The gutter's width, its words' room at [scaler].
  double get width => narrow
      ? max(scaler.scale(blameAgeRoom), _ageWidth)
      : scaler.scale(blameRoom);

  TextStyle get _style => theme.ui(theme.t.textMuted, size: 12);

  TextPainter _text(String text, {double? max}) => TextPainter(
    text: TextSpan(text: text, style: _style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: max ?? double.infinity);

  late final double _ageWidth = () {
    final p = _text(agoShortLongest);
    final w = p.width;
    p.dispose();
    return w.ceilToDouble();
  }();

  /// Whether [other] draws as this does.
  bool sameAs(BlameLook other) =>
      other.theme.t == theme.t &&
      other.scaler == scaler &&
      other.now == now &&
      other.narrow == narrow;
}

/// Paints [cell] in [box], a line's room in the gutter, whose first line
/// is [line] high: a hairline over a run's first line ([divider]), and on
/// it the author's name cut to fit and the age at the right, or "Not
/// committed"; narrow, the age alone, or "new".
void paintBlame(
  Canvas canvas,
  Rect box,
  BlameCell cell,
  BlameLook look, {
  required double line,
  required bool divider,
}) {
  if (!cell.first) return;
  final t = look.theme.t;
  if (divider) {
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, box.width, 1),
      Paint()..color = t.line,
    );
  }
  void put(TextPainter p, double x) {
    p.paint(canvas, Offset(x, box.top + (line - p.height) / 2));
    p.dispose();
  }

  final run = cell.run;
  if (look.narrow) {
    final age = look._text(
      run == null
          ? _notCommittedShort
          : agoShort(look.now.difference(authored(run))),
      max: box.width,
    );
    put(age, box.right - age.width);
    return;
  }
  if (run == null) {
    put(look._text('Not committed', max: box.width), box.left);
    return;
  }
  final age = look._ageWidth;
  final name = look._text(
    run.author.isEmpty ? 'Unknown' : run.author,
    max: max(0, box.width - age - _ageGap),
  );
  put(name, box.left);
  final ago = look._text(agoShort(look.now.difference(authored(run))));
  put(ago, box.right - ago.width);
}

/// When [run]'s commit was made, as its author says.
DateTime authored(BlameRun run) =>
    DateTime.fromMillisecondsSinceEpoch(run.authorUnixSeconds.toInt() * 1000);

/// A run's hover: its subject, the author's whole name, the date and the
/// short id, a line each.
String blameTip(BlameRun run) => [
  if (run.subject.isNotEmpty) run.subject,
  if (run.author.isNotEmpty) run.author,
  dateTime(authored(run)),
  shortId(run.commit),
].join('\n');

/// A commit's id as git shortens it.
String shortId(String commit) =>
    commit.length > 7 ? commit.substring(0, 7) : commit;

/// One line's cell in a read-only source's gutter: [cell] painted, and on
/// a run's first line its entry ([BlameEntry]), [line] high.
class BlameCellView extends StatelessWidget {
  const new({
    required this.cell,
    required this.look,
    required this.line,
    required this.divider,
    required this.onOpen,
    super.key,
  });

  final BlameCell? cell;
  final BlameLook look;
  final double line;
  final bool divider;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final cell = this.cell;
    if (cell == null || !cell.first) return const SizedBox.expand();
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CellPainter(cell, look, line: line, divider: divider),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: line,
          child: BlameEntry(cell: cell, onOpen: onOpen),
        ),
      ],
    );
  }
}

class _CellPainter extends CustomPainter {
  new(this.cell, this.look, {required this.line, required this.divider});

  final BlameCell cell;
  final BlameLook look;
  final double line;
  final bool divider;

  @override
  void paint(Canvas canvas, Size size) => paintBlame(
    canvas,
    Offset.zero & size,
    cell,
    look,
    line: line,
    divider: divider,
  );

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.cell != cell ||
      !old.look.sameAs(look) ||
      old.line != line ||
      old.divider != divider;
}

/// A run's entry, over its first line's words: its hover says the commit
/// ([blameTip]) and a press opens it ([onOpen]); a line not committed has
/// only its hover.
class BlameEntry extends StatelessWidget {
  const new({required this.cell, required this.onOpen, super.key});

  final BlameCell cell;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => switch (cell.run) {
    final run? => Tap(
      onTap: () => onOpen(run.commit),
      tooltip: blameTip(run),
      radius: NushiTheme.tag,
      child: const SizedBox.expand(),
    ),
    null => tooltip(context, 'Not committed yet', const SizedBox.expand()),
  };
}

/// The editor's Blame gutter, where re_editor laid the lines out
/// ([lines], the line numbers' own): painted as they are laid out, so it
/// scrolls with them, and each run's entry set a frame later, as the
/// change marks' (re_editor tells of its lines while it lays them out,
/// when nothing may build).
class EditorBlame extends StatefulWidget {
  const new({
    required this.lines,
    required this.cells,
    required this.line,
    required this.pane,
    required this.onOpen,
    super.key,
  });

  /// The pane's width, which sets the gutter's ([BlameLook]).
  final double pane;

  final CodeIndicatorValueNotifier lines;
  final ValueNotifier<List<BlameCell>> cells;

  /// A line's height, its words set in its middle.
  final double line;
  final ValueChanged<String> onOpen;

  @override
  State<EditorBlame> createState() => _EditorBlameState();
}

class _EditorBlameState extends State<EditorBlame> {
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    widget.lines.addListener(_laidOut);
    widget.cells.addListener(_laidOut);
  }

  @override
  void dispose() {
    widget.lines.removeListener(_laidOut);
    widget.cells.removeListener(_laidOut);
    super.dispose();
  }

  void _laidOut() {
    if (_waiting) return;
    _waiting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waiting = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final look = BlameLook(context, pane: widget.pane);
    final cells = widget.cells.value;
    return SizedBox(
      width: look.width + blameGap,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EditorPainter(
                widget.lines,
                widget.cells,
                look,
                widget.line,
              ),
            ),
          ),
          for (final p
              in widget.lines.value?.paragraphs ??
                  const <CodeLineRenderParagraph>[])
            if (cells.elementAtOrNull(p.index) case final cell? when cell.first)
              Positioned(
                left: 0,
                width: look.width,
                top: p.top,
                height: widget.line,
                child: BlameEntry(cell: cell, onOpen: widget.onOpen),
              ),
        ],
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  new(this.lines, this.cells, this.look, this.line)
    : super(repaint: Listenable.merge([lines, cells]));

  final CodeIndicatorValueNotifier lines;
  final ValueNotifier<List<BlameCell>> cells;
  final BlameLook look;
  final double line;

  @override
  void paint(Canvas canvas, Size size) {
    final all = cells.value;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (final p
        in lines.value?.paragraphs ?? const <CodeLineRenderParagraph>[]) {
      if (all.elementAtOrNull(p.index) case final cell?) {
        paintBlame(
          canvas,
          Rect.fromLTWH(0, p.top, look.width, p.height),
          cell,
          look,
          line: line,
          divider: p.index > 0,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EditorPainter old) =>
      !old.look.sameAs(look) ||
      old.line != line ||
      !identical(old.lines, lines) ||
      !identical(old.cells, cells);
}

/// Opens [commit] in [chat]'s Changes, in Commits, when Commits lists it
/// (the branch's commits, or the last 50 on the base branch itself);
/// else, an older commit or one of another repository, copies its id and
/// says so.
Future<void> openBlamedCommit(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  String commit,
) async {
  final toasts = Toasts.maybeOf(context);
  try {
    final found = await ChangeSpan.branchBase(daemon, chat);
    if (found.status.git) {
      final span = ChangeSpan(
        chat.folder,
        Scope.commits,
        found.base,
        found.status,
      );
      final listed = await daemon.client.listCommits(
        ListCommitsRequest(
          folder: chat.folder,
          base: span.onBase ? '' : found.base,
        ),
      );
      if (listed.commits.any((c) => c.hash == commit)) {
        chat.showCommit(commit);
        return;
      }
    }
  } on Object {
    // Not listed, as far as can be told: its id is the way to it.
  }
  await Clipboard.setData(ClipboardData(text: commit));
  showToast(
    toasts,
    'Copied ${shortId(commit)}: Changes’ Commits doesn’t list it',
  );
}
