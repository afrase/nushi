import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_merge_card.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pull_segments.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item;
import 'harness.dart';
import 'pull_overview_fixture.dart';

/// A row's item with these counts, as the daemon sends them: failed
/// counts the cancelled too.
GitHubItem _row({int passed = 16, int failed = 0, int cancelled = 0}) =>
    GitHubItem(
      state: 'open',
      checks: failed > 0 ? 'failure' : 'success',
      checkCounts: GitHubCheckCounts(
        passed: passed,
        failed: failed,
        cancelled: cancelled,
      ),
    );

/// The color [text]'s span is drawn in, in the rich text holding it (the
/// one holding [within], when given).
Color? _ink(WidgetTester tester, String text, {String? within}) {
  final rich = tester.widget<RichText>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(within ?? text),
    ),
  );
  Color? found;
  rich.text.visitChildren((s) {
    if (s is TextSpan && (s.text ?? '').contains(text)) {
      found = s.style?.color;
      return false;
    }
    return true;
  });
  return found;
}

/// The stop sign a cancelled check is drawn with.
final Finder _stopSign = find.byWidgetPredicate(
  (w) => w is CheckMark && w.icon == cancelledIcon,
);

void main() {
  setUpAll(loadFonts);
  const t = Tokens.dark;

  test('the Checks segment: "1 cancelled", not red; with failures beside '
      'it, both counted and red', () {
    String say(SegmentState s) =>
        '${s.words} ${s.mood.name} '
        '${s.progress.done}/${s.progress.waiting}/'
        '${s.progress.cancelled}/${s.progress.failing}';
    expect(say(segmentsOf(cancelledPull()).first), '1 cancelled warn 5/0/1/0');
    expect(
      say(segmentsOf(cancelledPull(mixed: true)).first),
      '2 failing, 1 cancelled bad 3/1/1/2',
    );
  });

  test("the merge card's line names a required cancelled check, and red "
      'only with a failure', () {
    final only = mergeView(cancelledPull(required: true))!;
    expect(only.why, '1 required check was cancelled.');
    expect(only.mood, Mood.warn);
    final mixed = mergeView(cancelledPull(required: true, mixed: true))!;
    expect(
      mixed.why,
      '2 required checks failing, 1 cancelled, checks running.',
    );
    expect(mixed.mood, Mood.bad);
  });

  test('a cancelled check is no failure for the agent to fix', () {
    expect(todo(cancelledPull()).items, isEmpty);
    expect(
      todo(cancelledPull(mixed: true)).items
          .whereType<CheckTodo>()
          .map((c) => c.check.name),
      ['test (ubuntu-latest)', 'lint'],
    );
  });

  test("a row's badge, words and light: cancelled in the secondary ink, "
      'red only with a failure', () {
    final only = badgeCounts(_row(failed: 1, cancelled: 1))!;
    expect(
      (only.passed, only.total, only.failed, only.cancelled),
      (16, 17, 0, 1),
    );
    expect(badgeColor(t, only), t.textSecondary);
    expect(checksSentence(only), '1 check cancelled');
    final mixed = badgeCounts(_row(passed: 3, failed: 3, cancelled: 1))!;
    expect(badgeColor(t, mixed), t.crashed);
    expect(checksSentence(mixed), '2 checks failing, 1 cancelled');
    expect(checksIcon(t, _row(failed: 1, cancelled: 1)), (
      icon: cancelledIcon,
      color: t.textSecondary,
      words: 'Checks cancelled',
    ));
    expect(checksIcon(t, _row(failed: 2, cancelled: 1))!.color, t.crashed);
    // An older daemon's row has no cancelled count: red, as it was.
    expect(badgeColor(t, badgeCounts(_row(failed: 1))!), t.crashed);
  });

  testWidgets('the merge card: "1 cancelled" muted, its own grey share of '
      'the bar, and its row a stop sign and "Cancelled after 30m" in the '
      'secondary ink, with no Send to agent', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final p = cancelledPull();
    viewport(tester, const Size(900, 1000));
    await tester.pumpWidget(
      themed(
        SendToAgent(
          onSend: (_, _) {},
          child: SingleChildScrollView(
            child: MergeCard(
              daemon: d,
              pull: p,
              items: todo(p).items,
              onChanged: () async {},
              onThread: (_) {},
              onReview: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final words = tester.widget<Text>(find.text('1 cancelled'));
    expect(words.style?.color, t.textMuted);
    final bar = find.descendant(
      of: find.byType(SegmentBar).first,
      matching: find.byType(ColoredBox),
    );
    final inks = [for (final b in tester.widgetList<ColoredBox>(bar)) b.color];
    expect(inks, [t.done, t.textSecondary]);
    await tester.tap(find.byKey(const ValueKey('segment checks')));
    await tester.pumpAndSettle();
    expect(_ink(tester, 'Cancelled after 30m'), t.textSecondary);
    final mark = tester.widget<CheckMark>(_stopSign);
    expect(mark.color, t.textSecondary);
    expect(find.byIcon(Icons.cancel_outlined), findsNothing);
    expect(find.text('Send to agent'), findsNothing);
    d.dispose();
  });

  testWidgets('the lists order: failed, cancelled, running, passed, the '
      'rest; the Checks tab counts "2 failing, 1 cancelled"', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final p = cancelledPull(mixed: true);
    viewport(tester, const Size(900, 1200));
    await tester.pumpWidget(
      themed(
        SendToAgent(
          onSend: (_, _) {},
          child: SingleChildScrollView(
            child: Column(
              children: [
                MergeCard(
                  daemon: d,
                  pull: p,
                  items: todo(p).items,
                  onChanged: () async {},
                  onThread: (_) {},
                  onReview: (_) {},
                ),
                GitHubChecks(daemon: d, pull: p),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('segment checks')));
    await tester.pumpAndSettle();
    double top(String name) => tester
        .getTopLeft(find.textContaining(name, findRichText: true).first)
        .dy;
    final order = ['test (ubuntu', 'CI / lint', 'smoke (linux)', 'e2e', 'vet'];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
    }
    expect(
      find.text(
        '2 failing, 1 cancelled, 1 running, 3 passed, 1 skipped',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      _ink(tester, '1 cancelled', within: '1 running, 3 passed'),
      t.textSecondary,
    );
    expect(_ink(tester, '2 failing', within: '1 running, 3 passed'), t.crashed);
    d.dispose();
  });

  testWidgets("the PR widget's summary: the stop sign and its count, not "
      'the red failing one', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) {
            ctx = context;
            return pullSummary(
              context,
              NushiTheme.of(context),
              number: 218,
              pull: null,
              item: _row(failed: 1, cancelled: 1),
            );
          },
        ),
      ),
    );
    expect(ctx.mounted, isTrue);
    expect(tester.widget<CheckMark>(_stopSign).color, t.textSecondary);
    expect(find.byIcon(Icons.cancel_outlined), findsNothing);
  });

  testWidgets("a chat's dot: the secondary ink while a check was cancelled "
      'and none failed, red once one fails; a whole read counts both', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    final states = PullStates.of(d);
    final whole = GitHubPull(
      item: item(412, 'Speed up CI', checks: 'failure'),
      checks: [
        GitHubCheck(name: 'build', state: 'success'),
        GitHubCheck(name: 'smoke', state: 'cancelled', failed: true),
      ],
    );
    states.put(whole);
    final kept = states.item(
      GitHubLink(
        host: 'github.com',
        repo: whole.item.ref.repo,
        number: 412,
        id: 'PR_412',
        pull: true,
      ),
    )!;
    expect((kept.checkCounts.failed, kept.checkCounts.cancelled), (1, 1));
    expect(itemChecks(kept), 'cancelled');
    d.dispose();
  });

  testWidgets("the fake daemon's row of a pull request with only a "
      'cancelled check counts it as the daemon does: grey, not red', (
    tester,
  ) async {
    final whole = GitHubPull(
      item: item(413, 'Trim the cache', checks: 'failure'),
      checks: [
        GitHubCheck(name: 'build', state: 'success'),
        GitHubCheck(name: 'smoke', state: 'cancelled', failed: true),
      ],
    );
    final fake = FakeDaemon([])
      ..answer = (input) => input is GetGitHubPullRequest
          ? GetGitHubPullResponse(pull: whole)
          : null;
    final d = await fake.connect(tester);
    final r = await d.client.getGitHubItems(
      GetGitHubItemsRequest(refs: [whole.item.ref]),
    );
    final row = r.items.single;
    expect(
      (
        row.checkCounts.passed,
        row.checkCounts.failed,
        row.checkCounts.cancelled,
      ),
      (1, 1, 1),
    );
    expect(itemChecks(row), 'cancelled');
    d.dispose();
  });
}
