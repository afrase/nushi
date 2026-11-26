import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/checks_watch.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

/// The chat's pull request as the chats' states say it: its checks
/// [checks] on commit [oid].
GitHubItem _state(String oid, {String checks = 'failure'}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: fixtureRepo, number: 537),
  id: 'PR_537',
  pull: true,
  title: 'Speed up the search index',
  state: 'open',
  checks: checks,
  checksOid: oid,
);

/// A chat on pull request #537 whose checks are as [now] says at each
/// ask, the app open on it.
Future<(Daemon, FakeDaemon)> _open(
  WidgetTester tester,
  GitHubItem Function() now, {
  Size size = const Size(1440, 900),
  Brightness brightness = Brightness.dark,
  bool linked = true,
}) async {
  showDetails.value = false;
  final whole = fixturePull()..item.author = 'robin';
  final c = chat(
    'c',
    'claude',
    'Speed up the search index',
    folder: '/Users/me/search-service',
  );
  if (linked) c.pull = fixtureLink;
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      // The chats' states: their rows (API 133).
      GetGitHubItemsRequest() => GetGitHubItemsResponse(items: [now()]),
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: fixtureRepo,
        branch: whole.head,
        pull: fixtureLink,
      ),
      // Read whole, it says what the states say.
      GetGitHubPullRequest() => GetGitHubPullResponse(
        pull: whole.deepCopy()
          ..item.checks = now().checks
          ..item.checksOid = now().checksOid,
      ),
      GetGitHubCommitsRequest() => fixtureCommits(),
      ListGitHubHostsRequest() => ListGitHubHostsResponse(
        hosts: [GitHubHost(host: 'github.com', login: 'robin', source: 'gh')],
      ),
      GetGitHubJobLogRequest() => GetGitHubJobLogResponse(
        tail: 'Run make test\nFAIL search_test.go:42\n##[error]exit code 1',
      ),
      _ => null,
    };
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  return (d, fake);
}

/// The next minute's ask of the chats' states, answered.
Future<void> _poll(WidgetTester tester) async {
  await tester.pump(const Duration(minutes: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  test('a failure is its pull request and commit, only while open and '
      'failing, and only from a daemon that says the commit', () {
    expect(failureOf(_state('a1')), 'PR_537@a1');
    expect(failureOf(_state('a1', checks: 'error')), 'PR_537@a1');
    expect(failureOf(_state('a1', checks: 'pending')), isNull);
    expect(failureOf(_state('a1', checks: 'success')), isNull);
    expect(failureOf(_state('')), isNull);
    expect(failureOf(_state('a1')..state = 'merged'), isNull);
    expect(failureOf(null), isNull);
  });

  test('failed checks need you once the agent is done, not while it '
      'works', () {
    final c = ChatState('c', '/x')..checksFailed = [fixtureLink];
    expect(c.phase, ChatPhase.waiting);
    expect(c.needsYou, isTrue);
    c.busy = true;
    expect(c.phase, ChatPhase.working);
    c
      ..busy = false
      ..archived = true;
    expect(c.phase, ChatPhase.archived);
  });

  testWidgets('a new failure flags the chat; Ask to fix fills the box and '
      'sends nothing; the same failure stays quiet, a later one flags it '
      'again, and Dismiss clears it', (tester) async {
    var now = _state('a1');
    final (d, fake) = await _open(tester, () => now);
    final chat = d.chats['c']!;
    // Failing when the chat was first seen: not new.
    expect(checksSeen.value['c'], ['PR_537@a1']);
    expect(find.byType(ChecksFailedBar), findsNothing);
    expect(chat.needsYou, isFalse);

    // A push, running, then failing on the new commit.
    now = _state('b2', checks: 'pending');
    await _poll(tester);
    expect(find.byType(ChecksFailedBar), findsNothing);
    now = _state('b2');
    await _poll(tester);
    expect(find.byType(ChecksFailedBar), findsOneWidget);
    expect(
      find.text('Checks failed on #537', findRichText: true),
      findsOneWidget,
      reason: 'its words',
    );
    expect(chat.phase, ChatPhase.waiting);
    expect(find.byTooltip('needs you'), findsOneWidget, reason: 'the row');
    final asked = fake.calls.whereType<GetGitHubItemsRequest>().length;
    final pulls = fake.calls.whereType<GetGitHubPullRequest>().length;

    await tester.tap(find.text('Ask to fix'));
    await tester.pumpAndSettle();
    final box = chat.draft.replies.value;
    expect(box, isNotEmpty);
    expect(box.first.from, startsWith('Failed checks on PR'));
    expect(box.first.quote, contains('FAIL search_test.go:42'));
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    expect(find.byType(ChecksFailedBar), findsNothing);
    expect(chat.needsYou, isFalse);
    expect(checksSeen.value['c'], ['PR_537@b2']);
    expect(
      fake.calls.whereType<GetGitHubItemsRequest>().length,
      asked,
      reason: 'no ask of its own',
    );
    expect(
      fake.calls.whereType<GetGitHubPullRequest>().length,
      pulls + 1,
      reason:
          'read whole for its failed checks: the tab, which would '
          'have it, shows the chat',
    );

    // Each ask after: the same failure stays quiet.
    await _poll(tester);
    await _poll(tester);
    expect(find.byType(ChecksFailedBar), findsNothing);

    // A later commit fails: flagged again, until dismissed.
    now = _state('c3');
    await _poll(tester);
    expect(find.byType(ChecksFailedBar), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(ChecksFailedBar), findsNothing);
    expect(checksSeen.value['c'], ['PR_537@c3']);
    await _poll(tester);
    expect(find.byType(ChecksFailedBar), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a pull request linked to a chat while its checks fail isn’t '
      'flagged for that failure; a later commit’s is', (tester) async {
    var now = _state('a1');
    final (d, _) = await _open(tester, () => now, linked: false);
    final chat = d.chats['c']!;
    // Found on the branch as the app opened, its row read then (one store
    // of the rows, GitHubItems): failing as first known, so not new.
    expect(checksSeen.value['c'], ['PR_537@a1']);
    expect(chat.needsYou, isFalse);
    chat.linkPull(fixtureLink);
    d.listChanged();
    await _poll(tester);
    await _poll(tester);
    expect(checksSeen.value['c'], ['PR_537@a1']);
    expect(chat.needsYou, isFalse, reason: 'failing as it was linked');
    expect(find.byType(ChecksFailedBar), findsNothing);
    now = _state('b2');
    await _poll(tester);
    expect(chat.needsYou, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a pull request first seen passing is flagged once it fails, '
      'on the same commit too', (tester) async {
    var now = _state('a1', checks: 'success');
    final (d, _) = await _open(tester, () => now);
    expect(checksSeen.value['c'], ['PR_537@']);
    now = _state('a1');
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a failure no longer failing takes the flag away', (
    tester,
  ) async {
    var now = _state('a1', checks: 'pending');
    final (d, _) = await _open(tester, () => now);
    now = _state('a1');
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isTrue);
    now = _state('b2', checks: 'pending');
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a check only cancelled flags the chat in its own words, '
      'with nothing to ask the agent to fix', (tester) async {
    var now = _state('a1', checks: 'pending');
    final (d, _) = await _open(tester, () => now);
    now = _state('a1')
      ..checkCounts = GitHubCheckCounts(passed: 5, failed: 1, cancelled: 1);
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isTrue, reason: 'it holds the merge back');
    expect(
      find.text('A check was cancelled on #537', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('failed', findRichText: true), findsNothing);
    expect(find.text('Ask to fix'), findsNothing);
    // A failure beside it on the same pull request: failed, as before.
    now = _state('b2')
      ..checkCounts = GitHubCheckCounts(passed: 4, failed: 2, cancelled: 1);
    await _poll(tester);
    expect(
      find.text('Checks failed on #537', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Ask to fix'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a cancel acted on stays quiet, but a real failure on the '
      'same commit after it flags the chat again', (tester) async {
    final cancelled = _state('a1')
      ..checkCounts = GitHubCheckCounts(passed: 5, failed: 1, cancelled: 1);
    expect(failureOf(cancelled), 'PR_537@a1:cancelled');
    var now = _state('a1', checks: 'pending');
    final (d, _) = await _open(tester, () => now);
    now = cancelled;
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isTrue);
    ChecksWatch.of(d).seen(d.chats['c']!);
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isFalse, reason: 'dismissed');
    // Run again on the same commit, it really fails.
    now = _state('a1')..checkCounts = GitHubCheckCounts(passed: 5, failed: 1);
    await _poll(tester);
    expect(d.chats['c']!.needsYou, isTrue);
    expect(
      find.text('Checks failed on #537', findRichText: true),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: onMac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    if (rendering) ('light', Brightness.light),
  ]) {
    testWidgets('renders: the chat flagged, Ask to fix ($name)', (
      tester,
    ) async {
      var now = _state('a1', checks: 'pending');
      final (d, _) = await _open(
        tester,
        () => now,
        size: const Size(1700, 900),
        brightness: brightness,
      );
      await render(tester, find.byType(NushiApp), 'checks_before_1700_$name');
      now = _state('a1');
      await _poll(tester);
      expect(find.byType(ChecksFailedBar), findsOneWidget);
      await render(tester, find.byType(NushiApp), 'checks_after_1700_$name');
      viewport(tester, const Size(720, 900), brightness: brightness);
      await tester.pumpAndSettle();
      expectTextInside(tester, 720);
      // The bar's Ask to fix and ✕ at its end, inside the window.
      expect(
        tester.getRect(find.byTooltip('Dismiss')).right,
        lessThanOrEqualTo(720),
      );
      await render(tester, find.byType(NushiApp), 'checks_after_720_$name');
      await closeView(tester, d);
    }, variant: onMac);
  }
}
