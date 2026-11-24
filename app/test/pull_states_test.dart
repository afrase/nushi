import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'fake_web_views.dart';
import 'github_fixture.dart' show item, pull;
import 'harness.dart';

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi-gh-test',
  number: n,
  id: 'PR_$n',
  pull: true,
);

/// Chats on pull requests 1 (failing), 2 (running) and 3 (passed), and
/// one without.
List<Chat> _chats() => [
  chat('a', 'claude', 'Add Sub')..pull = _link(1),
  chat('b', 'claude', 'Add Neg', age: 5)..pull = _link(2),
  chat('c', 'codex', 'Docs', age: 10)..pull = _link(3),
  chat('d', 'claude', 'No pull request', age: 15),
];

/// The chats' pull requests' rows (from API 133 the chats' states).
final List<GitHubItem> _items = [
  item(1, 'Add Sub', checks: 'failure'),
  item(2, 'Add Neg', checks: 'pending', draft: true),
  item(3, 'Docs', checks: 'success', state: 'merged'),
];

Object? _states(Object input) => switch (input) {
  GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
    items: [
      for (final it in _items)
        if (refs.any((r) => r.number == it.ref.number)) it,
    ],
  ),
  // Whole, for a chat that's opened: its row, no thread open.
  GetGitHubPullRequest(:final ref) => GetGitHubPullResponse(
    pull: pull()
      ..item = _items.firstWhere((i) => i.ref.number == ref.number)
      ..threads.clear(),
  ),
  _ => null,
};

void main() {
  setUpAll(loadFonts);

  testWidgets("the sidebar's rows: a dot for a pull request's checks, red "
      'failing, amber running, none passed', (tester) async {
    viewport(tester, const Size(1200, 700));
    final fake = FakeDaemon(_chats())..answer = _states;
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<GetGitHubItemsRequest>();
    expect(asked, hasLength(1), reason: 'one call for every chat');
    expect(asked.single.refs.map((l) => l.number), [1, 2, 3]);
    expect(find.byTooltip('#1: checks failing'), findsOneWidget);
    expect(find.byTooltip('#2: checks running'), findsOneWidget);
    expect(find.byType(PullDot), findsNWidgets(3));
    expect(find.byTooltip('#3: checks passed'), findsNothing);
    final t = NushiTheme.of(tester.element(find.byType(PullDot).first)).t;
    Color dot(String tip) =>
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byTooltip(tip),
                        matching: find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is ChecksMark,
                        ),
                      ),
                    )
                    .painter!
                as ChecksMark)
            .color;
    expect(dot('#1: checks failing'), t.crashed);
    expect(dot('#2: checks running'), t.needs);
    // Each minute, quietly.
    await tester.pump(const Duration(minutes: 1));
    expect(fake.calls.whereType<GetGitHubItemsRequest>().last.quiet, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  for (final size in const [Size(390, 844), Size(430, 932), Size(844, 390)]) {
    testWidgets("the phone: the pull request in the chat's bar, a tap opens "
        'it (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      viewport(tester, size, ratio: 2);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = FakeDaemon(_chats())
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(chat: _chats().first),
          _ => _states(input),
        };
      final platform = PhonePlatform()..saved = pairedRecord();
      final phone = await startPhone(tester, fake, platform: platform);
      await tester.tap(find.text('Add Sub'));
      await tester.pumpAndSettle();
      final chip = find.byType(PullChip);
      expect(chip, findsOneWidget);
      expect(
        find.bySemanticsLabel('Pull request #1, Open, checks failing'),
        findsOneWidget,
      );
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
      expect(
        tester.getTopRight(chip).dx,
        lessThanOrEqualTo(size.width),
        reason: 'inside the bar',
      );
      // Its row has no checks' counts (as an older daemon's state): the
      // failing checks' mark without a number.
      await render(
        tester,
        find.byType(PhoneApp),
        'pull_phone_uncounted_${size.width.toInt()}x${size.height.toInt()}',
      );
      final opened = <Uri>[];
      fakeWebViews().open = (url) async => opened.add(url);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse('https://github.com/afrase/nushi-gh-test/pull/1'),
      ]);
      await endPhone(tester, phone);
    });
  }

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    if (rendering) ('light', Brightness.light),
  ]) {
    testWidgets("the phone's bar: the PR widget's one-line summary, $name", (
      tester,
    ) async {
      viewport(tester, const Size(390, 844), ratio: 2);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = FakeDaemon(_chats())
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(chat: _chats().first),
          // Its row: a check failing, two threads open.
          GetGitHubItemsRequest() => GetGitHubItemsResponse(
            items: [
              item(1, 'Add Sub', checks: 'failure', unresolved: 2)
                ..checkCounts = GitHubCheckCounts(failed: 1, passed: 3),
              ..._items.skip(1),
            ],
          ),
          _ => _states(input),
        };
      final platform = PhonePlatform()..saved = pairedRecord();
      final phone = await startPhone(tester, fake, platform: platform);
      await tester.tap(find.text('Add Sub'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Pull request #1, Open, checks failing, 2 open threads',
        ),
        findsOneWidget,
      );
      final chip = find.byType(PullChip);
      expect(tester.getTopRight(chip).dx, lessThanOrEqualTo(390));
      await render(tester, find.byType(PhoneApp), 'pull_phone_bar_$name');
      await endPhone(tester, phone);
    });
  }

  testWidgets("the chip opens the pull request's page", (tester) async {
    final fake = FakeDaemon(_chats())..answer = _states;
    final d = await fake.connect(tester);
    final opened = <String>[];
    await tester.pumpWidget(
      themed(PullChip(d, d.chats['a']!, onOpen: opened.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PullChip));
    expect(opened, ['https://github.com/afrase/nushi-gh-test/pull/1']);
    await closeView(tester, d);
  });

  testWidgets('the chip reads no pull request of its own: its row, as the '
      "chats' minute ask keeps it", (tester) async {
    var state = 'open';
    final fake = FakeDaemon(_chats())
      ..answer = (input) => switch (input) {
        GetGitHubItemsRequest() => GetGitHubItemsResponse(
          items: [for (final it in _items) it.deepCopy()..state = state],
        ),
        _ => _states(input),
      };
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(PullChip(d, d.chats['a']!, onOpen: (_) {})));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('#1, Open,')), findsOneWidget);
    state = 'merged';
    await tester.pump(pullWidgetPoll);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('#1, Merged')), findsOneWidget);
    await tester.pump(pullDonePoll);
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isEmpty);
    await closeView(tester, d);
  });

  testWidgets("a chat's linked issue rides on the chats' minute ask (its "
      "header chip's freshness), not an archived chat's", (tester) async {
    final issue = GitHubLink(
      host: 'github.com',
      repo: 'afrase/nushi-gh-test',
      number: 7,
      id: 'I_7',
    );
    final fake = FakeDaemon([
      ..._chats(),
      chat('e', 'claude', 'From an issue', age: 20)..github = issue,
      chat('f', 'claude', 'Archived', age: 25)
        ..github = (issue.deepCopy()..number = 8)
        ..archived = true,
    ])..answer = _states;
    final d = await fake.connect(tester);
    final states = PullStates.of(d);
    fake.calls.clear();
    await states.refresh();
    final asked = fake.calls.whereType<GetGitHubItemsRequest>().single;
    expect(asked.refs.map((r) => r.number), [1, 2, 3, 7]);
    d.dispose();
  });

  // Gates above the floor keep one test of the daemon below them (ADR
  // 0004): before the rows said their checks' commit (API 133), the
  // chats' states come from GetGitHubStates.
  testWidgets("a daemon older than the rows' checks commit is asked for the "
      'states whole', (tester) async {
    final fake = FakeDaemon(_chats())
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(apiVersion: statesFromItemsApi - 1),
        GetGitHubStatesRequest() => GetGitHubStatesResponse(items: _items),
        _ => null,
      };
    final d = await fake.connect(tester);
    final states = PullStates.of(d);
    fake.calls.clear();
    await states.refresh();
    final asked = fake.calls.whereType<GetGitHubStatesRequest>().single;
    expect(asked.items.map((l) => l.number), [1, 2, 3]);
    expect(fake.calls.whereType<GetGitHubItemsRequest>(), isEmpty);
    // Its answers kept where every reader looks: GitHubItems.
    final look = GitHubItems.of(d).look(addressOf(_link(1)));
    expect(
      (look.item?.checks, states.item(_link(1))?.checks),
      ('failure', 'failure'),
    );
    d.dispose();
  });

  // Below API 133 the rows come from ChatPull's own ask and the states
  // from GetGitHubStates: a state is put over its row, never in its place.
  testWidgets("an older daemon's state keeps what only its row says", (
    tester,
  ) async {
    final fake = FakeDaemon(_chats())
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(apiVersion: statesFromItemsApi - 1),
        GetGitHubStatesRequest() => GetGitHubStatesResponse(
          items: [item(1, 'Add  Sub ', checks: 'pending', unresolved: 1)],
        ),
        _ => null,
      };
    final d = await fake.connect(tester);
    final items = GitHubItems.of(d);
    items.put(
      item(1, 'Add Sub', checks: 'pending')
        ..additions = 12
        ..mergeState = 'blocked'
        ..head = 'feature'
        ..checkCounts = GitHubCheckCounts(running: 2),
    );
    await PullStates.of(d).refresh();
    final it = items.look(addressOf(_link(1))).item!;
    expect(
      (it.title, it.unresolved, it.additions, it.mergeState, it.head),
      ('Add Sub', 1, 12, 'blocked', 'feature'),
    );
    expect(it.checkCounts.running, 2);
    d.dispose();
  });

  testWidgets('a pull request read whole is put over its row: what only the '
      "row says stays, its checks' counts go once its checks changed", (
    tester,
  ) async {
    final fake = FakeDaemon(_chats())..answer = _states;
    final d = await fake.connect(tester);
    final items = GitHubItems.of(d);
    final states = PullStates.of(d);
    items.put(
      item(1, 'Add Sub', checks: 'pending')
        ..additions = 12
        ..mergeState = 'blocked'
        ..checkCounts = GitHubCheckCounts(running: 2),
    );
    var told = 0;
    states
      ..addListener(() => told++)
      ..put(item(1, 'Add Sub and Mul', checks: 'pending', unresolved: 1));
    var it = states.item(_link(1))!;
    expect(
      (it.title, it.unresolved, it.additions, it.mergeState),
      ('Add Sub and Mul', 1, 12, 'blocked'),
    );
    expect(it.checkCounts.running, 2);
    states.put(item(1, 'Add Sub and Mul', checks: 'failure', unresolved: 1));
    it = states.item(_link(1))!;
    expect(
      (it.checks, it.hasCheckCounts(), it.additions),
      ('failure', false, 12),
    );
    expect(told, 2);
    // A change to an item no chat has tells the states' listeners nothing.
    items.put(item(9, 'Elsewhere'));
    expect(told, 2);
    d.dispose();
  });
}
