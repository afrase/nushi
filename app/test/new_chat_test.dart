import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// The newest chat is Codex's, so the dialog starts on Codex.
final _chats = [
  chat('a', 'claude', 'Older', age: 5),
  chat('b', 'codex', 'Newer', age: 1),
];

Future<(FakeDaemon, Daemon)> _sidebar(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon(_chats);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(width: 260, child: Sidebar(daemon: d)),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
  return (fake, d);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('New chat'));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

final _now = DateTime.now();

/// Sessions a terminal started, the newest first.
ListAgentSessionsResponse _found(ListAgentSessionsRequest r) =>
    switch (r.cursor) {
      '' => ListAgentSessionsResponse(
        canList: true,
        seesOpen: r.agent == 'claude',
        nextCursor: 'p2',
        sessions: [
          FoundSession(
            sessionId: 's1',
            title: 'Fix the flaky test',
            folder: '/Users/me/nushi',
            updatedUnixMs: Int64(
              _now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
            ),
            messages: 12,
            openIn: 'a terminal',
          ),
          FoundSession(
            sessionId: 's2',
            title: 'Rename the relay flags',
            folder: '/Users/me/relay',
            updatedUnixMs: Int64(
              _now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
            ),
          ),
          FoundSession(
            sessionId: 's3',
            folder: '/Users/me/old',
            folderGone: true,
            updatedUnixMs: Int64(
              _now.subtract(const Duration(days: 4)).millisecondsSinceEpoch,
            ),
          ),
        ],
      ),
      _ => ListAgentSessionsResponse(
        canList: true,
        sessions: [FoundSession(sessionId: 's4', title: 'Older one')],
      ),
    };

void main() {
  setUpAll(loadFonts);

  testWidgets('the last agent is picked: Enter starts it at once', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    expect(find.text('oh-my-pi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.single.agent, 'codex');
    expect(fake.started.single.folder, '');
    expect(find.text('oh-my-pi'), findsNothing); // closed
    d.dispose();
  });

  testWidgets('arrows move, a digit or a click starts, Esc cancels', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.arrowDown); // codex → ante
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.last.agent, 'ante');

    await _open(tester);
    await _key(tester, LogicalKeyboardKey.arrowUp); // codex → claude
    await _key(tester, LogicalKeyboardKey.arrowUp); // wraps → omp
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.last.agent, 'omp');

    await _open(tester);
    await _key(tester, LogicalKeyboardKey.digit1);
    expect(fake.started.last.agent, 'claude');

    await _open(tester);
    await tester.tap(find.text('oh-my-pi'));
    await tester.pumpAndSettle();
    expect(fake.started.last.agent, 'omp');

    await _open(tester);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('oh-my-pi'), findsNothing);
    expect(fake.started, hasLength(4));
    d.dispose();
  });

  testWidgets('an agent that didn’t start shows dimmed, with why', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    fake.startError =
        "couldn't start Codex: start agent: npx didn't find codex-acp: exit "
        'status 1';
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.enter); // codex fails
    expect(find.textContaining("couldn't start Codex"), findsOneWidget);

    fake.startError = null;
    await _open(tester);
    expect(find.text("npx didn't find codex-acp"), findsOneWidget);
    // Not picked any more: Enter starts the first that didn't fail.
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.last.agent, 'claude');

    // It can still be tried, and once it starts it's as before.
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(fake.started.last.agent, 'codex');
    await _open(tester);
    expect(find.text("npx didn't find codex-acp"), findsNothing);
    d.dispose();
  });

  testWidgets('a folder’s + and its menu open the dialog for the folder', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    await tester.tap(find.byTooltip('New chat here'));
    await tester.pumpAndSettle();
    expect(find.text('New chat in nushi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.last.folder, '/Users/me/nushi');

    await tester.tap(find.text('nushi'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat here').last);
    await tester.pumpAndSettle();
    expect(find.text('New chat in nushi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.digit3);
    expect(fake.started.last.agent, 'ante');
    expect(fake.started.last.folder, '/Users/me/nushi');
    d.dispose();
  });

  testWidgets('⌘N opens it', (tester) async {
    final fake = FakeDaemon(_chats);
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pump();
    // Keys go where the focus is: somewhere in the window.
    Focus.of(tester.element(find.text('New chat'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('oh-my-pi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.single.agent, 'codex');
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('→ lists the agent’s sessions; Enter opens one there', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    fake.sessions = _found;
    await tester.tap(find.byTooltip('New chat here'));
    await tester.pumpAndSettle();
    expect(find.text('Open a Codex session…'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Codex sessions in nushi'), findsOneWidget);
    expect(fake.listed.single.agent, 'codex');
    expect(fake.listed.single.folder, '/Users/me/nushi');
    expect(find.text('Rename the relay flags'), findsOneWidget);
    // Codex can't tell a session open elsewhere: the list says so once.
    expect(find.textContaining('both will write'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.opened.single.sessionId, 's2');
    expect(fake.opened.single.folder, '/Users/me/nushi');
    expect(fake.opened.single.title, 'Rename the relay flags');
    expect(fake.started, isEmpty);
    d.dispose();
  });

  testWidgets('← and Esc go back; the quick path is as it was', (tester) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('No other sessions here.'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await _key(tester, LogicalKeyboardKey.arrowDown); // codex → ante
    await tester.tap(find.text('Open an Ante session…'));
    await tester.pumpAndSettle();
    expect(find.text('Ante sessions'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('oh-my-pi'), findsOneWidget); // back, still open
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.single.agent, 'ante');
    expect(fake.opened, isEmpty);
    d.dispose();
  });

  testWidgets('one open in a terminal asks first; a gone folder can’t open', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    fake.sessions = _found;
    await _open(tester); // no folder: every folder's
    await _key(tester, LogicalKeyboardKey.arrowUp); // codex → claude
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Claude sessions'), findsOneWidget);
    expect(
      find.textContaining('both will write'),
      findsNothing,
    ); // Claude tells
    expect(find.textContaining('open in a terminal'), findsOneWidget);
    expect(find.textContaining('relay'), findsWidgets); // each one's folder
    await tester.tap(find.textContaining('folder gone'));
    await tester.pumpAndSettle();
    expect(find.text('Claude sessions'), findsOneWidget); // nothing happened
    await tester.tap(find.text('More'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(fake.listed.last.cursor, 'p2');
    expect(find.text('Older one'), findsOneWidget);
    await tester.tap(find.text('Fix the flaky test'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "It's open in a terminal. Both will write to the same "
        'history.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(fake.opened.single.sessionId, 's1');
    expect(fake.opened.single.folder, '/Users/me/nushi'); // its own
    d.dispose();
  });

  testWidgets('an agent that can’t list says so', (tester) async {
    final (fake, d) = await _sidebar(tester);
    fake.sessions = (_) => ListAgentSessionsResponse();
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text("Codex can't list its sessions."), findsOneWidget);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the dialog ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(700, 400);
      addTearDown(tester.view.reset);
      final (fake, d) = await _sidebar(tester, tokens: tokens);
      d.cantStart['ante'] =
          "couldn't start Ante: initialize: acp error -32603: Ante isn't "
          "installed: there's no ante on "
          'PATH or in ~/.ante/bin';
      await tester.tap(find.byTooltip('New chat here'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/new_chat_$name.png'),
      );
      d.dispose();
    });
    testWidgets('the sessions ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(700, 400);
      addTearDown(tester.view.reset);
      final (fake, d) = await _sidebar(tester, tokens: tokens);
      fake.sessions = _found;
      await _open(tester);
      await _key(tester, LogicalKeyboardKey.arrowUp); // Claude
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/sessions_$name.png'),
      );
      d.dispose();
    });
  }
}
