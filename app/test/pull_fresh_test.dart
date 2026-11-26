import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_bar.dart';
import 'package:nushi/github_view.dart' show githubPoll;
import 'package:nushi/motion.dart';
import 'package:nushi/pull_polls.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'github_fixture.dart' as gh;
import 'harness.dart';
import 'pull_fixture.dart';

const _title = "Export sighting dates in every site's own time zone";

/// The page's line ("Updated just now"), wherever it is.
Finder get _line => find.byKey(const ValueKey('pull-kept'));

/// The tab's Refresh, beside the line.
Finder get _refresh => find.byKey(const ValueKey('pull-refresh'));

/// The line's words.
Finder _says(String text) =>
    find.descendant(of: _line, matching: find.text(text), matchRoot: true);

/// The tab's answers with each read of the pull request whole counted in
/// [asked] as it's asked (the fake records a call once it's answered) and
/// answered by [whole] (the fixture's when it says null). The rows are
/// answered on their own: the fake would read them from the whole one, an
/// ask more, and wait on it.
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
      more: _counted(asked, () => hang?.future),
    );
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 20)); // past the 10 s guard
    fake.calls.clear();
    asked.clear();
    hang = Completer();
    await tester.tap(_refresh);
    await tester.pumpAndSettle(); // the ask under way: the read hangs
    expect(asked, hasLength(1));
    expect(asked.single.quiet, isFalse); // asked for, not a poll
    expect(fake.calls.whereType<FindChatPullRequest>(), hasLength(1));
    expect(_says('Updated 3m ago · refreshing'), findsOneWidget);
    await tester.tap(_refresh);
    await tester.pumpAndSettle();
    expect(asked, hasLength(1));
    hang.complete(GetGitHubPullResponse(pull: fixturePull()));
    hang = null;
    await tester.pumpAndSettle();
    await tester.pump(Waits.refreshShown); // the Refresh's busy cue
    expect(_says('Updated just now'), findsOneWidget);
    expect(asked, hasLength(1));
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
    await tester.pump(Waits.refreshShown); // the Refresh's busy cue
    expect(_says("Couldn't refresh · as of 3m ago"), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(_refresh, findsOneWidget); // to try again
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌘R on the tab refreshes as its button does; over a dialog '
      'it does nothing; on the chat with a page in the browser it still '
      'reloads the page', (tester) async {
    final fakes = browserFakes();
    final asked = <GetGitHubPullRequest>[];
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      size: const Size(1700, 900),
      more: _counted(asked),
    );
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    await press(tester, LogicalKeyboardKey.keyR, cmd: true);
    await tester.pump(Waits.refreshShown); // the Refresh's busy cue
    expect(asked, hasLength(1));
    expect(asked.single.quiet, isFalse);
    expect(_says('Updated just now'), findsOneWidget);

    // A dialog over it: the key is the dialog's, never the tab's.
    await tester.tap(find.text('Submit review').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    await press(tester, LogicalKeyboardKey.keyR, cmd: true);
    expect(asked, isEmpty);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(Dialog), findsNothing);

    // The chat, a page in its browser: ⌘R is Reload page's.
    final c = d.chats['c']!..tab.value = ChatTab.chat;
    await tester.pumpAndSettle();
    c.openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    asked.clear();
    await press(tester, LogicalKeyboardKey.keyR, cmd: true);
    expect(fakes.hosts.single.reloads, 1);
    expect(asked, isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the GitHub view with a pull request's page open: one "
      "freshness line, the page's, and the bar's Refresh and ⌘R refresh "
      'the page', (tester) async {
    var failing = false;
    Never fail() => throw Exception('no network');
    final (fake, g) = await gh.openView(
      tester,
      more: (input) =>
          failing &&
              (input is ListGitHubInboxRequest && !input.cached ||
                  input is GetGitHubPullRequest && input.quiet)
          ? fail()
          : null,
    );
    failing = true;
    await tester.pump(githubPoll);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsOneWidget); // bar
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    await tester.pump(pullWidgetPoll);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsOneWidget);
    expect(_says("Couldn't refresh · as of just now"), findsOneWidget);
    expect(find.byKey(const ValueKey('pull-refresh')), findsNothing);

    failing = false;
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    for (final how in ['button', 'key']) {
      fake.calls.clear();
      if (how == 'button') {
        await tester.tap(
          find.descendant(
            of: find.byType(GitHubBar),
            matching: find.byIcon(Icons.refresh),
          ),
        );
        await tester.pumpAndSettle();
      } else {
        await press(tester, LogicalKeyboardKey.keyR, cmd: true);
      }
      await tester.pump(Waits.refreshShown); // the Refresh's busy cue
      final pulls = fake.calls.whereType<GetGitHubPullRequest>().toList();
      expect(pulls, hasLength(1), reason: how);
      expect(pulls.single.quiet, isFalse, reason: how);
      expect(fake.calls.whereType<ListGitHubInboxRequest>(), isEmpty);
      expect(_says('Updated just now'), findsOneWidget, reason: how);
      expect(find.textContaining('Updated'), findsOneWidget, reason: how);
    }
    await closeView(tester, g);
  }, variant: onMac);

  testWidgets("a failed Refresh in the GitHub view says so in the page's "
      'failure line, as on the tab, and keeps the page', (tester) async {
    var failing = false;
    final (_, g) = await gh.openView(
      tester,
      more: (input) => failing && input is GetGitHubPullRequest
          ? Future<GetGitHubPullResponse>.error(Exception('no network'))
          : null,
    );
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    clock = () => fixtureNow.add(const Duration(minutes: 3));
    failing = true;
    await tester.tap(
      find.descendant(
        of: find.byType(GitHubBar),
        matching: find.byIcon(Icons.refresh),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(Waits.refreshShown); // the Refresh's busy cue
    expect(_says("Couldn't refresh · as of 3m ago"), findsOneWidget);
    expect(find.textContaining('Not current'), findsNothing);
    expect(find.text('Add Sub and Neg'), findsWidgets); // the page stays
    await closeView(tester, g);
  }, variant: onMac);

  testWidgets('in the GitHub view a second Refresh while the page asks '
      'asks nothing more', (tester) async {
    Completer<GetGitHubPullResponse>? hang;
    final (fake, g) = await gh.openView(
      tester,
      more: (input) => input is GetGitHubPullRequest ? hang?.future : null,
    );
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    hang = Completer();
    fake.calls.clear();
    final refresh = find.descendant(
      of: find.byType(GitHubBar),
      matching: find.byIcon(Icons.refresh),
    );
    await tester.tap(refresh);
    await tester.pump();
    await tester.tap(refresh);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyR, cmd: true, settle: false);
    hang.complete(GetGitHubPullResponse(pull: gh.pull()));
    hang = null;
    await tester.pumpAndSettle();
    await tester.pump(Waits.refreshShown); // the Refresh's busy cue
    expect(fake.calls.whereType<GetGitHubPullRequest>(), hasLength(1));
    expect(_says('Updated just now'), findsOneWidget);
    await closeView(tester, g);
  }, variant: onMac);

  testWidgets('holding ⌘R on the tab asks once, not once a repeat', (
    tester,
  ) async {
    final asked = <GetGitHubPullRequest>[];
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: _counted(asked),
    );
    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    final cmd = switch (conventions.commandKey) {
      CommandKey.meta => LogicalKeyboardKey.metaLeft,
      CommandKey.control => LogicalKeyboardKey.controlLeft,
    };
    await tester.sendKeyDownEvent(cmd);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    for (var i = 0; i < 10; i++) {
      await tester.pumpAndSettle();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyR);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(cmd);
    await tester.pumpAndSettle();
    expect(asked, hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌘R still refreshes the tab after a click into a field of '
      'the tab and back out of it', (tester) async {
    final asked = <GetGitHubPullRequest>[];
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      size: const Size(1700, 900),
      more: _counted(asked),
    );
    // Mid-page: at the top it would lie under the slim bar.
    await Scrollable.ensureVisible(
      tester.element(find.text('Leave a comment')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    // The hint lies under the field's text, which takes the tap.
    await tester.tapAt(tester.getCenter(find.text('Leave a comment')));
    await tester.pumpAndSettle();
    final field = FocusManager.instance.primaryFocus;
    expect(
      field?.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );
    // The box's note: plain text, outside the field.
    await tester.tap(
      find.descendant(
        of: find.byType(CommentBox),
        matching: find.textContaining('Markdown'),
      ),
    );
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(field));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    await press(tester, LogicalKeyboardKey.keyR, cmd: true);
    expect(asked, hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a tab whose first read failed, with nothing kept, has a '
      'Refresh under the error that asks again', (tester) async {
    var failing = true;
    final asked = <GetGitHubPullRequest>[];
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: _counted(
        asked,
        () => failing
            ? Future<GetGitHubPullResponse>.error(Exception('no network'))
            : null,
      ),
    );
    expect(find.text(_title), findsNothing);
    expect(_refresh, findsOneWidget);
    failing = false;
    await tester.pump(const Duration(seconds: 20));
    asked.clear();
    await tester.tap(_refresh);
    await tester.pumpAndSettle();
    expect(asked, hasLength(1));
    expect(find.text(_title), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);
}
