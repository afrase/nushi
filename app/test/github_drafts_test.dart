import 'package:connectrpc/connect.dart';
import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show openView, pull, testNow;
import 'harness.dart';

/// The GitHub view in the chat's place as the app has it (main.dart's
/// main area): gone while a chat shows, back when GitHub is.
Future<void> _inPlace(WidgetTester tester, Daemon d) async {
  d.go(const GitHubPlace());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: d,
          builder: (_, _) => switch (d.place) {
            GitHubPlace() => GitHubView(d, now: testNow),
            _ => const Text('A chat'),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A look at a chat, and back to GitHub.
Future<void> _lookAtChat(WidgetTester tester, Daemon d) async {
  d.go(const ChatPlace());
  await tester.pumpAndSettle();
  expect(find.byType(TextField), findsNothing);
  d.go(const GitHubPlace());
  await tester.pumpAndSettle();
}

/// Pull request 1's Files tab, in place.
Future<(FakeDaemon, Daemon)> _files(
  WidgetTester tester, {
  Object? Function(Object input)? more,
}) async {
  final (fake, d) = await openView(
    tester,
    size: const Size(1300, 1400),
    more: more,
  );
  await _inPlace(tester, d);
  await tester.tap(find.text('Add Sub and Neg'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Files 3'));
  await tester.pumpAndSettle();
  return (fake, d);
}

Finder _box(String text) => find.widgetWithText(TextField, text);

/// Thread [id]'s draft.
String _draft(String id) =>
    commentDraft(githubDraft(pull().item.ref, 'thread $id'));

Future<void> _post(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a thread's reply outlives a look at a chat; another "
      "thread's is its own", (tester) async {
    final (fake, d) = await _files(tester);
    await tester.tap(find.text('Reply').first); // line 5's thread
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Half a reply');
    await _lookAtChat(tester, d);
    // Back on Files, the box open with the text (in To do's row too).
    expect(_box('Half a reply'), findsWidgets);
    expect(_draft('T1'), 'Half a reply');
    // The outdated thread's box starts empty, and keeps its own.
    Finder inT2(Finder f) =>
        find.descendant(of: find.byKey(const ValueKey('T2')), matching: f);
    await tester.ensureVisible(inT2(find.text('Reply')));
    await tester.tap(inT2(find.text('Reply')));
    await tester.pumpAndSettle();
    final empty = inT2(find.byType(TextField));
    expect(tester.widget<TextField>(empty).controller!.text, isEmpty);
    await tester.enterText(empty, 'About -a');
    await _lookAtChat(tester, d);
    expect(_draft('T1'), 'Half a reply');
    expect(_draft('T2'), 'About -a');
    expect(_box('Half a reply'), findsWidgets);
    expect(_box('About -a'), findsWidgets);
    expect(fake.calls.whereType<ReplyGitHubThreadRequest>(), isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a reply posted is gone from its box; one GitHub refused '
      'stays', (tester) async {
    var refuse = true;
    final (fake, d) = await _files(
      tester,
      more: (input) => input is ReplyGitHubThreadRequest && refuse
          ? throw ConnectException(Code.unavailable, 'GitHub is down')
          : null,
    );
    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fixed it.');
    await _post(tester);
    expect(find.text('GitHub is down'), findsOneWidget);
    await _lookAtChat(tester, d);
    expect(_draft('T1'), 'Fixed it.');
    expect(_box('Fixed it.'), findsWidgets);
    // Posted now: the draft goes.
    refuse = false;
    await tester.showKeyboard(_box('Fixed it.').first);
    await _post(tester);
    // The refused one never reached the fake's calls.
    expect(
      fake.calls.whereType<ReplyGitHubThreadRequest>().single.body,
      'Fixed it.',
    );
    expect(_draft('T1'), isEmpty);
    await _lookAtChat(tester, d);
    expect(_box('Fixed it.'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('emptied or cancelled, a reply is gone', (tester) async {
    final (_, d) = await _files(tester);
    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Never mind');
    await tester.enterText(find.byType(TextField).first, '');
    expect(_draft('T1'), isEmpty);
    await tester.enterText(find.byType(TextField).first, 'Never mind');
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    expect(_draft('T1'), isEmpty);
    await _lookAtChat(tester, d);
    expect(_box('Never mind'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets("an inline comment being written, the pull request's comment "
      "and the review's text outlive a look at a chat", (tester) async {
    final (fake, d) = await _files(tester);
    // Lines 3–4 picked, a comment begun.
    tester.widget<DiffBox>(find.byType(DiffBox)).onLines!(
      const LineSelection(side: PaneSide.neu, anchor: 2, focus: 3),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Call it Minus?');
    await _lookAtChat(tester, d);
    expect(find.text('Lines 3–4: a comment of your review'), findsOneWidget);
    expect(_box('Call it Minus?'), findsOneWidget);
    // The pull request's comment, in Activity.
    await tester.tap(find.text('Activity 3'));
    await tester.pumpAndSettle();
    final comment = _box('Comment on the pull request');
    await tester.ensureVisible(comment);
    await tester.enterText(comment, 'Ready when CI is.');
    await _lookAtChat(tester, d);
    expect(_box('Ready when CI is.'), findsOneWidget);
    // The review's text: kept by Cancel, gone once submitted.
    final review = find.textContaining(
      RegExp(r'^Review( \(\d+\))?…$'),
      skipOffstage: false,
    );
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Close.');
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await _lookAtChat(tester, d);
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(_box('Close.'), findsOneWidget);
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<SubmitGitHubReviewRequest>().single.body,
      'Close.',
    );
    expect(commentDraft(githubDraft(pull().item.ref, 'review')), isEmpty);
    expect(fake.calls.whereType<AddGitHubCommentRequest>(), isEmpty);
    await closeView(tester, d);
  });
}
