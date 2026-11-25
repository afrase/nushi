import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_merge_card.dart';
import 'package:nushi/pull_segments.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_overview_fixture.dart';

/// The segment [name]'s cell.
Finder _segment(String name) => find.byKey(ValueKey('segment $name'));

/// The merge status card on its own: its words, Send N to agent, its
/// segments and their lists, in both themes.
void main() {
  setUpAll(loadFonts);

  /// What Send to agent sent, in order.
  late List<(List<Reply>, String)> sent;
  late FakeDaemon fake;

  Future<Daemon> card(
    WidgetTester tester,
    GitHubPull p, {
    Tokens tokens = Tokens.dark,
    double width = 860,
    List<String> opened = const [],
  }) async {
    sent = [];
    fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetGitHubJobLogRequest() => GetGitHubJobLogResponse(
          tail: 'go test ./...\n--- FAIL: TestSafeNext\nexit code 1',
        ),
        _ => null,
      };
    final d = await fake.connect(tester);
    viewport(tester, Size(width + 32, 1000));
    await tester.pumpWidget(const SizedBox()); // a fresh card's state
    await tester.pumpWidget(
      themed(
        tokens: tokens,
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SendToAgent(
              onSend: (r, what) => sent.add((r, what)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: const ValueKey('card'),
                    child: SizedBox(
                      width: width,
                      child: MergeCard(
                        daemon: d,
                        pull: p,
                        items: todo(p).items,
                        onChanged: () async {},
                        onThread: (x) => opened.add(x.id),
                        onReview: opened.add,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return d;
  }

  test('the segments: checks, comments, approvals in a few words', () {
    String say(SegmentState s) =>
        '${s.label}: ${s.words} ${s.mood.name} '
        '${s.progress.done}/${s.progress.waiting}/${s.progress.failing}';
    expect(segmentsOf(overviewPull()).map(say), [
      'Checks: 2 failing bad 3/0/2',
      'Comments: 2 unresolved warn 1/2/0',
      'Approvals: Changes requested bad 1/1/1',
    ]);
    expect(segmentsOf(overviewPull(ready: true)).map(say), [
      'Checks: 5 passed ok 5/0/0',
      'Comments: All resolved ok 3/0/0',
      'Approvals: 2 approved ok 2/0/0',
    ]);
    final none = overviewPull(ready: true)
      ..checks.clear()
      ..threads.clear()
      ..reviewers.clear();
    expect(segmentsOf(none, findings: 2).map(say), [
      'Checks: None ok 0/0/0',
      'Comments: 2 findings warn 0/2/0',
      'Approvals: None required ok 0/0/0',
    ]);
  });

  testWidgets('one list open at a time; a click again closes it', (
    tester,
  ) async {
    final d = await card(tester, overviewPull());
    await tester.tap(_segment('checks'));
    await tester.pumpAndSettle();
    expect(find.text('CI / lint'), findsNothing); // a span, not alone
    expect(
      find.textContaining('Failing after 41s', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(_segment('approvals'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Failing after', findRichText: true),
      findsNothing,
    );
    expect(find.text('@platform-team'), findsOneWidget);
    await tester.tap(_segment('approvals'));
    await tester.pumpAndSettle();
    expect(find.text('@platform-team'), findsNothing);
    d.dispose();
  });

  testWidgets("Send 5 to agent: each blocker's reply card, together; a "
      "failing check's own Send to agent, its card", (tester) async {
    final d = await card(tester, overviewPull());
    await tester.tap(find.text('Send 5 to agent'));
    await tester.pumpAndSettle();
    final (cards, _) = sent.single;
    expect(cards.map((r) => r.from), [
      'Failed checks',
      'Failed checks',
      'Changes requested by @tomas',
      'Review comments from @tomas, @mira',
      'Review comments from @iris',
    ]);
    expect(cards.first.quote, startsWith('Check CI / test (ubuntu-latest):'));
    await tester.tap(_segment('checks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to agent').at(1));
    await tester.pumpAndSettle();
    expect(sent.last.$2, 'CI / lint');
    expect(sent.last.$1.single.quote, contains('--- FAIL: TestSafeNext'));
    d.dispose();
  });

  testWidgets("a check's ⋯: its log under it, Re-run, Open on GitHub", (
    tester,
  ) async {
    final d = await card(tester, overviewPull());
    await tester.tap(_segment('checks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    expect(find.text('Re-run'), findsOneWidget);
    expect(find.text('Open on GitHub'), findsOneWidget);
    await tester.tap(find.text('Show the log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TestSafeNext'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-run'));
    await tester.pumpAndSettle();
    expect(
      fake.calls
          .whereType<RerunGitHubChecksRequest>()
          .single
          .jobs
          .single
          .toInt(),
      41,
    );
    d.dispose();
  });

  testWidgets('a thread row shows its thread', (tester) async {
    final opened = <String>[];
    final d = await card(tester, overviewPull(), opened: opened);
    await tester.tap(_segment('comments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('auth/session.go:46–47'));
    expect(opened, ['T_session']);
    d.dispose();
  });

  testWidgets('narrow: the segments stacked, nothing past the edge', (
    tester,
  ) async {
    final d = await card(tester, overviewPull(), width: 420);
    expect(
      tester.getTopLeft(_segment('comments')).dy,
      greaterThan(tester.getBottomLeft(_segment('checks')).dy - 1),
    );
    expectTextInside(tester, 452);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('goldens, $name', (tester) async {
      var d = await card(tester, overviewPull(), tokens: tokens);
      await expectLater(
        find.byKey(const ValueKey('card')),
        matchesGoldenFile('goldens/pull_merge_card_blocked_$name.png'),
      );
      await tester.tap(_segment('checks'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('card')),
        matchesGoldenFile('goldens/pull_merge_card_checks_$name.png'),
      );
      d.dispose();
      d = await card(tester, overviewPull(ready: true), tokens: tokens);
      await expectLater(
        find.byKey(const ValueKey('card')),
        matchesGoldenFile('goldens/pull_merge_card_ready_$name.png'),
      );
      d.dispose();
      // One cancelled check among passed ones, its list open.
      d = await card(tester, cancelledPull(), tokens: tokens);
      await tester.tap(_segment('checks'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('card')),
        matchesGoldenFile('goldens/pull_merge_card_cancelled_$name.png'),
      );
      d.dispose();
    });
  }
}
