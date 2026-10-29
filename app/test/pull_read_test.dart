import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test("a comment's first words: a table's first row, plain", () {
    expect(
      commentSummary(dangerBody),
      startsWith('Review App Links · Notes: filters-malformed-q'),
    );
    expect(commentSummary('## Hello *there*\n\nmore'), 'Hello *there*');
    expect(
      commentSummary(r'Use \_this\_ [link](https://x.dev)'),
      'Use _this_ link',
    );
    expect(commentSummary('\n\n'), '');
    expect(commentSummary('x' * 300).length, 200);
  });

  test("a table's empty columns go; the rest stay as written", () {
    expect(
      githubText(
        'a\n\n| | x | |\n| --- | --- | --- |\n| | 1 | |\n| | 2 | |\nb',
      ),
      'a\n\n| x |\n| --- |\n| 1 |\n| 2 |\nb',
    );
    const full = '| a | b |\n| --- | --- |\n| 1 | 2 |';
    expect(githubText(full), full);
    // An escaped pipe is a cell's text.
    expect(
      githubText(
        r'| a \| b | |'
        '\n| --- | --- |\n| 1 | |',
      ),
      '| a \\| b |\n| --- |\n| 1 |',
    );
    expect(longText('one\ntwo'), isFalse);
    expect(longText(aiReviewBody), isTrue);
  });

  test('the readable column: 860 centred, else the least padding', () {
    expect(readablePad(1440 - 260), (1180 - 860) / 2);
    expect(readablePad(700), 20);
  });

  testWidgets("a bot's comment folds to one line; a long review shows its "
      'start, and whole on Show', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    await tester.tap(find.text('Activity 4')); // scrolled to it
    await tester.pumpAndSettle();
    // Danger's table: its first row, on one line, until Show.
    expect(find.textContaining('Review App Links · Notes'), findsOneWidget);
    expect(find.byType(Table), findsNothing);
    await tester.tap(find.text('Show').first); // Danger's
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    // The review: clamped, with Show the whole review.
    expect(find.text('Show the whole review'), findsOneWidget);
    final clamp = find.ancestor(
      of: find.textContaining('PR hygiene', findRichText: true),
      matching: find.byType(ClipRect),
    );
    expect(clamp, findsWidgets);
    await tester.tap(find.text('Show the whole review'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.takeException(), isNull);
    d.dispose();
  }, variant: _mac);

  testWidgets("the tab shows the chat's pull request as the chat asks for "
      'it: one GetGitHubPullRequest a minute, and a comment that comes '
      'while it shows is seen', (tester) async {
    final whole = fixturePull();
    final (d, fake) = await openPullTab(tester, whole);
    expect(find.text('Activity 4'), findsOneWidget);
    fake.calls.clear();
    whole.conversation.add(said('mona', 'One more thing.', age: Duration.zero));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetGitHubPullRequest>(), hasLength(1));
    expect(find.text('Activity 5'), findsOneWidget);
    expect(pullSeen.value['c'], commentTimes(whole).reduce(max));
    d.dispose();
  }, variant: _mac);

  testWidgets('the text reads in 860 points, centred, at 1440', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    await tester.tap(find.text('Activity 4'));
    await tester.pumpAndSettle();
    final pane = tester.getRect(find.byType(GitHubPullPane));
    final text = tester.getRect(
      find
          .text(
            'Thanks, the guard looks right. Two small things before '
            'this goes in.',
            findRichText: true,
          )
          .last, // To do's line of it first
    );
    final pad = readablePad(pane.width);
    // In the column: beside the avatar, in its card.
    expect(text.left, greaterThan(pane.left + pad));
    expect(text.left, lessThan(pane.left + pad + 60));
    expect(text.right, lessThanOrEqualTo(pane.right - pad + 1));
    d.dispose();
  }, variant: _mac);

  testWidgets("a table's long cells wrap in the column", (tester) async {
    final p = fixturePull();
    p.conversation.first.bot = false; // shown whole
    final (d, _) = await openPullTab(tester, p, size: const Size(1100, 900));
    await tester.tap(find.text('Activity 4'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final pane = tester.getRect(find.byType(GitHubPullPane));
    final table = tester.getRect(find.byType(Table).first);
    expect(
      table.right,
      lessThanOrEqualTo(pane.right - readablePad(pane.width) + 1),
    );
    d.dispose();
  }, variant: _mac);
}
