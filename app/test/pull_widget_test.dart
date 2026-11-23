import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/line_icons.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/pull_merge_card.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item, pull;
import 'harness.dart';

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
  bool details = true,
  bool archived = false,
}) async {
  showDetails.value = details;
  collapsedWidgets.value = {};
  widgetOrder.value = ['Pull request'];
  pullSeen.value = {};
  final c = chat('c', 'claude', 'Add Sub and Neg');
  if (archived) {
    c
      ..archived = true
      ..pull = _link
      ..pulls.add(_link);
  }
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
  final d = await openApp(tester, fake, size: size);
  return (d, fake);
}

Finder get _pull => find.ancestor(
  of: find.text('Pull request'),
  matching: find.byType(PanelWidget),
);

Finder _inPull(Finder f) => find.descendant(of: _pull, matching: f);

/// The first row's ⋯.
Finder get _rowMenu => _inPull(
  find.descendant(
    of: find.byType(PullRow),
    matching: find.byTooltip('Pull request'),
  ),
);

/// From now on FindChatPull finds #1 (opened since) and links it, so the
/// chat list says it too, and GetGitHubPull answers it whole.
void _opened(FakeDaemon fake) => fake.answer = (input) => switch (input) {
  FindChatPullRequest(:final chatId) => FindChatPullResponse(
    host: 'github.com',
    repo: _repo,
    branch: 'subtract',
    pull: (fake.chats.firstWhere((c) => c.id == chatId)..pull = _link).pull,
  ),
  GetGitHubPullRequest() => GetGitHubPullResponse(pull: pull()),
  _ => null,
};

int _asks(FakeDaemon fake) =>
    fake.calls.whereType<FindChatPullRequest>().length;

/// The header's Pull request tab: there once one is linked.
Finder get _tab => find.descendant(
  of: find.byType(ChatHeader),
  matching: find.text('Pull request'),
);

/// The time the app sees ([clock]), moved by hand ([_later]); each test
/// starts at [_start].
final DateTime _start = fixtureNow;
DateTime _now = _start;

/// [d] later, on the clock and the timers.
Future<void> _later(WidgetTester tester, Duration d) async {
  _now = _now.add(d);
  await tester.pump(d);
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    _now = _start;
    clock = () => _now;
  });

  // The owner's report: a chat whose widget said "No pull request for x"
  // didn't link the one opened since; only the details panel's widget
  // asked each minute, so with the panel hidden (or another tab) nothing
  // asked again.
  testWidgets('the details panel hidden: asked each minute all the same, '
      'and one opened since is linked', (tester) async {
    final (d, fake) = await _app(tester, details: false);
    expect(find.byType(PanelWidget), findsNothing);
    expect(_tab, findsNothing);
    final asked = _asks(fake);
    expect(asked, 1);
    _opened(fake);
    await _later(tester, const Duration(seconds: 59));
    expect(_asks(fake), asked);
    await _later(tester, const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_asks(fake), asked + 1);
    expect(d.chats['c']!.pull?.number, 1);
    expect(_tab, findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('an ask the daemon was gone for is asked again once it is '
      'back, not a minute later', (tester) async {
    final (d, fake) = await _app(tester);
    fake.answer = (input) => input is FindChatPullRequest
        ? throw ConnectException(
            Code.unavailable,
            'daemon unavailable: connection lost',
          )
        : null;
    await _later(tester, const Duration(minutes: 1)); // the timer's ask
    final asked = _asks(fake);
    expect(d.chats['c']!.pull, isNull);
    _opened(fake);
    await fake.restart(tester);
    expect(_asks(fake), asked + 1);
    expect(d.chats['c']!.pull?.number, 1);
    expect(_tab, findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('the widget collapsed: linked within a minute; its tooltip says '
      'when it last looked and how often', (tester) async {
    final (d, fake) = await _app(tester);
    collapsedWidgets.value = {'Pull request'};
    await tester.pumpAndSettle();
    expect(_inPull(find.text('None')), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await _later(tester, const Duration(seconds: 20));
    final title = _inPull(find.text('Pull request'));
    await mouse.moveTo(tester.getCenter(title));
    await tester.pump();
    expect(find.byTooltip('Checked 20 s ago · every minute'), findsOneWidget);
    await mouse.moveTo(Offset.zero); // the grip in the summary's place
    _opened(fake);
    await _later(tester, const Duration(seconds: 40));
    await tester.pumpAndSettle();
    expect(_inPull(find.text('#1')), findsOneWidget);
    await _later(tester, const Duration(seconds: 5));
    await mouse.moveTo(tester.getCenter(title));
    await tester.pump();
    expect(find.byTooltip('Checked 5 s ago · every minute'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('asked 3 s after a push (in a cd … &&) and after a turn ends, '
      'and as the window comes to the front', (tester) async {
    final (d, fake) = await _app(tester, details: false);
    var asked = _asks(fake);
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(
          item: Item(
            id: 't1',
            kind: ItemKind.ITEM_KIND_TOOL_CALL,
            title: 'cd /Users/me/nushi && git push -u origin HEAD',
            status: 'completed',
          ),
        ),
      ),
    );
    await _later(tester, const Duration(seconds: 2));
    expect(_asks(fake), asked);
    await _later(tester, const Duration(seconds: 1));
    expect(_asks(fake), ++asked);
    // A turn: started, then ended.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(2),
        status: ChatStatus(busy: true, started: Int64(1000)),
      ),
    );
    await _later(tester, const Duration(seconds: 5));
    fake.emit(EventsResponse(chatId: 'c', seq: Int64(3), status: ChatStatus()));
    await _later(tester, const Duration(seconds: 3));
    expect(_asks(fake), ++asked);
    // The window to the front: asked, unless it was within the minute
    // (ADR 0140). Away, every 5 minutes.
    final binding = tester.binding;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_asks(fake), asked);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _later(tester, const Duration(minutes: 1)); // the minute's ask
    expect(_asks(fake), ++asked);
    await _later(tester, const Duration(minutes: 2));
    expect(_asks(fake), asked, reason: 'away: 5 minutes on');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_asks(fake), ++asked);
    d.dispose();
  }, variant: onMac);

  test('the tooltip: when last checked and how often', () {
    final at = DateTime(2026, 10, 29, 12);
    expect(
      checkedWords(at, pullWidgetPoll, at.add(const Duration(seconds: 20))),
      'Checked 20 s ago · every minute',
    );
    expect(
      checkedWords(at, pullDonePoll, at.add(const Duration(minutes: 3))),
      'Checked 3 min ago · every 15 minutes',
    );
    expect(
      checkedWords(null, pullWidgetPoll, at),
      'Not checked yet · every minute',
    );
  });

  testWidgets('no pull request linked: the branch, and Link…', (tester) async {
    final (d, fake) = await _app(tester);
    expect(
      _inPull(
        find.text('No pull request linked for subtract', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(_inPull(find.text('Link…')), findsOneWidget);
    expect(fake.calls.whereType<FindChatPullRequest>(), isNotEmpty);
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isEmpty);
    d.dispose();
  }, variant: onMac);

  // The owner's report: old chats had pull requests opened after they
  // were archived. An archived chat finds nothing new; its rows are asked
  // with the chat named, so the daemon drops one opened outside its life.
  testWidgets('an archived chat asks for its rows, never to find one', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, archived: true, whole: pull());
    expect(_asks(fake), 0);
    final rows = fake.calls.whereType<GetGitHubItemsRequest>();
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.chatId == 'c'), isTrue);
    expect(
      fake.calls.whereType<GetGitHubPullRequest>(),
      isEmpty,
      reason: 'read whole only while its tab shows (ADR 0140)',
    );
    d.dispose();
  }, variant: onMac);

  testWidgets('not a GitHub repository, or its default branch: no widget', (
    tester,
  ) async {
    var (d, _) = await _app(tester, found: FindChatPullResponse());
    expect(_pull, findsNothing);
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
    expect(_pull, findsNothing);
    d.dispose();
  }, variant: onMac);

  // ADR 0117: a row a pull request; the details are the tab's.
  testWidgets("a draft: its row's icon says so; its ⋯ has Ready for review", (
    tester,
  ) async {
    final (d, _) = await _app(
      tester,
      whole: pull()
        ..item = item(1, 'Add Sub and Neg', draft: true)
        ..checks.clear(),
    );
    expect(_inPull(find.text('Add Sub and Neg')), findsOneWidget);
    final icon = _inPull(
      find.descendant(
        of: find.byType(PullRow),
        matching: find.byType(ItemIcon),
      ),
    );
    final shown = tester.widget<ItemIcon>(icon);
    expect(
      itemLook(
        NushiTheme.of(tester.element(icon)).t,
        shown.item,
        pull: shown.pull,
      ).$1,
      LineIcon.pullDraft,
    );
    await tester.tap(_rowMenu);
    await tester.pumpAndSettle();
    expect(find.text('Ready for review on GitHub'), findsOneWidget);
    expect(find.textContaining('Merge…', findRichText: true), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('open with a failing check: the row, its badge and one cue; '
      'collapsed, the one-line summary', (tester) async {
    // Blocked: the failing check is one its base requires ("unstable",
    // one nothing requires, is ready).
    final (d, _) = await _app(tester, whole: pull()..mergeState = 'blocked');
    expect(_inPull(find.text('Add Sub and Neg')), findsOneWidget);
    expect(_inPull(find.byType(ChecksBadge)), findsOneWidget);
    expect(_inPull(find.text('1/2')), findsOneWidget);
    expect(
      _inPull(find.textContaining('2 threads', findRichText: true)),
      findsOneWidget,
    );
    // Collapsed: its number, the failing count, the threads.
    await tester.tap(_inPull(find.text('Pull request')));
    await tester.pumpAndSettle();
    expect(_inPull(find.text('#1')), findsOneWidget);
    expect(_inPull(find.byIcon(Icons.cancel_outlined)), findsOneWidget);
    expect(_inPull(find.byIcon(Icons.forum_outlined)), findsOneWidget);
    expect(_inPull(find.text('2')), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('merged: what it merged into; a new comment is the cue while '
      'open', (tester) async {
    final p = pull()..item = item(1, 'Add Sub and Neg', state: 'merged');
    final (d, _) = await _app(tester, whole: p);
    expect(
      _inPull(find.textContaining('Merged into main', findRichText: true)),
      findsOneWidget,
    );
    expect(_inPull(find.byType(ChecksBadge)), findsNothing);
    d.dispose();
    final q = pull()..threads.clear();
    final (e, _) = await _app(tester, whole: q);
    // One comment more than the chat has seen (ADR 0140: counted).
    pullSeenComments.value = {
      'c': {q.item.id: q.item.comments - 1},
    };
    await tester.pump();
    expect(
      _inPull(find.textContaining('1 new comment', findRichText: true)),
      findsOneWidget,
    );
    e.dispose();
  }, variant: onMac);

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
    final whole = pull();
    pullSeenComments.value = {
      'c': {whole.item.id: whole.item.comments - 1},
    };
    await tester.pump();
    expect(find.text('Pull request'), findsNWidgets(2)); // switch, widget
    await tester.tap(_inPull(find.text('Add Sub and Neg')));
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsOneWidget);
    expect(
      find.byType(PanelWidget),
      findsNothing,
    ); // the panel goes, as for Changes
    expect(
      find.descendant(
        of: find.byType(GitHubPullPane),
        matching: find.text('Add Sub and Neg', findRichText: true),
      ),
      findsOneWidget, // the head's
    );
    expect(find.text('Start work'), findsNothing);
    expect(find.byType(MergeCard), findsOneWidget);
    // An open thread, and the conversation.
    expect(
      find.text('Should this check for overflow?', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('A first look.', findRichText: true), findsOneWidget);
    expect(pullSeenComments.value['c'], {
      whole.item.id: whole.item.comments,
    }, reason: 'seen');
    await tester.tap(find.text('Checks  1 failing'));
    await tester.pumpAndSettle();
    expect(find.byType(GitHubChecks), findsOneWidget);
    expect(fake.calls.whereType<GetGitHubPullRequest>().last.ref.number, 1);
    // Unlinked: the tab goes, and the chat shows.
    fake
      ..on(
        (input) => input is FindChatPullRequest
            ? FindChatPullResponse(host: 'github.com', repo: _repo, branch: 'x')
            : null,
      )
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
  }, variant: onMac);

  // The owner's report: the widget's ⋯, at the window's right, opened its
  // menu off to one side; and the pointer going onto it closed it. A row's
  // ⋯ is the same kind of button.
  testWidgets("a row's ⋯ opens its menu under it, ending at its right "
      'edge, and it stays open to be picked from', (tester) async {
    final (d, fake) = await _app(tester, whole: pull());
    final more = _rowMenu;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(more));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await mouse.down(tester.getCenter(more));
    await mouse.up();
    await tester.pumpAndSettle();
    final opener = tester.getRect(more);
    final unlink = tester.getRect(
      find.ancestor(
        of: find.text('Unlink'),
        matching: find.byType(MenuItemButton),
      ),
    );
    // Under it, toward the panel's inside, ending near its right edge.
    expect(unlink.right, lessThanOrEqualTo(opener.right));
    expect(unlink.right, greaterThan(opener.right - 40));
    expect(unlink.left, lessThan(opener.left));
    expect(unlink.top, greaterThan(opener.bottom));

    await mouse.moveTo(unlink.center);
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'pull_widget_menu');
    await mouse.down(unlink.center);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Unlink'), findsNothing);
    final sent = fake.calls.whereType<LinkChatPullRequest>().single;
    expect(sent.hasPull(), isFalse, reason: 'Unlink ran');
    expect(sent.unlink.number, 1);
    d.dispose();
  }, variant: onMac);
}
