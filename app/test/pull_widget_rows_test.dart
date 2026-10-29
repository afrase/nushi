import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Finder get _card => find.ancestor(
  of: find.text('Pull request').last,
  matching: find.byType(PanelCard),
);

Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);

/// The fixture in each of the widget's states.
Map<String, GitHubPull Function()> states = {
  'running': () => fixturePull()
    ..checks.removeWhere((c) => c.failed)
    ..checks.addAll([
      for (var i = 1; i <= 6; i++)
        check('rspec (notebooks $i/6)', state: 'pending'),
    ])
    ..item.review = 'review_required'
    ..reviewers.removeWhere((r) => !r.team)
    ..threads.removeWhere((x) => !x.resolved),
  'failing': fixturePull,
  'ready': () => fixturePull()
    ..checks.removeWhere((c) => c.failed)
    ..item.review = 'approved'
    ..reviewers.clear()
    ..reviewers.addAll([
      GitHubReviewer(login: 'mona', state: 'approved'),
      GitHubReviewer(login: 'notes-reviewers', state: 'approved', team: true),
    ])
    ..threads.removeWhere((x) => !x.resolved)
    ..mergeState = 'clean',
  // GitHub's "unstable": a check its base doesn't require didn't pass.
  'unstable': () => states['ready']!()
    ..mergeState = 'unstable'
    ..checks.add(check('lint', state: 'cancelled')),
  'draft': () => fixturePull()
    ..item.draft = true
    ..checks.removeWhere((c) => c.failed)
    ..reviewers.clear()
    ..threads.clear()
    ..conversation.clear(),
  'merged': () => fixturePull()..item.state = 'merged',
  'closed': () => fixturePull()..item.state = 'closed',
};

void main() {
  setUpAll(loadFonts);

  testWidgets("Fix checks and Address put cards in this chat's box", (
    tester,
  ) async {
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      details: true,
      open: false,
    );
    final box = d.chats['c']!.draft.replies;
    await tester.tap(_inCard(find.text('Fix checks')));
    await tester.pumpAndSettle();
    expect(box.value, hasLength(3));
    expect(box.value.first.from, startsWith('Failed checks on PR'));
    expect(box.value.first.quote, startsWith('Check CI / rspec'));
    expect(
      box.value.first.from,
      endsWith('on PR octo/notes#412 (GitHub), my pull request:'),
    );
    await tester.tap(_inCard(find.text('Address')));
    await tester.pumpAndSettle();
    expect(box.value, hasLength(5));
    expect(box.value.last.from, startsWith('Review comments from @mona'));
    d.dispose();
  }, variant: _mac);

  testWidgets('a code owner waited on; ready; closed', (tester) async {
    var (d, _) = await openPullTab(
      tester,
      states['running']!(),
      details: true,
      open: false,
    );
    expect(_inCard(find.text('@notes-reviewers')), findsOneWidget);
    expect(_inCard(find.byTooltip('Asked as a code owner')), findsOneWidget);
    expect(_inCard(find.text('checks, review')), findsOneWidget);
    d.dispose();
    (d, _) = await openPullTab(
      tester,
      states['ready']!(),
      details: true,
      open: false,
    );
    expect(_inCard(find.text('Ready to merge')), findsOneWidget);
    expect(_inCard(find.text('All 10 checks passed')), findsNothing);
    expect(
      _inCard(find.textContaining('checks passed', findRichText: true)),
      findsNothing, // two skipped: a legend, not "all passed"
    );
    d.dispose();
    // Unstable: a check its base doesn't require didn't pass. It can
    // merge, as the header says.
    (d, _) = await openPullTab(
      tester,
      states['unstable']!(),
      details: true,
      open: false,
    );
    expect(_inCard(find.text('Ready to merge')), findsOneWidget);
    expect(
      _inCard(find.text('Checks not passing (not required)')),
      findsOneWidget,
    );
    expect(_inCard(find.text('Merge blocked')), findsNothing);
    d.dispose();
    (d, _) = await openPullTab(
      tester,
      states['closed']!(),
      details: true,
      open: false,
    );
    expect(
      _inCard(
        find.text(
          'Closed without merging. Its 1 commit stays on filters-malformed-q.',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    expect(_inCard(find.text('Reopen on GitHub')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final state in states.keys) {
      testWidgets('golden: the widget $state, $name', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          states[state]!(),
          size: const Size(1100, 760),
          details: true,
          open: false,
          brightness: brightness,
        );
        await expectLater(
          _card,
          matchesGoldenFile('goldens/pull_widget_${state}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }

    testWidgets('golden: the collapsed summaries, $name', (tester) async {
      final tokens = brightness == Brightness.dark ? Tokens.dark : Tokens.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: Builder(
            builder: (context) {
              final theme = NushiTheme.of(context);
              return Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      for (final s in states.keys)
                        Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(s, style: theme.ui(tokens.textMuted)),
                            ),
                            pullSummary(
                              theme,
                              number: 412,
                              pull: states[s]!(),
                              unread: s == 'running' ? 1 : 0,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/pull_widget_collapsed_$name.png'),
      );
    }, variant: _mac);
  }
}
