import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

Finder get _pull => find.ancestor(
  of: find.text('Pull request').last,
  matching: find.byType(PanelWidget),
);

Finder _inPull(Finder f) => find.descendant(of: _pull, matching: f);

/// The fixture in each of the widget's states.
Map<String, GitHubPull Function()> states = {
  'running': () => fixturePull()
    ..checks.removeWhere((c) => c.failed)
    ..checks.addAll([
      for (var i = 1; i <= 6; i++)
        check('pytest (slow $i/6)', state: 'pending'),
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
      GitHubReviewer(login: 'field-data-team', state: 'approved', team: true),
    ])
    ..threads.removeWhere((x) => !x.resolved)
    ..mergeState = 'clean'
    ..merge.blocks.clear(),
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

/// Ready by its Merge control (API 96), with a failing check its base
/// doesn't require.
GitHubPull _optionalFailing() => mergePull('ready')
  ..mergeState = 'unstable'
  ..checks.add(check('lint', state: 'failure'));

/// [pullSummary] of [p] on its own.
Widget _summary(GitHubPull p, {Tokens tokens = Tokens.dark}) => themed(
  Builder(
    builder: (context) =>
        pullSummary(context, NushiTheme.of(context), number: 537, pull: p),
  ),
  tokens: tokens,
);

void main() {
  setUpAll(loadFonts);

  // An older daemon's state (before API 133) has no checks' counts: the
  // summary still says its checks fail or run, without a number.
  for (final (checks, icon, tip) in [
    ('failure', Icons.cancel_outlined, 'Checks failing'),
    ('pending', Icons.schedule, 'Checks running'),
  ]) {
    testWidgets('an item without counts says its checks: $checks', (
      tester,
    ) async {
      final it = GitHubItem(pull: true, state: 'open', checks: checks);
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => pullSummary(
              context,
              NushiTheme.of(context),
              number: 537,
              pull: null,
              item: it,
            ),
          ),
        ),
      );
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.byTooltip(tip), findsOneWidget);
      // With counts, the count says it.
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => pullSummary(
              context,
              NushiTheme.of(context),
              number: 537,
              pull: null,
              item: it.deepCopy()..checkCounts = GitHubCheckCounts(passed: 3),
            ),
          ),
        ),
      );
      expect(find.byIcon(icon), findsNothing);
    });
  }

  testWidgets("Fix checks (the badge's) and Send open threads to agent (the "
      "row's ⋯) put cards in this chat's box", (tester) async {
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      details: true,
      open: false,
    );
    final box = d.chats['c']!.draft.replies;
    await tester.tap(_inPull(find.byType(ChecksBadge)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fix checks'));
    await tester.pumpAndSettle();
    expect(box.value, hasLength(3));
    expect(box.value.first.from, startsWith('Failed checks on PR'));
    expect(box.value.first.quote, startsWith('Check CI / pytest'));
    expect(
      box.value.first.from,
      endsWith('on PR octo/tally#537 (GitHub), my pull request:'),
    );
    await tester.tap(
      _inPull(
        find.descendant(
          of: find.byType(PullRow),
          matching: find.byTooltip('Pull request'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send open threads to agent'));
    await tester.pumpAndSettle();
    expect(box.value, hasLength(5));
    expect(box.value.last.from, startsWith('Review comments from @mona'));
    d.dispose();
  }, variant: onMac);

  testWidgets("a failing check that isn't required: the summary says Ready, "
      'as the Merge control does', (tester) async {
    await tester.pumpWidget(_summary(_optionalFailing()));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byTooltip('Checks: 1 failing'), findsNothing);
    // Blocked by the control: not Ready, whatever the merge state says.
    await tester.pumpWidget(
      _summary(
        _optionalFailing()
          ..mergeState = 'clean'
          ..merge.blocks.add('rules'),
      ),
    );
    expect(find.text('Ready'), findsNothing);
  }, variant: onMac);

  testWidgets("each state's one cue under the row's title", (tester) async {
    for (final (state, cue) in [
      ('failing', 'changes requested'),
      ('ready', 'ready to merge'),
      ('merged', 'merged into main'),
      ('closed', 'closed without merging'),
    ]) {
      final (d, _) = await openPullTab(
        tester,
        states[state]!(),
        details: true,
        open: false,
      );
      expect(
        _inPull(find.textContaining(cue, findRichText: true)),
        findsOneWidget,
        reason: state,
      );
      d.dispose();
    }
  }, variant: onMac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final state in states.keys) {
      testWidgets('golden: the widget $state, $name', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          states[state]!(),
          size: const Size(1160, 760),
          details: true,
          open: false,
          brightness: brightness,
        );
        await expectLater(
          _pull,
          matchesGoldenFile('goldens/pull_widget_${state}_$name.png'),
        );
        d.dispose();
      }, variant: onMac);
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
                      for (final (s, p) in [
                        for (final s in states.keys) (s, states[s]!),
                        ('optional', _optionalFailing),
                      ])
                        Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(s, style: theme.ui(tokens.textMuted)),
                            ),
                            pullSummary(
                              context,
                              theme,
                              number: 537,
                              pull: p(),
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
    }, variant: onMac);
  }
}
