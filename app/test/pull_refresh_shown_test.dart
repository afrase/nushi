import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_bar.dart';
import 'package:nushi/pull_polls.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' as gh;
import 'harness.dart';
import 'pull_fixture.dart';

// A Refresh the user asks for shows it's working for 600 ms at least
// (Waits.refreshShown), so a quick answer that changed nothing still
// reads as a refresh; the polls show only what they take.

/// The page's line ("Updated just now").
Finder get _line => find.byKey(const ValueKey('pull-kept'));

/// The tab's Refresh, beside the line.
Finder get _refresh => find.byKey(const ValueKey('pull-refresh'));

/// The GitHub view's bar's Refresh.
Finder get _barRefresh => find.descendant(
  of: find.byType(GitHubBar),
  matching: find.byIcon(Icons.refresh),
);

/// The line's words.
Finder _says(String text) =>
    find.descendant(of: _line, matching: find.text(text), matchRoot: true);

const _ms100 = Duration(milliseconds: 100);

/// The tab's answers: each read of the pull request whole counted in
/// [asked], answered by [whole] (the fixture's when it says null); the
/// rows answered on their own.
Object? Function(Object) _counted(
  List<GetGitHubPullRequest> asked, [
  Object? Function()? whole,
]) => (input) {
  if (input is GetGitHubItemsRequest) {
    return GetGitHubItemsResponse(items: [rowItem(fixturePull())]);
  }
  if (input is! GetGitHubPullRequest) return null;
  asked.add(input);
  return whole?.call();
};

/// The line at 100, 500 and 700 ms after a press with an instant answer:
/// busy, busy, then [after].
Future<void> _heldThen(WidgetTester tester, String after) async {
  await tester.pump(_ms100);
  expect(_says('Updated just now · refreshing'), findsOneWidget);
  await tester.pump(_ms100 * 4);
  expect(_says('Updated just now · refreshing'), findsOneWidget);
  await tester.pump(_ms100 * 2);
  expect(_says(after), findsOneWidget);
}

/// The chat's Pull request tab, read, its clock still, the next poll far.
Future<(Daemon, FakeDaemon)> _tab(
  WidgetTester tester,
  List<GetGitHubPullRequest> asked, [
  Object? Function()? whole,
]) async {
  final (d, fake) = await openPullTab(
    tester,
    fixturePull(),
    more: _counted(asked, whole),
  );
  await tester.pump(const Duration(seconds: 20));
  fake.calls.clear();
  asked.clear();
  return (d, fake);
}

void main() {
  setUpAll(loadFonts);

  testWidgets("the tab's Refresh with an instant answer that changed "
      'nothing says "refreshing" for 600 ms, once, a second press '
      'changing nothing', (tester) async {
    final asked = <GetGitHubPullRequest>[];
    final (d, fake) = await _tab(tester, asked);
    await tester.tap(_refresh);
    await tester.pump(_ms100 * 3);
    await tester.tap(_refresh); // inside the 600 ms: no more, no longer
    await tester.pump(_ms100 * 2);
    expect(_says('Updated just now · refreshing'), findsOneWidget);
    await tester.pump(_ms100 * 2);
    expect(_says('Updated just now'), findsOneWidget);
    expect(asked, hasLength(1));
    expect(fake.calls.whereType<FindChatPullRequest>(), hasLength(1));

    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    await tester.tap(_refresh);
    await _heldThen(tester, 'Updated just now');
    expect(asked, hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌘R on the tab with an instant answer says "refreshing" for '
      '600 ms', (tester) async {
    final asked = <GetGitHubPullRequest>[];
    final (d, fake) = await _tab(tester, asked);
    await press(tester, LogicalKeyboardKey.keyR, cmd: true, settle: false);
    await _heldThen(tester, 'Updated just now');
    expect(asked, hasLength(1));
    expect(fake.calls.whereType<FindChatPullRequest>(), hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the GitHub view's bar Refresh on a pull request's page with "
      'an instant answer says "refreshing" for 600 ms', (tester) async {
    final (fake, g) = await gh.openView(tester);
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    fake.calls.clear();
    await tester.tap(_barRefresh);
    await _heldThen(tester, 'Updated just now');
    expect(fake.calls.whereType<GetGitHubPullRequest>(), hasLength(1));
    await closeView(tester, g);
  }, variant: onMac);

  testWidgets('a slow Refresh says "refreshing" until it answers, not '
      'past it', (tester) async {
    final asked = <GetGitHubPullRequest>[];
    Completer<GetGitHubPullResponse>? hang;
    final (d, _) = await _tab(tester, asked, () => hang?.future);
    hang = Completer();
    await tester.tap(_refresh);
    await tester.pump(_ms100 * 10);
    expect(_says('Updated just now · refreshing'), findsOneWidget);
    await tester.pump(_ms100 * 10);
    hang.complete(GetGitHubPullResponse(pull: fixturePull()));
    hang = null;
    await tester.pump();
    await tester.pump();
    expect(_says('Updated just now'), findsOneWidget);
    expect(asked, hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the minute's quiet poll with an instant answer isn't held", (
    tester,
  ) async {
    final asked = <GetGitHubPullRequest>[];
    final (d, _) = await _tab(tester, asked);
    await tester.pump(pullWidgetPoll);
    await tester.pump();
    await tester.pump(_ms100);
    expect(asked, hasLength(1));
    expect(asked.single.quiet, isTrue);
    expect(_says('Updated just now'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a Refresh that fails at once says "refreshing" for 600 ms, '
      'then the failure line', (tester) async {
    final asked = <GetGitHubPullRequest>[];
    var failing = false;
    final (d, _) = await _tab(
      tester,
      asked,
      () => failing
          ? Future<GetGitHubPullResponse>.error(Exception('no network'))
          : null,
    );
    failing = true;
    await tester.tap(_refresh);
    await _heldThen(tester, "Couldn't refresh · as of just now");
    await closeView(tester, d);
  }, variant: onMac);
}
