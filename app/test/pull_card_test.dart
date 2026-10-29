import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show comment, item, pull, testNow;

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
    final checks = _inCard(find.text('1 failing · 1 passed'));
    expect(checks, findsOneWidget);
    // Each count in its own color: the passed one isn't red.
    final t = NushiTheme.of(tester.element(checks)).t;
    Color? color(String words) {
      Color? found;
      tester.widget<Text>(checks).textSpan!.visitChildren((s) {
        if (s is TextSpan && s.text == words) found = s.style?.color;
        return found == null;
      });
      return found;
    }

    expect(color('1 failing'), t.crashed);
    expect(color('1 passed'), t.done);
    expect(_inCard(find.text('Checks failing')), findsOneWidget);
    expect(_inCard(find.text('5')), findsOneWidget); // comments, none new
    // Collapsed: its number and the failing count.
    await tester.tap(_inCard(find.text('Pull request')));
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

  testWidgets("the Pull request tab: the GitHub view's pull request, no "
      'Start work; its comments seen', (tester) async {
    final (d, fake) = await _app(tester, whole: pull());
    // A comment came since the chat first saw it.
    pullSeen.value = {'c': pullSeen.value['c']! - 1};
    await tester.pump();
    expect(find.text('Pull request'), findsNWidgets(2)); // the switch, the card
    await tester.tap(find.text('1 new of 5'));
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsOneWidget);
    expect(
      find.byType(PanelCard),
      findsNothing,
    ); // the panel goes, as for Changes
    expect(find.text('Add Sub and Neg', findRichText: true), findsWidgets);
    expect(find.text('Start work'), findsNothing);
    expect(find.text('Fix checks'), findsOneWidget);
    expect(find.text('Should this check for overflow?'), findsNothing);
    expect(find.text('A first look.'), findsOneWidget);
    expect(pullSeen.value['c'], greaterThan(0));
    await tester.tap(find.text('Checks · 1 failed'));
    await tester.pumpAndSettle();
    expect(find.byType(GitHubChecks), findsOneWidget);
    expect(fake.calls.whereType<GetGitHubPullRequest>().last.ref.number, 1);
    // Unlinked: the tab goes, and the chat shows.
    final was = fake.answer!;
    fake
      ..answer = ((input) => input is FindChatPullRequest
          ? FindChatPullResponse(host: 'github.com', repo: _repo, branch: 'x')
          : was(input))
      ..emit(
        EventsResponse(
          chatId: 'c',
          chat: chat('c', 'claude', 'Add Sub and Neg'),
        ),
      );
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Pull request'),
      ),
      findsNothing,
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('golden: the Pull request tab, dark', (tester) async {
    // Its comments' ages from the test's day, not the real one.
    clock = () => testNow;
    addTearDown(() => clock = DateTime.now);
    final (d, _) = await _app(tester, whole: pull());
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.tap(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Pull request'),
      ),
    );
    await tester.pumpAndSettle();
    // A comment sent to the agent: the bar counts it.
    await tester.tap(
      find
          .byTooltip(
            "Send to the agent: a reply card in the chat's box, to send",
          )
          .at(1),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/pull_tab_dark.png'),
    );
    d.dispose();
  }, variant: _mac);

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
