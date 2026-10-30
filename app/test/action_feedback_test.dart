import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/update_toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The banner over an empty app, and a button running [onGo].
Widget _app(Tokens tokens, Daemon d, [void Function(BuildContext)? onGo]) =>
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Column(
          children: [
            RepaintBoundary(child: DaemonBanner(d)),
            Expanded(
              child: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => onGo?.call(context),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

/// A daemon whose ping answers as [phase] says: 'old', 'gone' (none
/// answers) or 'new'.
class _Phases {
  String phase = 'old';

  FakeDaemon fake() => FakeDaemon([])
    ..answer = (input) => switch (input) {
      PingRequest() when phase == 'gone' => throw ConnectException(
        Code.unavailable,
        'no daemon',
      ),
      PingRequest() => PingResponse(apiVersion: apiVersion, build: phase),
      _ => null,
    };
}

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a restart asked for shows at once, wherever it was asked '
        'from, and says when the new daemon is there ($name)', (tester) async {
      viewport(tester, const Size(520, 120));
      final p = _Phases();
      final d = await p.fake().connect(tester);
      await tester.pumpWidget(_app(tokens, d));
      final run = d.restartDaemon();
      await tester.pump();
      await tester.pump(DaemonBanner.slideFor);
      expect(find.text('Restarting the daemon…'), findsOneWidget);
      await expectLater(
        find.byType(DaemonBanner),
        matchesGoldenFile('goldens/daemon_banner_restarting_$name.png'),
      );

      p.phase = 'gone';
      await tester.pump(const Duration(milliseconds: 500));
      expect(d.connected, isFalse);
      expect(find.text('Restarting the daemon…'), findsOneWidget);
      p.phase = 'new';
      await tester.pump(const Duration(milliseconds: 500));
      await run;
      await tester.pump();
      expect(find.text('Daemon restarted'), findsOneWidget);
      await expectLater(
        find.byType(DaemonBanner),
        matchesGoldenFile('goldens/daemon_banner_restarted_$name.png'),
      );
      await tester.pump(DaemonBanner.backFor);
      await tester.pumpAndSettle();
      expect(find.text('Daemon restarted'), findsNothing);
      await closeView(tester, d);
    });
  }

  testWidgets('a restart that fails while the daemon still answers just '
      'goes; its caller says why', (tester) async {
    final p = _Phases();
    final d = await p.fake().connect(tester);
    await tester.pumpWidget(_app(Tokens.dark, d));
    Object? error;
    unawaited(d.restartDaemon().then((_) {}, onError: (Object e) => error = e));
    await tester.pump();
    expect(find.text('Restarting the daemon…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11)); // it never stopped
    await tester.pumpAndSettle();
    expect(error, isA<StateError>());
    expect(find.text('Restarting the daemon…'), findsNothing);
    expect(find.text('Daemon restarted'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('Reload from the menus says it runs, then that it is done', (
    tester,
  ) async {
    final reloaded = Completer<ReloadChatResponse>();
    final fake = FakeDaemon([chat('c', 'claude', 'Fix the login')])
      ..answer = (input) => input is ReloadChatRequest ? reloaded.future : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      _app(
        Tokens.dark,
        d,
        (context) => reloadChat(context, d.chats['c']!, d, say: true),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Reloading Fix the login…'), findsNothing); // a moment
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reloading Fix the login…'), findsOneWidget);
    reloaded.complete(ReloadChatResponse());
    await tester.pumpAndSettle();
    expect(find.text('Reloaded Fix the login'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('Check for updates says it asks, then what it found', (
    tester,
  ) async {
    final checked = Completer<CheckForUpdatesResponse>();
    final fake = FakeDaemon([])
      ..answer = (input) =>
          input is CheckForUpdatesRequest ? checked.future : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      _app(Tokens.dark, d, (context) => checkForUpdates(context, d)),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Checking for updates…'), findsOneWidget);
    checked.complete(
      CheckForUpdatesResponse(update: UpdateCheck(latest: 'v1.2.0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checking for updates…'), findsNothing);
    expect(find.textContaining('v1.2.0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('a fork says it runs; the toast goes as the new chat shows', (
    tester,
  ) async {
    final forked = Completer<ForkAsChatResponse>();
    final fake = FakeDaemon([chat('c', 'claude', 'Fix the login')])
      ..answer = (input) => input is ForkAsChatRequest ? forked.future : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      _app(Tokens.dark, d, (context) => forkChat(context, d, d.chats['c']!)),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Forking Fix the login…'), findsOneWidget);
    forked.complete(ForkAsChatResponse(chatId: 'f'));
    await tester.pumpAndSettle();
    expect(find.text('Forking Fix the login…'), findsNothing);
    expect(d.selectedId, 'f');
    await closeView(tester, d);
  });
}
