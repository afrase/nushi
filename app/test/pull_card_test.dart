import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show comment, item, pull;

const _repo = 'afrase/nushi-gh-test';

final _link = GitHubLink(
  host: 'github.com',
  repo: _repo,
  number: 1,
  id: 'PR_1',
  pull: true,
);

/// The app on a chat whose folder is on branch subtract of the test
/// repository, the details panel shown; FindChatPull answers [found],
/// GetGitHubPull [whole].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  FindChatPullResponse? found,
  GitHubPull? whole,
  Size size = const Size(1700, 900),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  showDetails.value = true;
  collapsedCards.value = {};
  cardOrder.value = ['Pull request'];
  pullSeen.value = {};
  final c = chat('c', 'claude', 'Add Sub and Neg');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      FindChatPullRequest() =>
        found ??
            FindChatPullResponse(
              host: 'github.com',
              repo: _repo,
              branch: 'subtract',
              pull: whole == null ? null : _link,
            ),
      GetGitHubPullRequest() => GetGitHubPullResponse(pull: whole),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

Finder get _card => find.ancestor(
  of: find.text('Pull request'),
  matching: find.byType(PanelCard),
);

Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('no pull request yet: the branch, and Link…', (tester) async {
    final (d, fake) = await _app(tester);
    expect(
      _inCard(find.text('No pull request for subtract', findRichText: true)),
      findsOneWidget,
    );
    expect(_inCard(find.text('Link…')), findsOneWidget);
    expect(fake.calls.whereType<FindChatPullRequest>(), isNotEmpty);
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('not a GitHub repository, or its default branch: no card', (
    tester,
  ) async {
    var (d, _) = await _app(tester, found: FindChatPullResponse());
    expect(_card, findsNothing);
    d.dispose();
    (d, _) = await _app(
      tester,
      found: FindChatPullResponse(
        host: 'github.com',
        repo: _repo,
        branch: 'main',
        defaultBranch: true,
      ),
    );
    expect(_card, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('a draft', (tester) async {
    final (d, _) = await _app(
      tester,
      whole: pull()
        ..item = item(1, 'Add Sub and Neg', draft: true)
        ..checks.clear(),
    );
    expect(_inCard(find.text('Draft')), findsOneWidget);
    expect(_inCard(find.text('Draft: not ready to merge')), findsOneWidget);
    expect(_inCard(find.text('None')), findsOneWidget); // checks
    d.dispose();
  }, variant: _mac);

  testWidgets('open with a failing check: counted, and what blocks merging', (
    tester,
  ) async {
    final (d, _) = await _app(tester, whole: pull());
    expect(
      _inCard(find.text('#1 Add Sub and Neg', findRichText: true)),
      findsOneWidget,
    );
    expect(_inCard(find.text('Open')), findsOneWidget);
    expect(_inCard(find.text('1 failing · 1 passed')), findsOneWidget);
    expect(_inCard(find.text('Checks failing')), findsOneWidget);
    expect(_inCard(find.text('5')), findsOneWidget); // comments, none new
    // Collapsed: its number and the failing count.
    await tester.tap(find.text('Pull request'));
    await tester.pumpAndSettle();
    expect(_inCard(find.text('#1')), findsOneWidget);
    expect(_inCard(find.byIcon(Icons.close)), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('merged: no merge row; a new comment is counted', (tester) async {
    final p = pull()..item = item(1, 'Add Sub and Neg', state: 'merged');
    final (d, _) = await _app(tester, whole: p);
    expect(_inCard(find.text('Merged')), findsOneWidget);
    expect(_inCard(find.text('Checks failing')), findsNothing);
    // A comment newer than those first seen.
    pullSeen.value = {'c': pullSeen.value['c']! - 1};
    await tester.pump();
    expect(_inCard(find.text('1 new of 5')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  test('a pull request named by its link, owner/name#n or its number', () {
    expect(
      parsePullRef('https://github.com/afrase/nushi-gh-test/pull/12/files'),
      GitHubRef(host: 'github.com', repo: _repo, number: 12),
    );
    expect(
      parsePullRef('#7', host: 'github.com', repo: _repo),
      GitHubRef(host: 'github.com', repo: _repo, number: 7),
    );
    expect(
      parsePullRef('a/b#3', host: 'github.com'),
      GitHubRef(host: 'github.com', repo: 'a/b', number: 3),
    );
    expect(parsePullRef('7'), isNull); // no repository to put it in
    expect(
      parsePullRef('https://github.com/afrase/nushi-gh-test/issues/2'),
      isNull,
    );
    expect(parsePullRef('javascript:alert(1)'), isNull);
  });

  testWidgets('golden: the card, open with a failing check, dark', (
    tester,
  ) async {
    final (d, _) = await _app(
      tester,
      whole: pull()
        ..conversation.add(
          comment('octo', 'One more thing.', age: Duration.zero),
        ),
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/pull_card_dark.png'),
    );
    d.dispose();
  }, variant: _mac);
}
