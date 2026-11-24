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
/// either age reads alike.
enum CheckKind { passed, failed, running, skipped }

/// A check's kind by its state (lower case): a neutral one passed and a
/// cancelled one failed, as GitHub's rollup and its merge gate have it; a
/// skipped or stale one is neither; any other state is still running.
CheckKind checkKind(String state) => switch (state) {
  'success' || 'neutral' || 'completed' => CheckKind.passed,
  'failure' ||
  'error' ||
  'timed_out' ||
  'startup_failure' ||
  'action_required' ||
  'cancelled' => CheckKind.failed,
  'skipped' || 'stale' => CheckKind.skipped,
  _ => CheckKind.running,
};

/// A pull request's checks, each in one group by [checkKind]: failed (the
/// required first), running, passed, and the rest (skipped).
({
  List<GitHubCheck> failed,
  List<GitHubCheck> running,
  List<GitHubCheck> passed,
  List<GitHubCheck> other,
})
splitChecks(GitHubPull p) {
  final failed = <GitHubCheck>[];
  final running = <GitHubCheck>[];
  final passed = <GitHubCheck>[];
  final other = <GitHubCheck>[];
  for (final c in p.checks) {
    switch (checkKind(c.state)) {
      case CheckKind.failed:
        failed.add(c);
      case CheckKind.running:
        running.add(c);
      case CheckKind.passed:
        passed.add(c);
      case CheckKind.skipped:
        other.add(c);
    }
  }
  failed.sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
  return (failed: failed, running: running, passed: passed, other: other);
}

/// A pull request's checks counted, as [splitChecks] groups them.
({int failing, int running, int passed, int other}) countChecks(GitHubPull p) {
  final s = splitChecks(p);
  return (
    failing: s.failed.length,
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

/// What an "unstable" merge state says beside Ready to merge.
const unstableWords = 'Checks not passing (not required)';
