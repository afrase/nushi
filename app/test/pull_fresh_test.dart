import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_polls.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

const _title = "Ignore q params that aren't hashes in admin filters";

/// The page's line ("Updated just now"), wherever it is.
Finder get _line => find.byKey(const ValueKey('pull-kept'));

/// The tab's Refresh, beside the line.
Finder get _refresh => find.byKey(const ValueKey('pull-refresh'));

/// The line's words.
Finder _says(String text) =>
    find.descendant(of: _line, matching: find.text(text), matchRoot: true);

void main() {
  setUpAll(loadFonts);

  testWidgets('the tab says how fresh it is after a good read, and the '
      "line ticks with the app's minute clock", (tester) async {
    // Merged: asked again only every quarter of an hour, so a minute's
    // tick is the clock's alone.
    final (d, fake) = await openPullTab(
      tester,
      fixturePull()..item.state = 'merged',
    );
    expect(_says('Updated just now'), findsOneWidget);
    fake.calls.clear();
    clock = () => fixtureNow.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isEmpty);
    expect(_says('Updated 2m ago'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('while the minute poll asks it says "refreshing", and a poll '
      'that fails says so in the failure line and keeps the page', (
    tester,
  ) async {
    Completer<GetGitHubPullResponse>? hang;
    var failing = false;
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => input is! GetGitHubPullRequest
          ? null
          : failing
          ? Future<GetGitHubPullResponse>.error(Exception('no network'))
          : hang?.future,
    );
    hang = Completer();
    await tester.pump(pullWidgetPoll);
    await tester.pump();
    expect(_says('Updated just now · refreshing'), findsOneWidget);
    hang.complete(GetGitHubPullResponse(pull: fixturePull()));
    hang = null;
    await tester.pumpAndSettle();
    expect(_says('Updated just now'), findsOneWidget);
    failing = true;
    await tester.pump(pullWidgetPoll);
    await tester.pumpAndSettle();
    expect(_says("Couldn't refresh · as of just now"), findsOneWidget);
    expect(find.text(_title), findsOneWidget); // the page stays
    expect(find.textContaining('Not current'), findsNothing); // one cue
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the tab's Refresh asks GitHub at once, says so while it "
      'asks, then "Updated just now"; a second press meanwhile asks nothing '
      'more', (tester) async {
    Completer<GetGitHubPullResponse>? hang;
    final asked = <GetGitHubPullRequest>[];
    final (d, fake) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => switch (input) {
        // The rows its own, so they don't wait on the whole one's.
        GetGitHubItemsRequest() => GetGitHubItemsResponse(
          items: [rowItem(fixturePull())],
        ),
        // Counted as asked: the fake records a call once it's answered.
        GetGitHubPullRequest() =>
          (asked..add(input)).isEmpty ? null : hang?.future,
        _ => null,
      },
    );
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 20)); // past the 10 s guard
    fake.calls.clear();
    asked.clear();
    hang = Completer();
    await tester.tap(_refresh);
    await tester.pumpAndSettle(); // the ask under way: the read hangs
    List<GetGitHubPullRequest> pulls() => asked;
    expect(pulls(), hasLength(1));
    expect(pulls().single.quiet, isFalse); // asked for, not a poll
    expect(fake.calls.whereType<FindChatPullRequest>(), hasLength(1));
    expect(_says('Updated 3m ago · refreshing'), findsOneWidget);
    await tester.tap(_refresh);
    await tester.pumpAndSettle();
    expect(pulls(), hasLength(1));
    hang.complete(GetGitHubPullResponse(pull: fixturePull()));
    hang = null;
    await tester.pumpAndSettle();
    expect(_says('Updated just now'), findsOneWidget);
    expect(pulls(), hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a Refresh that fails says so in the failure's line and "
      'keeps the page', (tester) async {
    var failing = false;
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => failing && input is GetGitHubPullRequest
          ? Future<GetGitHubPullResponse>.error(Exception('no network'))
          : null,
    );
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 20));
    failing = true;
    await tester.tap(_refresh);
    await tester.pumpAndSettle();
    expect(_says("Couldn't refresh · as of 3m ago"), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(_refresh, findsOneWidget); // to try again
    await closeView(tester, d);
  }, variant: onMac);
}
