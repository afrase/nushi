import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The merge status card's three segments, after GitHub's page.
enum Segment { checks, comments, approvals }

/// A segment's bar: its met (done), failing (crashed), cancelled (the
/// secondary ink: checks that hold the merge back until run again) and
/// waiting (needs) shares; all none draws it hatched, nothing to meet.
typedef Progress = ({int done, int failing, int cancelled, int waiting});

/// A segment as it shows: its label, its status in a few words, its bar,
/// and whether it holds the merge back (its `mood` bad or warn).
typedef SegmentState = ({
  Segment segment,
  String label,
  String words,
  Progress progress,
  Mood mood,
});

/// Red only when something failed: a cancelled check, like one still
/// waited on, holds the merge back without having failed.
Mood _moodOf(Progress p) => p.failing > 0
    ? Mood.bad
    : p.cancelled > 0 || p.waiting > 0
    ? Mood.warn
    : Mood.ok;

/// [p]'s segments: Checks (failing and cancelled, running, passed),
/// Comments (its review threads, and [findings], a review bot's findings
/// to address) and Approvals (its reviewers' states).
List<SegmentState> segmentsOf(GitHubPull p, {int findings = 0}) {
  SegmentState seg(Segment s, String label, String words, Progress pr) =>
      (segment: s, label: label, words: words, progress: pr, mood: _moodOf(pr));
  final n = countChecks(p);
  final checks = seg(
    Segment.checks,
    'Checks',
    n.failing > 0 || n.cancelled > 0
        ? failingWords(failing: n.failing, cancelled: n.cancelled)
        : n.running > 0
        ? '${n.running} running'
        : n.passed > 0
        ? '${n.passed} passed'
        : p.checks.isEmpty
        ? 'None'
        : 'Skipped',
    (
      done: n.passed,
      failing: n.failing,
      cancelled: n.cancelled,
      waiting: n.running,
    ),
  );
  final open = p.threads.where((x) => !x.resolved).length;
  final resolved = p.threads.length - open;
  final found = findings == 0
      ? ''
      : ', $findings finding${findings == 1 ? '' : 's'}';
  final comments = seg(
    Segment.comments,
    'Comments',
    open > 0
        ? '$open unresolved$found'
        : p.threads.isEmpty
        ? (found.isEmpty ? 'None' : found.substring(2))
        : 'All resolved$found',
    (done: resolved, failing: 0, cancelled: 0, waiting: open + findings),
  );
  var approved = 0;
  var changes = 0;
  var waiting = 0;
  for (final r in p.reviewers) {
    switch (r.state) {
      case 'approved':
        approved++;
      case 'changes_requested':
        changes++;
      case 'requested':
        waiting++;
    }
  }
  final required = p.item.review == 'review_required';
  final approvals = seg(
    Segment.approvals,
    'Approvals',
    changes > 0
        ? 'Changes requested'
        : required && approved == 0
        ? 'Approval required'
        : approved > 0
        ? '$approved approved${waiting > 0 ? ', $waiting awaited' : ''}'
        : waiting > 0
        ? '$waiting awaited'
        : 'None required',
    (
      done: approved,
      failing: changes,
      cancelled: 0,
      waiting: waiting == 0 && required && approved == 0 ? 1 : waiting,
    ),
  );
  return [checks, comments, approvals];
}

/// The segments side by side (stacked when narrow), each a label, its
/// words and its bar; a click opens its list under them ([onOpen] with
/// it, or null to close the one [open]).
class SegmentRow extends StatelessWidget {
  const new({
    required this.segments,
    required this.open,
    required this.onOpen,
    required this.narrow,
    super.key,
  });

  final List<SegmentState> segments;
  final Segment? open;
  final ValueChanged<Segment?> onOpen;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final cells = [
      for (final s in segments)
        _Cell(
          s,
          open: s.segment == open,
          onTap: () => onOpen(s.segment == open ? null : s.segment),
        ),
    ];
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cells.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            c,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cells.indexed) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, color: t.line),
            Expanded(child: c),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const new(this.s, {required this.open, required this.onTap});

  final SegmentState s;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tap(
      key: ValueKey('segment ${s.segment.name}'),
      selected: open,
      radius: 0,
      onTap: onTap,
      tooltip: open ? 'Hide the list' : 'Show the list',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Text(s.label, style: theme.ui(t.text, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.words,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(
                      s.mood == Mood.bad ? t.crashed : t.textMuted,
                      size: 12,
                      weight: s.mood == Mood.bad ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: t.textMuted,
                ),
              ],
            ),
            SegmentBar(s.progress),
          ],
        ),
      ),
    );
  }
}

/// A segment's bar: its shares in their inks (met, waiting, cancelled,
/// failing: the cancelled beside the failing, both wanting someone), or
/// hatched with nothing to meet.
class SegmentBar extends StatelessWidget {
  const new(this.p, {super.key});

  final Progress p;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final total = p.done + p.failing + p.cancelled + p.waiting;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NushiTheme.pill),
      child: SizedBox(
        height: 6,
        child: total == 0
            ? SizedBox.expand(
                child: CustomPaint(painter: _Hatch(t.line, t.lifted)),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2,
                children: [
                  if (p.done > 0)
                    Expanded(
                      flex: p.done,
                      child: ColoredBox(color: t.done),
                    ),
                  if (p.waiting > 0)
                    Expanded(
                      flex: p.waiting,
                      child: ColoredBox(color: t.needs),
                    ),
                  if (p.cancelled > 0)
                    Expanded(
                      flex: p.cancelled,
                      child: ColoredBox(color: t.textSecondary),
                    ),
                  if (p.failing > 0)
                    Expanded(
                      flex: p.failing,
                      child: ColoredBox(color: t.crashed),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Hatch extends CustomPainter {
  new(this.ink, this.fill);

  final Color ink;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), pen);
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.ink != ink || old.fill != fill;
}

/// A quiet Send to agent beside a row (an arrow alone when [narrow]):
/// beside the page's one primary, the merge button (ADR 0137).
Widget quietSend(
  BuildContext context, {
  required VoidCallback onPressed,
  bool narrow = false,
  String label = 'Send to agent',
}) {
  const tip = "A reply card in the chat's box, to send with your message";
  return narrow
      ? IconTap(
          Icons.subdirectory_arrow_right,
          size: 14,
          tooltip: label,
          onTap: onPressed,
        )
      : Button(
          label: label,
          kind: ButtonKind.quiet,
          icon: Icons.subdirectory_arrow_right,
          tooltip: tip,
          onPressed: onPressed,
        );
}
