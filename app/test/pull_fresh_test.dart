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
}
