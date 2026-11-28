import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show Button, NotePill;
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_commits.dart';
import 'package:nushi/pull_side.dart';
import 'package:nushi/pull_thread_card.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_overview_fixture.dart';

/// The pull request page's parts on their own: the side column, a review
/// thread's card and the commits, in both themes.
void main() {
  setUpAll(loadFonts);

  final ref = overviewPull().item.ref;

  /// The fake, as the last [daemon] made it.
  late FakeDaemon fake;

  Future<Daemon> daemon(
    WidgetTester tester, {
    Object? Function(Object input)? answer,
  }) => (fake = FakeDaemon([])..answer = answer).connect(tester);

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Tokens tokens = Tokens.dark,
    double width = 700,
    double height = 900,
  }) async {
    viewport(tester, Size(width + 32, height));
    await tester.pumpWidget(
      themed(
        tokens: tokens,
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SendToAgent(
              onSend: (_, _) {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: const ValueKey('part'),
                    child: SizedBox(width: width, child: child),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('participants: the author first, then in order of first word', () {
    expect(participants(overviewPull()), ['mira', 'iris', 'tomas']);
  });

  test("a label's colour: six hex digits, else none", () {
    expect(labelColor('d73a4a'), isNotNull);
    expect(labelColor('xyz'), isNull);
    expect(labelColor('fff'), isNull);
  });

  testWidgets('the side column: reviewers with their states, assignees, '
      'labels, who took part; Commits opens the Commits tab', (tester) async {
    var commits = 0;
    await show(
      tester,
      PullSide(pull: overviewPull(), onCommits: () => commits++),
      width: 270,
    );
    expect(find.text('@platform-team'), findsOneWidget);
    expect(find.text('3 participants'), findsOneWidget);
    expect(find.text('bug'), findsOneWidget);
    await tester.tap(find.text('Commits'));
    expect(commits, 1);
    final empty = overviewPull()
      ..reviewers.clear()
      ..assignees.clear()
      ..labels.clear();
    await show(tester, PullSide(pull: empty, onCommits: () {}), width: 270);
    expect(find.text('No reviews'), findsOneWidget);
    expect(find.text('No one'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('a thread: an open one shows its hunk, comments, Reply and '
      'Resolve conversation; a resolved one folds, Show opens it', (
    tester,
  ) async {
    final d = await daemon(tester);
    final [open, resolved, _] = overviewPull().threads;
    await show(
      tester,
      Column(
        children: [
          PullThread(
            daemon: d,
            item: overviewPull().item,
            thread: open,
            onChanged: () async {},
          ),
          PullThread(
            daemon: d,
            item: overviewPull().item,
            thread: resolved,
            onChanged: () async {},
          ),
        ],
      ),
    );
    expect(find.text('Good point, doing that now.'), findsOneWidget);
    expect(find.text('Resolve conversation'), findsOneWidget);
    expect(find.text('Reply…'), findsOneWidget);
    expect(find.text('nit: name it target'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Unresolve conversation'), findsOneWidget);
    // Reply opens the reply box.
    await tester.tap(find.text('Reply…').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    // Resolve conversation asks GitHub.
    await tester.tap(find.text('Resolve conversation'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<ResolveGitHubThreadRequest>().single.thread,
      'T_session',
    );
    d.dispose();
  });

  // Show turns into Hide and back without moving: its width and its
  // row's height are the same folded or open, so the pills before it stay
  // put too.
  testWidgets("a folded thread's Show keeps its place and width as it "
      'reads Hide, and its pills stay put', (tester) async {
    final d = await daemon(tester);
    final [_, _, outdated] = overviewPull().threads;
    final both = outdated.deepCopy()..resolved = true;
    for (final b in renderThemes) {
      await show(
        tester,
        PullThread(
          daemon: d,
          item: overviewPull().item,
          thread: both,
          onChanged: () async {},
        ),
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
      );
      Finder button(String label) =>
          find.byWidgetPredicate((w) => w is Button && w.label == label);
      List<Rect> pills() => [
        for (final e in find.byType(NotePill).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      final at = tester.getRect(button('Show'));
      final before = pills();
      expect(before, hasLength(2));
      await render(
        tester,
        find.byKey(const ValueKey('part')),
        'press_thread_show_${b.name}',
      );
      await tester.tap(button('Show'));
      await tester.pumpAndSettle();
      expect(tester.getRect(button('Hide')), at);
      expect(pills(), before);
      await render(
        tester,
        find.byKey(const ValueKey('part')),
        'press_thread_hide_${b.name}',
      );
      await tester.tap(button('Hide'));
      await tester.pumpAndSettle();
      expect(tester.getRect(button('Show')), at);
      expect(pills(), before);
    }
    d.dispose();
  });

  testWidgets('the commits: asked when wanted, again only for a new head; '
      'newest first, an author without a login by name; capped, it says '
      'so', (tester) async {
    var total = 3;
    final d = await daemon(
      tester,
      answer: (input) => input is GetGitHubCommitsRequest
          ? overviewCommits(total: total)
          : null,
    );
    final commits = PullCommits(d, ref)..want('head 1');
    await show(tester, PullCommitsList(commits: commits));
    expect(fake.calls.whereType<GetGitHubCommitsRequest>(), hasLength(1));
    expect(
      tester.getTopLeft(find.text('Move the redirect check into safeNext')).dy,
      lessThan(tester.getTopLeft(find.text('Test the redirect target')).dy),
    );
    expect(find.text('Tomas committed 1h ago'), findsOneWidget);
    expect(find.textContaining('Showing the newest'), findsNothing);
    commits.want('head 1');
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetGitHubCommitsRequest>(), hasLength(1));
    total = 140;
    commits.want('head 2');
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<GetGitHubCommitsRequest>();
    expect(asked, hasLength(2));
    expect(asked.last.quiet, isTrue);
    expect(find.text('Showing the newest 3 of 140'), findsOneWidget);
    commits.dispose();
    d.dispose();
  });

  testWidgets('the commit trail: the newest, how many between and by whom '
      '(opens the Commits tab), the oldest', (tester) async {
    final d = await daemon(
      tester,
      answer: (input) =>
          input is GetGitHubCommitsRequest ? overviewCommits(total: 5) : null,
    );
    var all = 0;
    final commits = PullCommits(d, ref)..want('h');
    await show(tester, CommitTrail(commits: commits, onAll: () => all++));
    expect(
      find.textContaining('3 additional commits by', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('additional', findRichText: true));
    expect(all, 1);
    commits.dispose();
    d.dispose();
  });

  testWidgets('the Commits tab of a long pull request: the newest 100, '
      "newest first, said so; its first commit, sent on its own, isn't "
      'among them', (tester) async {
    final d = await daemon(
      tester,
      answer: (input) =>
          input is GetGitHubCommitsRequest ? longCommits(250) : null,
    );
    final commits = PullCommits(d, ref)..want('h');
    await show(tester, PullCommitsList(commits: commits), height: 6000);
    expect(find.text('Showing the newest 100 of 250'), findsOneWidget);
    final rows = find.byType(CommitRow);
    expect(rows, findsNWidgets(100));
    expect(
      find.descendant(of: rows.first, matching: find.text('Commit 250')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows.last, matching: find.text('Commit 151')),
      findsOneWidget,
    );
    expect(find.text('Commit 1'), findsNothing);
    commits.dispose();
    d.dispose();
  });

  testWidgets('the commit trail of a long pull request: its oldest is the '
      "first commit when the daemon sends it, else the list's oldest", (
    tester,
  ) async {
    var withFirst = true;
    final d = await daemon(
      tester,
      answer: (input) => input is GetGitHubCommitsRequest
          ? longCommits(250, withFirst: withFirst)
          : null,
    );
    final commits = PullCommits(d, ref)..want('h 1');
    await show(tester, CommitTrail(commits: commits, onAll: () {}));
    Finder row(String headline) => find.descendant(
      of: find.byType(CommitRow),
      matching: find.textContaining(RegExp('^$headline '), findRichText: true),
    );
    expect(row('Commit 250'), findsOneWidget);
    expect(row('Commit 1'), findsOneWidget);
    expect(row('Commit 151'), findsNothing);
    expect(
      find.textContaining('248 additional commits by', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row('Commit 250')).dy,
      lessThan(tester.getTopLeft(row('Commit 1')).dy),
    );
    // An older daemon sends no first: the list's oldest stands in.
    withFirst = false;
    commits.want('h 2');
    await tester.pumpAndSettle();
    expect(row('Commit 151'), findsOneWidget);
    expect(row('Commit 1'), findsNothing);
    commits.dispose();
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('goldens, $name', (tester) async {
      final d = await daemon(
        tester,
        answer: (input) =>
            input is GetGitHubCommitsRequest ? overviewCommits() : null,
      );
      await show(
        tester,
        PullSide(pull: overviewPull(), onCommits: () {}),
        tokens: tokens,
        width: 270,
      );
      await expectLater(
        find.byKey(const ValueKey('part')),
        matchesGoldenFile('goldens/pull_side_$name.png'),
      );
      final [open, resolved, outdated] = overviewPull().threads;
      await show(
        tester,
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardBox(tokens),
          child: Column(
            spacing: 12,
            children: [
              for (final x in [open, resolved, outdated])
                PullThread(
                  daemon: d,
                  item: overviewPull().item,
                  thread: x,
                  onChanged: () async {},
                ),
            ],
          ),
        ),
        tokens: tokens,
      );
      await expectLater(
        find.byKey(const ValueKey('part')),
        matchesGoldenFile('goldens/pull_thread_$name.png'),
      );
      final commits = PullCommits(d, ref)..want('h');
      await show(tester, PullCommitsList(commits: commits), tokens: tokens);
      await expectLater(
        find.byKey(const ValueKey('part')),
        matchesGoldenFile('goldens/pull_commits_$name.png'),
      );
      commits.dispose();
      d.dispose();
    });
  }
}
