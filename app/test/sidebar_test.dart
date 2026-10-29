import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

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
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 600);
      addTearDown(tester.view.reset);
      final d = await FakeDaemon(_chats).connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: MediaQuery(
            // Still, so the working chat's mark doesn't breathe.
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: const Key('shot'),
                  child: SizedBox(
                    width: 260,
                    height: 540,
                    child: Sidebar(daemon: d),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
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
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(width, 600);
      addTearDown(tester.view.reset);
      paneWidths.value = {};
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
        matching: find.widgetWithText(Button, 'New chat'),
      );
      final box = tester.getRect(button);
      final icon = tester.getRect(
        find.descendant(of: button, matching: find.byIcon(Icons.add)),
      );
      // The label, then its key.
      final label = tester.getRect(
        find.descendant(of: button, matching: find.text('⌘N')),
      );
      expect(box.width, greaterThan(label.right - icon.left + 40));
      expect((icon.left - box.left) - (box.right - label.right), closeTo(0, 1));
      // A secondary button: the accent is for the one action of a card.
      expect(tester.widget<Button>(button).kind, ButtonKind.secondary);
      d.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
