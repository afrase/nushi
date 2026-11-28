import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show Button, MenuIcon;
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_comments.dart';
import 'package:nushi/pull_thread_card.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_overview_fixture.dart';

/// The Overview's Comments: reviews holding their threads, plain comments
/// between them in time, the filter, a bot's comment folded.
void main() {
  setUpAll(loadFonts);

  String say(CommentItem i) =>
      '${i.comment?.author ?? '-'} '
      '${i.comment?.review ?? ''}: '
      '${i.threads.map((x) => x.id).join(' ')}';

  test('each review holds its threads by review id, the newest first '
      "with the comments; a thread whose review isn't known comes on its "
      'own', () {
    final p = overviewPull();
    expect(commentItems(p).map(say), [
      'mira : ',
      'tomas changes_requested: T_session T_middleware',
      'iris approved: T_test',
    ]);
    // An older daemon: no review ids, the reviews from the conversation.
    final old = overviewPull()..reviews.clear();
    for (final x in old.threads) {
      for (final c in x.comments) {
        c.reviewId = '';
      }
    }
    expect(commentItems(old).map(say), [
      'mira : ',
      '- : T_session',
      '- : T_middleware',
      '- : T_test',
    ]);
  });

  test('a review that said nothing and holds no thread is left out', () {
    final p = overviewPull()
      ..reviews.add(
        GitHubComment(id: 'PRR_x', author: 'iris', review: 'commented'),
      );
    expect(commentItems(p), hasLength(3));
  });

  test('filters: Unresolved keeps only open threads, under their review; '
      'Mine what I wrote or answered', () {
    final items = commentItems(overviewPull());
    expect(filtered(items, CommentFilter.unresolved, 'mira').map(say), [
      'tomas changes_requested: T_session',
      'iris approved: T_test',
    ]);
    expect(filtered(items, CommentFilter.mine, 'Mira').map(say), [
      'mira : ',
      'tomas changes_requested: T_session',
    ]);
    expect(filtered(items, CommentFilter.mine, ''), isEmpty);
  });

  late List<(List<Reply>, String)> sent;

  Future<Daemon> comments(
    WidgetTester tester,
    GitHubPull p, {
    CommentFilter start = CommentFilter.all,
    Tokens tokens = Tokens.dark,
  }) async {
    var filter = start;
    sent = [];
    final d = await FakeDaemon([]).connect(tester);
    viewport(tester, const Size(900, 1600));
    final keys = <String, GlobalKey<PullThreadState>>{};
    await tester.pumpWidget(
      themed(
        tokens: tokens,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SendToAgent(
            onSend: (r, what) => sent.add((r, what)),
            child: StatefulBuilder(
              builder: (context, setState) => PullComments(
                daemon: d,
                pull: p,
                me: 'mira',
                filter: filter,
                onFilter: (f) => setState(() => filter = f),
                onPosted: () async {},
                threadKeys: (id) => keys.putIfAbsent(id, GlobalKey.new),
                reviewKeys: (_) => GlobalKey(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return d;
  }

  testWidgets("a thread sits in its review's card; the filter narrows "
      'them', (tester) async {
    final d = await comments(tester, overviewPull());
    double y(Finder f) => tester.getTopLeft(f).dy;
    final review = find.textContaining('The fix is right', findRichText: true);
    final mira = find.textContaining('Moved it into', findRichText: true);
    final place = find.text('auth/session.go:46–47');
    final box = find.text('Leave a comment');
    final iris = find.textContaining('Looks good to me', findRichText: true);
    // The box first, then the newest: mira's comment, tomas's review
    // holding its thread, iris's approval.
    expect(y(box), lessThan(y(mira)));
    expect(y(mira), lessThan(y(review)));
    expect(y(place), greaterThan(y(review)));
    expect(y(place), lessThan(y(iris)));
    // A thread's replies stay oldest first.
    expect(
      y(find.textContaining('This duplicates', findRichText: true)),
      lessThan(y(find.textContaining('Good point', findRichText: true))),
    );
    await tester.tap(find.text('Unresolved'));
    await tester.pumpAndSettle();
    expect(find.text('auth/middleware.go:31'), findsNothing);
    expect(
      find.textContaining('Moved it into', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();
    expect(find.text('auth/session_test.go:12'), findsNothing);
    expect(
      find.textContaining('Moved it into', findRichText: true),
      findsOneWidget,
    );
    d.dispose();
  });

  testWidgets("a review's ⋯ sends it to the agent: changes requested as "
      'such; a thread its own card', (tester) async {
    final d = await comments(tester, overviewPull());
    await tester.tap(find.byTooltip('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to agent').first); // the menu's
    await tester.pumpAndSettle();
    expect(sent.single.$2, "@tomas' review");
    expect(sent.single.$1.single.from, 'Changes requested by @tomas');
    await tester.tap(find.text('Send to agent'));
    await tester.pumpAndSettle();
    expect(sent.last.$2, 'the thread on auth/session.go:46–47');
    expect(sent.last.$1.single.quote, contains('Good point, doing that now.'));
    d.dispose();
  });

  testWidgets("a bot's comment folds to its first words, Show opens it", (
    tester,
  ) async {
    final p = overviewPull()
      ..conversation.add(
        GitHubComment(
          id: 'IC_bot',
          author: 'preview-bot',
          bot: true,
          body: 'Deployed a preview.\n\nIt lives at preview.example.dev.',
          createdMs: msAgo(const Duration(minutes: 5)),
        ),
      );
    final d = await comments(tester, p);
    expect(
      find.textContaining('It lives at', findRichText: true),
      findsNothing,
    );
    // The newest, so the first Show.
    await tester.tap(find.text('Show').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('It lives at', findRichText: true),
      findsOneWidget,
    );
    d.dispose();
  });

  // Show turns into Hide without moving: it keeps its width, so the ⋯
  // after it and the summary before it stay put.
  testWidgets("a bot's Show keeps its width as it reads Hide, and the ⋯ "
      'beside it stays put', (tester) async {
    final p = overviewPull()
      ..conversation.add(
        GitHubComment(
          id: 'IC_bot',
          author: 'preview-bot',
          bot: true,
          body: 'Deployed a preview.\n\nIt lives at preview.example.dev.',
          url: 'https://github.com/example/app/pull/7#issuecomment-1',
          createdMs: msAgo(const Duration(minutes: 5)),
        ),
      );
    for (final b in renderThemes) {
      final d = await comments(
        tester,
        p,
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
      );
      // The newest, so the first Show, in the first card's head.
      final show = find
          .byWidgetPredicate((w) => w is Button && w.label == 'Show')
          .first;
      // The card's head: the Row with the author's line and the buttons.
      final row = find
          .ancestor(
            of: find.textContaining('preview-bot', findRichText: true).first,
            matching: find.byWidgetPredicate((w) => w is Row && w.spacing == 8),
          )
          .first;
      final more = find.descendant(of: row, matching: find.byType(MenuIcon));
      final card = find.ancestor(of: row, matching: find.byType(DecoratedBox));
      final at = tester.getRect(show);
      final menu = tester.getRect(more);
      final summary = tester.getRect(
        find.descendant(
          of: row,
          matching: find.textContaining('preview-bot', findRichText: true),
        ),
      );
      await render(tester, card.first, 'press_bot_comment_show_${b.name}');
      await tester.tap(show);
      await tester.pumpAndSettle();
      final hide = find.byWidgetPredicate(
        (w) => w is Button && w.label == 'Hide',
      );
      expect(tester.getRect(hide), at);
      expect(tester.getRect(more), menu);
      expect(
        tester.getRect(
          find.descendant(
            of: row,
            matching: find.textContaining('preview-bot', findRichText: true),
          ),
        ),
        summary,
      );
      await render(tester, card.first, 'press_bot_comment_hide_${b.name}');
      d.dispose();
    }
  });

  testWidgets('a comment posted lands at the top of the list, right under '
      'the box; the box and the heading stay put', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    viewport(tester, const Size(900, 1600));
    var p = overviewPull();
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => PullComments(
              daemon: d,
              pull: p,
              me: 'mira',
              filter: CommentFilter.all,
              onFilter: (_) {},
              // What GitHub answers next: the comment, just now.
              onPosted: () async => setState(
                () => p = overviewPull()
                  ..conversation.add(
                    GitHubComment(
                      id: 'IC_new',
                      author: 'mira',
                      body: 'Rebased on main.',
                      createdMs: msAgo(Duration.zero),
                    ),
                  ),
              ),
              threadKeys: (_) => GlobalKey<PullThreadState>(),
              reviewKeys: (_) => GlobalKey(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    double y(Finder f) => tester.getTopLeft(f).dy;
    final heading = y(find.text('Comments'));
    final field = find.byType(TextField).first;
    final box = tester.getRect(field);
    await tester.enterText(field, 'Rebased on main.');
    await tester.pump();
    await tester.tap(find.text('Comment'));
    await tester.pumpAndSettle();
    expect(y(find.text('Comments')), heading);
    expect(tester.getRect(field), box);
    final posted = find.textContaining('Rebased on', findRichText: true);
    final mira = find.textContaining('Moved it into', findRichText: true);
    expect(y(posted), greaterThan(box.bottom));
    expect(y(posted), lessThan(y(mira)));
    d.dispose();
  });
}
