import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

/// Chats of all five agents, in each status.
final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the login redirect', status: ChatStatus(busy: true))
    ..jiraKey = 'ACME-12',
  chat(
    'b',
    'codex',
    'Bump the API version',
    age: 1,
    status: ChatStatus(busy: true, waiting: true),
  ),
  chat('c', 'ante', 'Profile the transcript', age: 2),
  chat(
    'd',
    'omp',
    'Try the new parser',
    age: 3,
    status: ChatStatus(asleep: true),
  ),
  chat('e', 'claude', 'Scratch questions', folder: '/tmp/s', age: 4),
  chat('f', 'codex', 'Release notes', folder: '/Users/me/site', age: 5),
  chat('g', 'ante', 'Logs', folder: '/Users/me/site', age: 6),
  chat('h', 'omp', 'Fonts', folder: '/Users/me/site', age: 7),
  chat('j', 'pig', 'Port the tests', folder: '/Users/me/site', age: 7),
  chat(
    'i',
    'mystery',
    'An agent Nushi has no mark for',
    folder: '/Users/me/site',
    age: 8,
  ),
];

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('each row shows its agent beside its status ($name)', (
      tester,
    ) async {
      // Still, so the working chat's mark doesn't breathe.
      final (d, _) = await arrangedSidebar(
        tester,
        chats: _chats,
        tokens: tokens,
        size: const Size(400, 600),
        height: 540,
        settle: false,
      );
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/sidebar_$name.png'),
      );
      d.dispose();
    });
  }

  // The owner: "New chat looks a little weird it's all the way to the left."
  for (final width in [1700.0, 720.0]) {
    testWidgets('New chat is centred in its button (${width.toInt()} wide)', (
      tester,
    ) async {
      viewport(tester, Size(width, 600));
      // Idle ones, so pumpAndSettle settles.
      final d = await FakeDaemon([
        for (final c in _chats)
          if (!c.status.busy) c,
      ]).connect(tester);
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      // The sidebar's (the empty pane has one too).
      final button = find.descendant(
        of: find.byType(Sidebar),
        matching: find.widgetWithText(WideButton, 'New chat'),
      );
      final box = tester.getRect(button);
      final icon = tester.getRect(
        find.descendant(of: button, matching: find.byIcon(Icons.add)),
      );
      // The label, then its key.
      final label = tester.getRect(
        find.descendant(of: button, matching: find.text('⌘N')),
      );
      // The icon at its start, the key's cap at its end, as far in.
      expect(icon.left - box.left, 12);
      expect(box.right - label.right, closeTo(13, 1));
      expect(label.left, greaterThan(box.center.dx));
      // A card's fill, not the accent: that is for the one action of a card.
      expect(box.height, WideButton.height);
      d.dispose();
    }, variant: onMac);
  }

  // An idle app's sidebar goes on with the clock: the ages its rows show,
  // and the Date groups past midnight.
  testWidgets('the rows’ ages and the Date groups follow the clock', (
    tester,
  ) async {
    viewport(tester, const Size(1200, 700));
    // The fake's chats count from fixtureNow, noon on the 29th.
    final noon = fixtureNow;
    sidebarShows.value = {...defaultRowParts, RowPart.time};
    final d = await FakeDaemon([
      chat('a', 'claude', 'Fix the login redirect', age: 2),
    ]).connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(find.text('2m'), findsOneWidget);
    clock = () => noon.add(const Duration(hours: 3));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('3h'), findsOneWidget);

    sidebarShows.value = defaultRowParts;
    sidebarGroupBy.value = GroupBy.date;
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    clock = () => DateTime(2026, 10, 30, 0, 30);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsNothing);
    expect(find.text('Yesterday'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);
}
