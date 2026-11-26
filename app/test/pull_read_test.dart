import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/pull_header.dart' show pullNarrow, pullPad;
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

void main() {
  setUpAll(loadFonts);

  test("a comment's first words: a table's first row, plain", () {
    expect(
      commentSummary(dangerBody),
      startsWith('Trial Site Links · Shelf: shelf-page-size-fix'),
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

  testWidgets("a bot's comment folds to one line; a long review shows its "
      'start, and whole on Show', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    // Danger's table: its first row, on one line, until Show.
    expect(
      find.textContaining('Trial Site Links · Shelf', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(Table), findsNothing);
    // Danger's, in its folded line.
    final show = find.descendant(
      of: find
          .ancestor(
            of: find.textContaining(
              'Trial Site Links · Shelf',
              findRichText: true,
            ),
            matching: find.byType(Row),
          )
          .first,
      matching: find.text('Show'),
    );
    await tester.ensureVisible(show);
    await tester.pumpAndSettle();
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    // The review: clamped, with Show the whole review.
    expect(find.text('Show the whole review'), findsOneWidget);
    await tester.ensureVisible(find.text('Show the whole review'));
    final clamp = find.ancestor(
      of: find.textContaining('Commit log', findRichText: true),
      matching: find.byType(ClipRect),
    );
    expect(clamp, findsWidgets);
    await tester.tap(find.text('Show the whole review'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.takeException(), isNull);
    d.dispose();
  }, variant: onMac);

  testWidgets("the tab shows the chat's pull request as the chat asks for "
      'it: one GetGitHubPullRequest a minute, and a comment that comes '
      'while it shows is seen', (tester) async {
    final whole = fixturePull();
    final (d, fake) = await openPullTab(tester, whole);
    expect(find.textContaining('One more thing.'), findsNothing);
    fake.calls.clear();
    whole.conversation.add(said('mona', 'One more thing.', age: Duration.zero));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetGitHubPullRequest>(), hasLength(1));
    expect(
      find.textContaining('One more thing.', findRichText: true),
      findsOneWidget,
    );
    expect(pullSeenComments.value['c']?[whole.item.id], whole.item.comments);
    d.dispose();
  }, variant: onMac);

  testWidgets("the text reads in the page's main column, at 1440", (
    tester,
  ) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    final pane = tester.getRect(find.byType(GitHubPullPane));
    final text = tester.getRect(
      find.text(
        'Thanks, the checks read right. Two small things, then this can land.',
        findRichText: true,
      ),
    );
    final pad = pullPad(pane.width);
    // Beside the mark, in its card; the side column at its right.
    expect(text.left, greaterThan(pane.left + pad));
    expect(text.left, lessThan(pane.left + pad + 60));
    expect(text.right, lessThanOrEqualTo(pane.right - pad - 270 - 32 + 1));
    d.dispose();
  }, variant: onMac);

  testWidgets("a table's long cells wrap in the column", (tester) async {
    final p = fixturePull();
    p.conversation.first.bot = false; // shown whole
    final (d, _) = await openPullTab(tester, p, size: const Size(1100, 900));
    await tester.ensureVisible(find.byType(Table).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final pane = tester.getRect(find.byType(GitHubPullPane));
    final table = tester.getRect(find.byType(Table).first);
    // Narrower than the page's two columns: the main one the whole width.
    expect(pane.width, lessThan(pullNarrow));
    expect(
      table.right,
      lessThanOrEqualTo(pane.right - pullPad(pane.width) + 1),
    );
    d.dispose();
  }, variant: onMac);
}
