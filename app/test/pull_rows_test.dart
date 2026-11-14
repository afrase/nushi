import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pulls_chip.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

const _repo = 'lumen-dev/lumen';

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: _repo,
  number: n,
  id: 'PR_$n',
  pull: true,
);

GitHubItem _item(
  int n,
  String title, {
  String state = 'open',
  bool draft = false,
  String base = 'main',
  String head = '',
  int adds = 10,
  int dels = 2,
  (int, int, int, int) checks = (0, 0, 0, 0),
  int threads = 0,
  String review = '',
  String merge = 'blocked',
}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: _repo, number: n),
  id: 'PR_$n',
  pull: true,
  title: title,
  url: 'https://github.com/$_repo/pull/$n',
  state: state,
  draft: draft,
  author: 'mira-k',
  createdMs: Int64(
    fixtureNow.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
  ),
  additions: adds,
  deletions: dels,
  changedFiles: 3,
  base: base,
  head: head.isEmpty ? 'branch-$n' : head,
  unresolved: threads,
  review: review,
  mergeState: merge,
  checkCounts: GitHubCheckCounts(
    passed: checks.$1,
    failed: checks.$2,
    running: checks.$3,
    skipped: checks.$4,
  ),
  checks: checks.$2 > 0
      ? 'failure'
      : checks.$3 > 0
      ? 'pending'
      : checks.$1 > 0
      ? 'success'
      : '',
);

/// A stack: #215 merged (feed-cursor into main), #221 on it, and #224, a
/// draft on main of its own.
final Map<int, GitHubItem> _stack = {
  215: _item(
    215,
    'Cursor in store.ListPosts',
    state: 'merged',
    head: 'feed-cursor',
    adds: 88,
    dels: 20,
  ),
  221: _item(
    221,
    'Break cursor ties by post id',
    base: 'feed-cursor',
    head: 'cursor-ties',
    adds: 48,
    dels: 12,
    checks: (4, 0, 6, 0),
    threads: 2,
  ),
  224: _item(
    224,
    'Older posts link in the templates',
    draft: true,
    adds: 31,
    dels: 4,
    checks: (3, 0, 0, 0),
  ),
};

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The app on a chat with [numbers] linked (the first the primary), the
/// details panel shown.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required List<int> numbers,
  Size size = const Size(1700, 1000),
  Brightness brightness = Brightness.dark,
  Map<int, GitHubItem>? items,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = ['Pull request'];
  pullSeen.value = {};
  final known = items ?? _stack;
  final c = chat('c', 'claude', 'Paginate the feed')
    ..pull = _link(numbers.first)
    ..pulls.addAll([for (final n in numbers) _link(n)]);
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: _repo,
        branch: 'cursor-ties',
        pull: _link(numbers.first),
        pulls: [for (final n in numbers) _link(n)],
      ),
      GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
        items: [for (final r in refs) ?known[r.number]],
      ),
      GetGitHubPullRequest(:final ref) => GetGitHubPullResponse(
        pull: fixturePull()..item = known[ref.number]!,
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

void main() {
  setUpAll(loadFonts);

  test('a stack lists its base first, each right after the one it is on', () {
    String order(List<int> ns) => orderPulls([
      for (final n in ns) _link(n),
    ], (l) => _stack[l.number]).map((l) => l.number).join(' ');
    expect(order([221, 224, 215]), '215 221 224');
    expect(order([224, 215, 221]), '224 215 221');
    expect(order([224]), '224');
  });

  test('the badge counts passed of the total, skipped in neither', () {
    final it = _item(1, 't', checks: (8, 3, 0, 2));
    expect(badgeCounts(it), (passed: 8, total: 11, failed: 3, running: 0));
    expect(checksSentence(badgeCounts(it)!), '3 checks failing');
    expect(badgeCounts(_stack[215]!), isNull);
    expect(checksSentence(badgeCounts(_stack[224]!)!), '3 of 3 checks passed');
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('three pull requests: rows in stack order, "Pull requests",'
          ' the header chip +2 and its rows on hover '
          '(${width.round()}, $name)', (tester) async {
        final (d, _) = await _app(
          tester,
          numbers: [221, 224, 215],
          size: Size(width, 900),
          brightness: brightness,
        );
        // The details panel shows where it fits; narrower, the rows are
        // the header chip's hover.
        if (width > 1000) {
          expect(find.text('Pull requests'), findsOneWidget);
          expect(
            tester
                .widgetList<PullRow>(find.byType(PullRow))
                .map((r) => r.link.number),
            [215, 221, 224],
          );
          expect(
            find.textContaining('2 threads', findRichText: true),
            findsWidgets,
          );
          expect(find.text('4/10'), findsOneWidget);
        }
        expect(find.byType(PullsChip), findsOneWidget);
        expect(find.text('+2'), findsOneWidget);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'pull_rows_three_${width.round()}_$name',
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('+2')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('3 pull requests'), findsOneWidget);
        await render(
          tester,
          find.byType(NushiApp),
          'pull_rows_chip_hover_${width.round()}_$name',
        );
        await gesture.moveTo(Offset.zero);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('one pull request: one row, "Pull request", no +N ($name)', (
      tester,
    ) async {
      final (d, _) = await _app(
        tester,
        numbers: [221],
        size: const Size(1700, 700),
        brightness: brightness,
      );
      expect(find.byType(PullRow), findsOneWidget);
      expect(find.text('Pull requests'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PullsChip),
          matching: find.textContaining('+'),
        ),
        findsNothing,
      );
      await render(tester, find.byType(NushiApp), 'pull_rows_one_1700_$name');
      await tester.binding.setSurfaceSize(null);
      viewport(tester, const Size(720, 700), brightness: brightness);
      await tester.pumpAndSettle();
      expectTextInside(tester, 720);
      await render(tester, find.byType(NushiApp), 'pull_rows_one_720_$name');
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets("the badge's popover and the row's ⋯ ($name)", (tester) async {
      final (d, _) = await _app(
        tester,
        numbers: [221, 224, 215],
        brightness: brightness,
      );
      await tester.tap(find.text('4/10'));
      await tester.pumpAndSettle();
      expect(find.text('Checks · 10'), findsOneWidget);
      expect(find.text('Show checks'), findsOneWidget);
      expect(find.text('Fix checks'), findsNothing); // none failing
      await render(tester, find.byType(NushiApp), 'pull_rows_badge_$name');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // The ⋯ shows under the pointer, without moving anything.
      final row = find.byType(PullRow).at(1);
      final before = tester.getRect(find.text('4/10'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('4/10')), before);
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Pull request')),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        'Open on GitHub',
        'Copy link',
        'View changes',
        'Merge…',
        'Send open threads to agent',
        'Unlink',
      ]) {
        expect(
          find.textContaining(entry, findRichText: true),
          findsOneWidget,
          reason: entry,
        );
      }
      await render(tester, find.byType(NushiApp), 'pull_rows_menu_$name');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets("the tab's picker lists the rows; a pick is remembered "
        '($name)', (tester) async {
      final (d, fake) = await _app(
        tester,
        numbers: [221, 224, 215],
        brightness: brightness,
        size: const Size(1440, 900),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ChatHeader),
          matching: find.text('Pull request'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip("The chat's pull requests"), findsOneWidget);
      await tester.tap(find.byTooltip("The chat's pull requests"));
      await tester.pumpAndSettle();
      await render(tester, find.byType(NushiApp), 'pull_tab_picker_$name');
      await tester.tap(find.text('Older posts link in the templates').last);
      await tester.pumpAndSettle();
      expect(pickedPulls.value['c'], 'github.com/lumen-dev/lumen#224');
      expect(fake.calls.whereType<GetGitHubPullRequest>().last.ref.number, 224);
      await closeView(tester, d);
    }, variant: _mac);
  }

  testWidgets('Unlink from a row unlinks that one', (tester) async {
    final (d, fake) = await _app(tester, numbers: [221, 224, 215]);
    final row = find.byType(PullRow).last;
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Pull request')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<LinkChatPullRequest>().single;
    expect(sent.unlink.number, 224);
    expect(sent.hasPull(), isFalse);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('folded, several read their count by state and the worst '
      'checks', (tester) async {
    final (d, _) = await _app(tester, numbers: [221, 224, 215]);
    collapsedWidgets.value = {'Pull request'};
    await tester.pumpAndSettle();
    expect(find.text('2 open, 1 merged'), findsOneWidget);
    expect(find.text('6 running'), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  test('the store keys an item by host, repository in any case and number', () {
    const a = GitHubAddress(
      host: 'github.com',
      repo: 'Lumen-Dev/Lumen',
      number: 1,
      pull: true,
    );
    expect(a.key, 'github.com/lumen-dev/lumen#1');
    expect(addressOf(_link(1)).key, 'github.com/lumen-dev/lumen#1');
    expect(stateWord(_stack[224]!), 'Draft');
  });
}
