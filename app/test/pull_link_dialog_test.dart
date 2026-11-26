import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item, testRepo;
import 'harness.dart';

// Link pull request…: the chat's repository's open pull requests to pick
// from (mine and those asking my review, each once), or a link or number
// typed; GitHub is asked for the one picked, which is linked to the chat.

/// The dialog open on chat c, in the test repository; GetGitHubPull fails
/// while [fails]; FindChatPull suggests [branch]'s pull request #4 when
/// given.
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester, {
  bool fails = false,
  String? branch,
}) async {
  viewport(tester, const Size(900, 700));
  final fake = FakeDaemon([chat('c', 'claude', 'Add Sub and Neg')])
    ..answer = (input) => switch (input) {
      FindChatPullRequest(suggest: true) when branch != null =>
        FindChatPullResponse(
          host: 'github.com',
          repo: testRepo,
          branch: branch,
          branchPull: GitHubLink(
            host: 'github.com',
            repo: testRepo,
            number: 4,
            pull: true,
          ),
        ),
      GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
        items: [
          for (final r in refs)
            if (r.number == 4) item(4, 'Add Sub and Neg'),
        ],
      ),
      ListGitHubInboxRequest() => ListGitHubInboxResponse(
        mine: [
          item(4, 'Add Sub and Neg'),
          item(3, 'An old one', state: 'merged'),
          item(9, 'An issue', pull: false),
        ],
        review: [item(4, 'Add Sub and Neg'), item(6, 'Faster parsing')],
      ),
      GetGitHubPullRequest(:final ref) when !fails => GetGitHubPullResponse(
        pull: GitHubPull(item: item(ref.number, 'Linked')),
      ),
      GetGitHubPullRequest() => throw ConnectException(
        Code.unavailable,
        'GitHub is unreachable',
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  final cp = ChatPull.of(d, d.chats['c']!)
    ..found = FindChatPullResponse(host: 'github.com', repo: testRepo);
  await tester.pumpWidget(
    themed(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => linkPull(context, cp),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (fake, d);
}

GitHubLink? _linked(FakeDaemon fake) =>
    fake.calls.whereType<LinkChatPullRequest>().lastOrNull?.pull;

void main() {
  setUpAll(loadFonts);

  testWidgets('the repository’s open pull requests, each once; one picked '
      'is linked and the dialog closes', (tester) async {
    final (fake, d) = await _open(tester);
    expect(find.text('Link pull request'), findsOne);
    final asked = fake.calls.whereType<ListGitHubInboxRequest>().single;
    expect(asked.host, 'github.com');
    expect(asked.repos, [testRepo]);
    expect(find.text('#4'), findsOne);
    expect(find.text('#6'), findsOne);
    expect(find.text('#3'), findsNothing); // merged
    expect(find.text('#9'), findsNothing); // an issue
    await tester.tap(find.text('Faster parsing'));
    await tester.pumpAndSettle();
    final link = _linked(fake)!;
    expect(
      (link.repo, link.number, link.id, link.pull),
      (testRepo, 6, 'PR_6', true),
    );
    expect(find.text('Link pull request'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('a number typed is one of the repository’s; what isn’t a pull '
      'request says so and asks nothing', (tester) async {
    final (fake, d) = await _open(tester);
    await tester.enterText(find.byType(TextField), 'not a pull');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text("That isn't a pull request's link or number."), findsOne);
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isEmpty);
    await tester.enterText(find.byType(TextField), '#12');
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetGitHubPullRequest>().single.ref.number, 12);
    expect(_linked(fake)!.number, 12);
    await closeView(tester, d);
  });

  testWidgets('Link keeps its width while it reads Linking…, so Cancel '
      'beside it stays put', (tester) async {
    final (fake, d) = await _open(tester);
    final held = Completer<GetGitHubPullResponse>();
    fake.on((input) => input is GetGitHubPullRequest ? held.future : null);
    await tester.enterText(find.byType(TextField), '12');
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    final rest = tester.getRect(button('Link'));
    final cancel = tester.getRect(button('Cancel'));
    await render(tester, find.byType(Dialog), 'busy_link_pull_idle');
    await tester.tap(button('Link'));
    await tester.pump();
    expect(tester.getRect(button('Linking…')), rest);
    await render(tester, find.byType(Dialog), 'busy_link_pull_busy');
    expect(tester.getRect(button('Cancel')), cancel);
    held.complete(
      GetGitHubPullResponse(pull: GitHubPull(item: item(12, 'Linked'))),
    );
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('GitHub not answering: why shows, the dialog stays to try '
      'again', (tester) async {
    final (fake, d) = await _open(tester, fails: true);
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GitHub is unreachable'), findsOne);
    expect(find.text('Link'), findsOne); // not Linking… any more
    expect(_linked(fake), isNull);
    await closeView(tester, d);
  });

  // The case: a new chat took the pull request its folder's
  // branch already had. The chat links it by itself only once it pushed
  // the branch; until then the dialog offers it first.
  testWidgets('the branch’s pull request is offered first, once, and '
      'linked when picked', (tester) async {
    final (fake, d) = await _open(tester, branch: 'subtract');
    expect(fake.calls.whereType<FindChatPullRequest>().single.suggest, isTrue);
    expect(
      find.text('The pull request of subtract', findRichText: true),
      findsOne,
    );
    expect(find.text('#4'), findsOne); // the inbox's too, shown once
    final top = tester.getTopLeft(find.text('#4')).dy;
    expect(top, lessThan(tester.getTopLeft(find.text('#6')).dy));
    expect(
      top,
      greaterThan(
        tester
            .getTopLeft(
              find.text('The pull request of subtract', findRichText: true),
            )
            .dy,
      ),
    );
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    expect(_linked(fake)!.number, 4);
    await closeView(tester, d);
  });

  testWidgets('no pull request on the branch: nothing offered above the '
      'list', (tester) async {
    final (_, d) = await _open(tester);
    expect(find.textContaining('The pull request of'), findsNothing);
    expect(find.text('#4'), findsOne);
    await closeView(tester, d);
  });
}
