import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

/// The pull request page's tabs (ADR 0137).
enum PullSection { overview, commits, checks, files }

/// How a state reads (the merge status card, a segment): bad (red), warn
/// (amber), ok (green), or quiet (grey).
enum Mood { bad, warn, ok, quiet }

/// [m]'s colour.
Color moodColor(Tokens t, Mood m) => switch (m) {
  Mood.bad => t.crashed,
  Mood.warn => t.needs,
  Mood.ok => t.done,
  Mood.quiet => t.textMuted,
};

/// The soft fill behind [m]'s mark (the merge status card's tile): the
/// state's own, or for one that asks for nothing the lifted fill.
Color moodSoft(Tokens t, Mood m) => switch (m) {
  Mood.bad => t.crashedSoft,
  Mood.warn => t.needsSoft,
  Mood.ok => t.doneSoft,
  Mood.quiet => t.lifted,
};

/// What a check's state counts as: the daemon's table, githubapi.KindOf
/// (internal/githubapi/checks.go), kept the same here so a daemon of
/// either age reads alike; change both together.
enum CheckKind { passed, failed, cancelled, running, skipped }

/// A check's kind by its state (lower case): a neutral one passed; a
/// cancelled one is its own kind, drawn and named apart from a failure as
/// GitHub's page has it, though GitHub's merge gate counts it as not
/// passed (the daemon's merge blocks say so); a skipped or stale one is
/// neither; any other state is still running.
CheckKind checkKind(String state) => switch (state) {
  'success' || 'neutral' || 'completed' => CheckKind.passed,
  'failure' ||
  'error' ||
  'timed_out' ||
  'startup_failure' ||
  'action_required' => CheckKind.failed,
  'cancelled' => CheckKind.cancelled,
  'skipped' || 'stale' => CheckKind.skipped,
  _ => CheckKind.running,
};

/// A check's kind by [checkKind], the one rule the app reads: never the
/// daemon's GitHubCheck.failed, which a daemon before API 145 sends false
/// for a cancelled check and a later one true.
extension CheckKindOf on GitHubCheck {
  /// What this check's state counts as.
  CheckKind get kind => checkKind(state);
}

/// A row's counts (GitHubItem.checkCounts) by kind: the daemon's failed
/// counts the cancelled too (as the merge gate has them), and cancelled
/// says how many of those were (API 148; 0 before, when they read as
/// failed).
extension CheckCountsKinds on GitHubCheckCounts {
  /// The failed ones that weren't cancelled.
  int get failing => failed > cancelled ? failed - cancelled : 0;
}

/// A row's checks' state as its lights read it: GitHub's rollup
/// ([GitHubItem.checks]: "success", "failure", "pending"), except
/// "cancelled" where the rollup fails only because of cancelled checks,
/// which a list draws neutral rather than red.
String itemChecks(GitHubItem it) {
  final failure = it.checks == 'failure' || it.checks == 'error';
  if (!failure || !it.hasCheckCounts()) return it.checks;
  final n = it.checkCounts;
  return n.cancelled > 0 && n.failing == 0 ? 'cancelled' : it.checks;
}

/// The words that count what holds checks back: "2 failing, 1
/// cancelled", "1 cancelled", "2 failing"; empty for none.
String failingWords({required int failing, required int cancelled}) => [
  if (failing > 0) '$failing failing',
  if (cancelled > 0) '$cancelled cancelled',
].join(', ');

/// A pull request's checks, each in one group by [checkKind]: failed and
/// cancelled (each the required first), running, passed, and the rest
/// (skipped).
({
  List<GitHubCheck> failed,
  List<GitHubCheck> cancelled,
  List<GitHubCheck> running,
  List<GitHubCheck> passed,
  List<GitHubCheck> other,
})
splitChecks(GitHubPull p) {
  final failed = <GitHubCheck>[];
  final cancelled = <GitHubCheck>[];
  final running = <GitHubCheck>[];
  final passed = <GitHubCheck>[];
  final other = <GitHubCheck>[];
  for (final c in p.checks) {
    switch (checkKind(c.state)) {
      case CheckKind.failed:
        failed.add(c);
      case CheckKind.cancelled:
        cancelled.add(c);
      case CheckKind.running:
        running.add(c);
      case CheckKind.passed:
        passed.add(c);
      case CheckKind.skipped:
        other.add(c);
    }
  }
  int requiredFirst(GitHubCheck a, GitHubCheck b) =>
      (b.required ? 1 : 0) - (a.required ? 1 : 0);
  failed.sort(requiredFirst);
  cancelled.sort(requiredFirst);
  return (
    failed: failed,
    cancelled: cancelled,
    running: running,
    passed: passed,
    other: other,
  );
}

/// A pull request's checks counted, as [splitChecks] groups them.
({int failing, int cancelled, int running, int passed, int other}) countChecks(
  GitHubPull p,
) {
  final s = splitChecks(p);
  return (
    failing: s.failed.length,
    cancelled: s.cancelled.length,
    running: s.running.length,
    passed: s.passed.length,
    other: s.other.length,
  );
}

/// The reviewers still asked, not reviewed yet.
List<GitHubReviewer> waitingOn(GitHubPull p) => [
  for (final r in p.reviewers)
    if (r.state == 'requested') r,
];

const IconData closedIcon = Icons.do_not_disturb_on_outlined;

/// A cancelled check's mark where an icon is passed about (a check's
/// `checkIcon`, a list's light): [CheckMark] draws it as a stop sign, so
/// it's never taken for a skipped one's barred circle or a failed one's
/// crossed circle.
const IconData cancelledIcon = Icons.report_outlined;

/// A check's or a list's checks' mark: [icon] at [size] in [color], or
/// for [cancelledIcon] a stop sign: a solid octagon with a square cut out
/// of it.
class CheckMark extends StatelessWidget {
  const new(this.icon, {required this.size, required this.color, super.key});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => icon == cancelledIcon
      ? CustomPaint(size: Size.square(size), painter: _StopSign(color))
      : Icon(icon, size: size, color: color);
}

class _StopSign extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // A little past the outline icons' rings (20 of their 24 points), so
    // its corners show.
    final r = size.shortestSide * 11 / 24;
    final c = size.center(Offset.zero);
    final octagon = Path();
    for (var i = 0; i < 8; i++) {
      final a = pi / 8 + i * pi / 4;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? octagon.moveTo(p.dx, p.dy) : octagon.lineTo(p.dx, p.dy);
    }
    octagon.close();
    // A stop button's square cut out of it: unlike a skipped check's bar
    // or a failed one's cross.
    final square = Rect.fromCenter(center: c, width: r * 0.8, height: r * 0.8);
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawPath(octagon, Paint()..color = color)
      ..drawRect(square, Paint()..blendMode = BlendMode.clear)
      ..restore();
  }

  @override
  bool shouldRepaint(_StopSign old) => old.color != color;
}

/// What an "unstable" merge state says beside Ready to merge.
const unstableWords = 'Checks not passing (not required)';
