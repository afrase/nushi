// An issue's comments show their reactions as a pull request's do, and
// a pill or the picker reacts on GitHub the same way (#88).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_issue.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart';
import 'harness.dart';

GitHubReaction _r(String kind, int n, {bool mine = false}) =>
    GitHubReaction(content: kind, count: n, mine: mine);

/// An issue with one comment, its reactions kept as GitHub would.
GitHubIssue _issue() => GitHubIssue(
  item: item(2, 'Add a Mul function', pull: false),
  body: 'We need `Mul(a, b int) int` beside `Add`.',
  conversation: [
    GitHubComment(
      id: 'IC_lena',
      author: 'lena',
      body: 'Overflow should wrap, as Add does.',
      createdMs: msAgo(const Duration(minutes: 20)),
      reactions: [_r('thumbs_up', 2, mine: true), _r('eyes', 1)],
    ),
  ],
);

void main() {
  setUpAll(loadFonts);

  for (final b in renderThemes) {
    testWidgets('a comment shows its reactions; a pill takes mine away, '
        'the picker adds one, ${b.name}', (tester) async {
      final issue = _issue();
      final (fake, d) = await openView(
        tester,
        size: const Size(1700, 900),
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
        more: (input) => switch (input) {
          GetGitHubIssueRequest() => GetGitHubIssueResponse(issue: issue),
          ReactGitHubRequest() => () {
            final c = issue.conversation.single;
            final now = toggled(c.reactions, input.content);
            c.reactions
              ..clear()
              ..addAll(now);
            return ReactGitHubResponse();
          }(),
          _ => null,
        },
      );
      await tester.tap(find.text('Add a Mul function'));
      await tester.pumpAndSettle();
      final pane = find.byType(GitHubIssuePane);
      final lena = find.descendant(
        of: pane,
        matching: find.byWidgetPredicate(
          (w) => w is Reactions && w.subject == 'IC_lena',
        ),
      );
      expect(lena, findsOneWidget);
      // The description has none: the daemon doesn't read an issue's own.
      expect(
        find.descendant(of: pane, matching: find.byType(Reactions)),
        findsOneWidget,
      );
      expect(find.byTooltip('You and 1 other reacted with +1'), findsOneWidget);
      expect(find.byTooltip('1 reacted with eyes'), findsOneWidget);
      await render(
        tester,
        find.byType(MaterialApp),
        'issue_reactions_${b.name}',
      );

      await tester.tap(find.byTooltip('You and 1 other reacted with +1'));
      await tester.pumpAndSettle();
      final off = fake.calls.whereType<ReactGitHubRequest>().single;
      expect(
        (off.host, off.subject, off.content, off.remove),
        ('github.com', 'IC_lena', 'thumbs_up', true),
      );
      expect(find.byTooltip('1 reacted with +1'), findsOneWidget);

      await tester.tap(
        find.descendant(of: lena, matching: find.byTooltip('Add reaction')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('react heart')));
      await tester.pumpAndSettle();
      final on = fake.calls.whereType<ReactGitHubRequest>().last;
      expect((on.subject, on.content, on.remove), ('IC_lena', 'heart', false));
      expect(find.byTooltip('You reacted with heart'), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);
  }

  renderTest('renders: the reactions in a narrow window', (tester) async {
    for (final b in Brightness.values) {
      final (_, d) = await openView(
        tester,
        size: const Size(720, 900),
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
        more: (input) => input is GetGitHubIssueRequest
            ? GetGitHubIssueResponse(issue: _issue())
            : null,
      );
      await tester.tap(find.text('Add a Mul function'));
      await tester.pumpAndSettle();
      await render(
        tester,
        find.byType(MaterialApp),
        'issue_reactions_720_${b.name}',
      );
      await closeView(tester, d);
    }
  }, variant: onMac);
}
