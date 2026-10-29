import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/pull_header.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

String _move(GitHubPull p, int todo) {
  final m = moveWords(p, todo);
  return '${m.lead} ${m.rest}'.trim();
}

void main() {
  setUpAll(loadFonts);

  test('whose move it is', () {
    final p = fixturePull();
    expect(
      _move(p, 5),
      'Your move. 5 things block the merge. After them, @notes-reviewers '
      'has to approve.',
    );
    p.reviewers.removeWhere((r) => r.team);
    expect(_move(p, 1), 'Your move. 1 thing blocks the merge.');
    // Nothing to do: the checks run, then the code owners approve.
    final q = fixturePull()
      ..checks.removeWhere((c) => c.failed)
      ..checks.first.state = 'pending'
      ..item.review = 'review_required'
      ..reviewers.removeWhere((r) => !r.team);
    expect(
      _move(q, 0),
      'Waiting on checks. 1 running. Then @notes-reviewers has to approve.',
    );
    q.checks.first.state = 'success';
    expect(
      _move(q, 0),
      'Waiting on @notes-reviewers. Approval required as code owner.',
    );
    q
      ..reviewers.clear()
      ..mergeState = 'clean';
    expect(_move(q, 0), 'Ready to merge.');
    // GitHub's "unstable": checks fail that its base doesn't require.
    q.mergeState = 'unstable';
    expect(_move(q, 0), 'Ready to merge. Checks not passing (not required).');
    q.mergeState = 'behind';
    expect(_move(q, 0), 'Your move. The branch is behind main.');
    q.item.draft = true;
    expect(_move(q, 0), 'Draft. Mark it ready for review when it is.');
    q.item.state = 'merged';
    expect(_move(q, 0), 'Merged. Into main.');
    q.item.state = 'closed';
    expect(_move(q, 0), 'Closed. Without merging.');
  });

  test('the status lights', () {
    final p = fixturePull();
    final l = pullLights(p);
    String say(Light l) => '${l.name}: ${l.value} (${l.sub})';
    expect(l.map(say), [
      'Checks: 3 failing (8 passed · 2 skipped)',
      'Review: Changes requested (mona · code owner waiting)',
      'Threads: 2 unresolved (1 resolved)',
      'Branch: No conflicts (Merges into main)',
    ]);
    expect(l.map((l) => l.mood), [Mood.bad, Mood.bad, Mood.warn, Mood.ok]);
    p
      ..mergeable = 'conflicting'
      ..checks.clear()
      ..threads.clear()
      ..reviewers.clear()
      ..item.review = '';
    expect(pullLights(p).map(say), [
      'Checks: None (None yet)',
      'Review: None yet (No reviewers asked)',
      'Threads: None (No review threads)',
      'Branch: Conflicts (With main)',
    ]);
  });

  for (final (light, section) in [
    ('3 failing', GitHubChecks),
    ('No conflicts', GitHubFiles),
  ]) {
    testWidgets('a light jumps to its section: $light', (tester) async {
      final (d, _) = await openPullTab(tester, fixturePull());
      expect(find.byType(section), findsNothing);
      await tester.tap(find.text(light));
      await tester.pumpAndSettle();
      expect(find.byType(section), findsOneWidget);
      // Scrolled to it: the section's tabs as near the top as it goes.
      final tabs = tester.getRect(find.text('Files 12')).top;
      expect(tabs, lessThan(section == GitHubFiles ? 100 : 600));
      d.dispose();
    }, variant: _mac);
  }

  testWidgets('narrow: the buttons go under the branches', (tester) async {
    // Opened wide (narrow, the tabs fold into a menu), then narrowed.
    final (d, _) = await openPullTab(tester, fixturePull());
    tester.view.physicalSize = const Size(720, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.getRect(
      find.text("Ignore q params that aren't hashes in admin filters"),
    );
    final review = tester.getRect(find.text('Review…'));
    expect(review.top, greaterThan(title.bottom));
    d.dispose();
  }, variant: _mac);
}
