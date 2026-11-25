import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_check_row.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/theme/tokens.dart';

import 'pull_fixture.dart';

/// Every check state GitHub documents, lower-case, with its kind: the same
/// states and answers as the daemon's table (checkKinds in
/// internal/githubapi/checks_test.go); change both together.
const Map<String, CheckKind> _kinds = {
  'success': CheckKind.passed,
  'neutral': CheckKind.passed,
  'completed': CheckKind.passed,
  'failure': CheckKind.failed,
  'error': CheckKind.failed,
  'timed_out': CheckKind.failed,
  'startup_failure': CheckKind.failed,
  'action_required': CheckKind.failed,
  'cancelled': CheckKind.cancelled,
  'skipped': CheckKind.skipped,
  'stale': CheckKind.skipped,
  'queued': CheckKind.running,
  'in_progress': CheckKind.running,
  'pending': CheckKind.running,
  'waiting': CheckKind.running,
  'requested': CheckKind.running,
  'expected': CheckKind.running,
  '': CheckKind.running,
};

void main() {
  test('each state GitHub documents is of the kind the daemon says', () {
    for (final MapEntry(key: state, value: kind) in _kinds.entries) {
      expect(checkKind(state), kind, reason: state);
    }
  });

  test('the checks list and the lights group by kind: a cancelled one in '
      'its own group after the failed, a neutral one passed', () {
    final p = fixturePull()
      ..checks.clear()
      ..checks.addAll([
        // A daemon before cancelled was failed sends failed: false.
        check('deploy', state: 'cancelled')..failed = false,
        check('lint', state: 'neutral'),
        check('docs', state: 'skipped'),
        check('test', state: 'failure'),
        check('build', state: 'pending'),
        check('smoke', state: 'cancelled', required: true),
      ]);
    final s = splitChecks(p);
    expect(s.failed.map((c) => c.name), ['test']);
    expect(s.cancelled.map((c) => c.name), ['smoke', 'deploy']);
    expect(s.running.map((c) => c.name), ['build']);
    expect(s.passed.map((c) => c.name), ['lint']);
    expect(s.other.map((c) => c.name), ['docs']);
    final n = countChecks(p);
    expect((n.failing, n.cancelled, n.running), (1, 2, 1));
  });

  test("a check's icon: cancelled its own stop sign in the secondary "
      'ink; neutral and skipped muted', () {
    const t = Tokens.dark;
    expect(checkIcon(t, check('x', state: 'cancelled')..failed = false), (
      Icons.report_outlined,
      t.textSecondary,
    ));
    expect(checkIcon(t, check('x', state: 'neutral')), (
      Icons.remove_circle_outline,
      t.textMuted,
    ));
    expect(checkIcon(t, check('x', state: 'skipped')).$2, t.textMuted);
    expect(checkIcon(t, check('x', state: 'failure')), (
      Icons.cancel_outlined,
      t.crashed,
    ));
    expect(checkIcon(t, check('x', state: 'pending')).$2, t.needs);
    expect(checkIcon(t, check('x')).$2, t.done);
  });

  test("a row's checks: cancelled when every one that failed was "
      'cancelled; failing with a failure among them, or no counts', () {
    GitHubItem it(int failed, int cancelled) => GitHubItem(
      checks: 'failure',
      checkCounts: GitHubCheckCounts(
        passed: 16,
        failed: failed,
        cancelled: cancelled,
      ),
    );
    expect(itemChecks(it(1, 1)), 'cancelled');
    expect(it(3, 1).checkCounts.failing, 2);
    expect(itemChecks(it(3, 1)), 'failure');
    expect(itemChecks(it(1, 0)), 'failure');
    // An older daemon's row: no cancelled count, failed as before.
    expect(itemChecks(GitHubItem(checks: 'failure')), 'failure');
    expect(itemChecks(GitHubItem(checks: 'pending')), 'pending');
  });

  test('the words that count them: failing, then cancelled beside it', () {
    expect(failingWords(failing: 2, cancelled: 1), '2 failing, 1 cancelled');
    expect(failingWords(failing: 0, cancelled: 1), '1 cancelled');
    expect(failingWords(failing: 3, cancelled: 0), '3 failing');
    expect(failingWords(failing: 0, cancelled: 0), '');
  });
}
