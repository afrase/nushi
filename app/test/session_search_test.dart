import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/session_search.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'session_fixtures.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The text of the excerpt under a found session's row.
String _excerpt(WidgetTester tester, String match) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .firstWhere((s) => s.contains(match) && s.contains('test fail'));

void main() {
  setUpAll(loadFonts);

  testWidgets('once typing pauses, what was said is searched; the sessions '
      'found show under the titles, the hit marked, and open', (tester) async {
    final (fake, d, opened, _) = await pumpSessionList(tester);
    fake.searches = sessionHits;
    await typeIn(tester, 'flaky');
    // The titles filter at once; the search waits for the pause.
    expect(find.text('Fix the flaky test'), findsOne);
    expect(find.text('Searching what was said…'), findsOne);
    expect(fake.searched, isEmpty);
    await tester.pump(SessionSearch.pause);
    await tester.pumpAndSettle();
    expect(fake.searched.single.agent, 'claude');
    expect(fake.searched.single.folder, '/Users/me/nushi');
    expect(fake.searched.single.text, 'flaky');
    expect(find.text('Titles'), findsOne);
    expect(find.text('What was said'), findsOne);
    expect(find.text('Old relay work'), findsOne);
    expect(find.textContaining('3 mentions'), findsOne);
    expect(find.textContaining('1 mention'), findsOne);
    expect(
      _excerpt(tester, 'flaky'),
      startsWith('…so why does the flaky test'),
    );
    // The marked hit is its own span, on the accent's tint.
    final marked = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((r) => (r.text as TextSpan).children ?? const <InlineSpan>[])
        .whereType<TextSpan>()
        .expand((s) => s.children ?? const <InlineSpan>[])
        .whereType<TextSpan>()
        .where((s) => s.style?.backgroundColor == Tokens.dark.accentSoft);
    expect(marked.map((s) => s.text), contains('flaky'));
    // Two titles, More, then the sessions found.
    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.enter);
    expect(opened.single.sessionId, 's9');
    d.dispose();
  });

  testWidgets('Enter searches at once; an answer to older text is dropped', (
    tester,
  ) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    final late = Completer<SearchAgentSessionsResponse>();
    fake.searches = (r) => r.text == 'fla' ? late.future : sessionHits(r);
    await typeIn(tester, 'fla');
    await press(tester, LogicalKeyboardKey.enter);
    expect(fake.searched.single.text, 'fla');
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Old relay work'), findsOne);
    // The daemon was told to stop reading for the older text.
    expect(fake.cancelledSearches, ['fla']);
    late.complete(SearchAgentSessionsResponse(canSearch: true));
    await tester.pumpAndSettle();
    expect(find.text('Old relay work'), findsOne); // still flaky's
    expect(find.textContaining('No sessions mention'), findsNothing);
    d.dispose();
  });

  testWidgets('a search still running when the list closes is cancelled', (
    tester,
  ) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    final never = Completer<SearchAgentSessionsResponse>();
    fake.searches = (_) => never.future;
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    expect(fake.cancelledSearches, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(fake.cancelledSearches, ['flaky']);
    d.dispose();
  });

  testWidgets('an older daemon, until it restarts, filters titles only and '
      'is never asked', (tester) async {
    viewport(tester, const Size(720, 900), brightness: Brightness.dark);
    final (fake, d, _, _) = await pumpSessionList(
      tester,
      api: searchSessionsApi - 1,
    );
    expect(find.text('Filter by title'), findsOne);
    await typeIn(tester, 'relay');
    await tester.pump(SessionSearch.pause);
    await press(tester, LogicalKeyboardKey.enter);
    expect(fake.searched, isEmpty);
    expect(find.text('Rename the relay flags'), findsOne);
    expect(
      find.text(
        'Searching what was said comes once the daemon restarts: only '
        'titles are filtered until then.',
      ),
      findsOne,
    );
    expectTextInside(tester, 720);
    await render(tester, find.byType(Dialog), 'session_search_old_daemon');
    d.dispose();
  });

  testWidgets('text typed for an older daemon is searched once it '
      'restarts into one that searches', (tester) async {
    final (fake, d, _, _) = await pumpSessionList(
      tester,
      api: searchSessionsApi - 1,
    );
    fake
      ..searches = sessionHits
      ..answer = null;
    await typeIn(tester, 'flaky');
    expect(fake.searched, isEmpty);
    await d.ping(); // the daemon restarted
    await tester.pump();
    expect(find.text('What was said'), findsNothing);
    await tester.pump(SessionSearch.pause);
    await tester.pumpAndSettle();
    expect(fake.searched.single.text, 'flaky');
    expect(find.text('Old relay work'), findsOne);
    d.dispose();
  });

  testWidgets('clearing the field cancels the search it asked', (tester) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    final never = Completer<SearchAgentSessionsResponse>();
    fake.searches = (_) => never.future;
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    await typeIn(tester, '');
    expect(fake.cancelledSearches, ['flaky']);
    // The same text again is asked again, not taken as answered.
    fake.searches = sessionHits;
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    expect(fake.searched, hasLength(2));
    expect(find.text('Old relay work'), findsOne);
    d.dispose();
  });

  testWidgets('a failed search says why, and Try again asks again', (
    tester,
  ) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    fake.searches = (_) =>
        throw ConnectException(Code.unavailable, 'the daemon went away');
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.textContaining("Couldn't search:"), findsOne);
    fake.searches = sessionHits;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(fake.searched, hasLength(2));
    expect(find.text('Old relay work'), findsOne);
    d.dispose();
  });

  testWidgets('nothing found says so', (tester) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    await typeIn(tester, 'quokka');
    await press(tester, LogicalKeyboardKey.enter);
    expect(fake.searched.single.text, 'quokka');
    expect(find.text('No sessions mention “quokka”'), findsOne);
    expect(find.text('No title loaded so far says “quokka”'), findsOne);
    d.dispose();
  });

  testWidgets('an agent without a search says so once, and its titles still '
      'filter', (tester) async {
    final (fake, d, _, _) = await pumpSessionList(tester);
    fake.searches = (_) => SearchAgentSessionsResponse();
    await typeIn(tester, 'relay');
    await press(tester, LogicalKeyboardKey.enter);
    expect(
      find.text(
        "Claude's sessions can't be searched for what was said: only "
        'titles are.',
      ),
      findsOne,
    );
    expect(find.text('Rename the relay flags'), findsOne);
    await typeIn(tester, 'flags');
    await tester.pump(SessionSearch.pause);
    await tester.pumpAndSettle();
    expect(fake.searched, hasLength(1)); // not asked again
    expect(find.text('Filter by title'), findsOne);
    d.dispose();
  });

  testWidgets('a session found open elsewhere asks first, as the list does; '
      'one that allows one writer isn’t offered', (tester) async {
    viewport(tester, const Size(1700, 1000));
    final fake = FakeDaemon(const [])
      ..sessions = sessionPages
      ..searches = sessionHits;
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    unawaited(
      newChat(tester.element(find.byType(Scaffold).first), d, '/Users/me/x'),
    );
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowRight);
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('Clock skew'));
    await tester.pumpAndSettle();
    expect(find.text('Open it here too?'), findsOne);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(fake.opened.single.sessionId, 's8');
    expect(fake.opened.single.folder, '/Users/me/x');
    expect(fake.opened.single.title, 'Clock skew');

    fake.searches = (r) => sessionHits(r)..oneWriter = true;
    unawaited(
      newChat(tester.element(find.byType(Scaffold).first), d, '/Users/me/x'),
    );
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowRight);
    await typeIn(tester, 'flaky');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('Clock skew'));
    await tester.pumpAndSettle();
    expect(find.text('Open it here too?'), findsNothing);
    expect(fake.opened, hasLength(1));
    d.dispose();
  }, variant: _mac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the sessions found ($name)', (tester) async {
      viewport(tester, const Size(700, 640));
      final (fake, d, _, _) = await pumpSessionList(tester, tokens: tokens);
      fake.searches = sessionHits;
      await typeIn(tester, 'flaky');
      await press(tester, LogicalKeyboardKey.enter);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/session_search_$name.png'),
      );
      d.dispose();
    });
  }

  for (final (width, height) in [(1700.0, 1000.0), (720.0, 900.0)]) {
    testWidgets('the dialog with sessions found, ${width.toInt()} wide', (
      tester,
    ) async {
      viewport(tester, Size(width, height), brightness: Brightness.dark);
      final fake = FakeDaemon([chat('c', 'claude', 'A chat', age: 1)])
        ..sessions = sessionPages
        ..searches = sessionHits;
      final d = await fake.connect(tester);
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      unawaited(
        newChat(
          tester.element(find.byType(Scaffold).first),
          d,
          '/Users/me/nushi',
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowRight);
      await typeIn(tester, 'flaky');
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Claude sessions in nushi'), findsOne);
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'session_search_${width.toInt()}_dark',
      );
      d.dispose();
    }, variant: _mac);
  }
}
