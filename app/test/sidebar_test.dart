import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// Chats of all five agents, in each status.
final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the login redirect', status: ChatStatus(busy: true)),
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
}
