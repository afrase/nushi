import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_live_card.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _repo = 'lumen-dev/lumen';

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: _repo,
  number: n,
  id: 'PR_$n',
  pull: true,
);

GitHubItem _item(
  int n, {
  String state = 'open',
  (int, int, int) checks = (2, 0, 1),
}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: _repo, number: n),
  id: 'PR_$n',
  pull: true,
  title: 'Break cursor ties by post id, so a page never repeats a post',
  url: 'https://github.com/$_repo/pull/$n',
  state: state,
  author: 'mira-k',
  createdMs: Int64(
    fixtureNow.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
  ),
  additions: 48,
  deletions: 12,
  changedFiles: 3,
  base: 'main',
  head: 'cursor-ties',
  checkCounts: GitHubCheckCounts(
    passed: checks.$1,
    failed: checks.$2,
    running: checks.$3,
  ),
);

Item _call(String id, String command, String output) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  title: command,
  input: '{"command": "$command"}',
  status: 'completed',
  text: output,
);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The app on chat c (and another, d); GetGitHubItems answers what
/// [item] gives.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required GitHubItem Function() item,
  Size size = const Size(1700, 900),
  Brightness brightness = Brightness.dark,
  List<GitHubLink> pulls = const [],
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Paginate the feed')
    ..pulls.addAll(pulls)
    ..pull = pulls.isEmpty ? GitHubLink() : pulls.first;
  if (pulls.isEmpty) c.clearPull();
  final fake = FakeDaemon([c, chat('d', 'claude', 'Another chat')])
    ..answer = (input) => switch (input) {
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: _repo,
        branch: 'cursor-ties',
        pull: pulls.isEmpty ? null : pulls.first,
        pulls: pulls,
      ),
      GetGitHubItemsRequest() => GetGitHubItemsResponse(items: [item()]),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// The tool call [it] completes in chat c; the chat then links what it
/// opened, as the daemon does.
Future<void> _completes(
  WidgetTester tester,
  FakeDaemon fake,
  Item it, {
  List<GitHubLink>? pulls,
}) async {
  fake.emit(
    EventsResponse(
      chatId: 'c',
      seq: Int64(10),
      item: ItemEvent(item: it),
    ),
  );
  if (pulls != null) {
    fake.emit(
      EventsResponse(
        chatId: 'c',
        chat: chat('c', 'claude', 'Paginate the feed')
          ..pull = pulls.first
          ..pulls.addAll(pulls),
      ),
    );
  }
  await tester.pumpAndSettle();
  // The card's ask, gathered.
  await tester.pump(GitHubItems.gather);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  test('what a tool call did to a pull request', () {
    final c = ChatState('c', '/f')
      ..linkPull(_link(221), all: [_link(215), _link(221)]);
    bool known(String h) => h == 'github.com';
    final opened = livePullOf(
      _call(
        't',
        'gh pr create --fill',
        'https://evil.example/a/b/pull/1\nhttps://github.com/$_repo/pull/221',
      ),
      c,
      known,
    );
    expect(opened?.address.number, 221);
    expect(opened?.merged, isFalse);
    expect(
      livePullOf(
        _call('t', 'gh pr merge 215 --squash', 'Merged'),
        c,
        known,
      )?.address.number,
      215,
    );
    expect(
      livePullOf(
        _call('t', 'gh pr merge --squash', ''),
        c,
        known,
      )?.address.number,
      221,
    );
    // Not the chat's: no card.
    expect(livePullOf(_call('t', 'gh pr merge 9', ''), c, known), isNull);
    expect(
      livePullOf(
        _call('t', 'gh pr view 221', 'https://github.com/$_repo/pull/221'),
        c,
        known,
      ),
      isNull,
    );
    expect(
      livePullOf(
        _call('t', 'gh pr create', 'https://evil.example/a/b/pull/1'),
        c,
        known,
      ),
      isNull,
    );
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('opened: a card after the call, until the chat is left '
          '(${width.round()}, $name)', (tester) async {
        final (d, fake) = await _app(
          tester,
          item: () => _item(221),
          size: Size(width, 700),
          brightness: brightness,
        );
        await _completes(
          tester,
          fake,
          _call(
            't1',
            'gh pr create --base main --fill',
            'https://github.com/$_repo/pull/221',
          ),
          pulls: [_link(221)],
        );
        expect(find.byType(LivePullCard), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('1 check running'), findsNothing);
        expect(find.text('Checks running'), findsOneWidget);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'pull_live_opened_${width.round()}_$name',
        );
        // A click opens the Pull request tab on it.
        await tester.tap(find.byType(LivePullCard));
        await tester.pumpAndSettle();
        expect(find.byType(GitHubPullPane), findsOneWidget);
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('merged, and before GitHub answers ($name)', (tester) async {
      var answered = false;
      final (d, fake) = await _app(
        tester,
        item: () => answered ? _item(221, state: 'merged') : GitHubItem(),
        brightness: brightness,
        pulls: [_link(221)],
      );
      await _completes(
        tester,
        fake,
        _call(
          't2',
          'gh pr merge 221 --squash',
          '✓ Squashed and merged pull request #221',
        ),
      );
      expect(find.byType(LivePullCard), findsOneWidget);
      expect(find.textContaining('lumen-dev/lumen #221'), findsOneWidget);
      await render(tester, find.byType(NushiApp), 'pull_live_asking_$name');
      answered = true;
      await _completes(
        tester,
        fake,
        _call('t3', 'gh pr merge 221 --squash', 'Merged'),
      );
      expect(find.text('Merged'), findsWidgets);
      await render(tester, find.byType(NushiApp), 'pull_live_merged_$name');
      // Another chat, and back: gone.
      d.select('d');
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      expect(find.byType(LivePullCard), findsNothing);
      await closeView(tester, d);
    }, variant: _mac);
  }

  testWidgets('failing checks say so on the card', (tester) async {
    final (d, fake) = await _app(
      tester,
      item: () => _item(221, checks: (1, 2, 0)),
    );
    await _completes(
      tester,
      fake,
      _call('t1', 'gh pr create', 'https://github.com/$_repo/pull/221'),
      pulls: [_link(221)],
    );
    expect(find.text('2 checks failing'), findsOneWidget);
    await render(tester, find.byType(NushiApp), 'pull_live_failing');
    await closeView(tester, d);
  }, variant: _mac);
}
