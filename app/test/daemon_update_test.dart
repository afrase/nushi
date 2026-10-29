import 'package:connectrpc/connect.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';

/// A fake daemon whose Ping answers [ping] (null: no daemon answers).
/// Its restart waits for chat c's turn and a command in chat r's
/// terminal.
FakeDaemon _daemon(PingResponse? Function() ping) =>
    FakeDaemon([
        chat('c', 'claude', 'Fix the login redirect'),
        chat('r', 'codex', 'Release notes', age: 1),
      ])
      ..answer = (input) => switch (input) {
        PingRequest() =>
          ping() ?? (throw ConnectException(Code.unavailable, 'no daemon')),
        RestartWhenIdleRequest() => RestartWhenIdleResponse(
          holds: [
            RestartHold(chatId: 'c', why: 'working'),
            RestartHold(
              chatId: 'r',
              why: 'running npm run dev',
              terminal: true,
            ),
          ],
        ),
        _ => null,
      };

/// The app on [fake], bundling a daemon built at time 2000.
Future<Daemon> _open(
  WidgetTester tester,
  FakeDaemon fake, {
  double width = 900,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 500);
  addTearDown(tester.view.reset);
  final d = Daemon(transport: fake)..bundled = '7-2000';
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

int _asks(FakeDaemon fake) =>
    fake.calls.whereType<RestartWhenIdleRequest>().length;

const _bar = 'Nushi will update its daemon when the chats are idle.';

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('an older daemon is asked to restart when idle, again with '
      'each ping; the bar says so until the new one answers', (tester) async {
    var running = '7-1000'; // then gone, then the bundled one
    final fake = _daemon(
      () => running.isEmpty
          ? null
          : PingResponse(apiVersion: apiVersion, build: running),
    );
    final d = await _open(tester, fake);
    expect(find.text(_bar), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
    expect(find.text('Fix the login redirect'), findsWidgets); // the app shows
    final asked = _asks(fake);
    expect(asked, greaterThan(0));
    await tester.pump(const Duration(seconds: 4));
    expect(_asks(fake), greaterThan(asked));

    // It restarts: gone a moment, then the bundled one answers.
    running = '';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(DaemonBanner.grace); // shown once it's not a blip
    expect(find.text('Starting the new daemon…'), findsOneWidget);
    expect(find.text(_bar), findsNothing);
    running = '7-2000';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Starting the new daemon…'), findsNothing);
    expect(find.text(_bar), findsNothing);
    final after = _asks(fake);
    await tester.pump(const Duration(seconds: 4));
    expect(_asks(fake), after);
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('the bar, ${width.toInt()} wide ($name)', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final fake = _daemon(
          () => PingResponse(apiVersion: apiVersion, build: '7-1000'),
        );
        final d = await _open(tester, fake, width: width);
        final bar = tester.getRect(find.byType(DaemonUpdateBar));
        final button = tester.getRect(find.text('Restart now'));
        expect((bar.left, bar.width), (0, width));
        expect(button.right, greaterThan(width - 40)); // at the trailing edge
        await expectLater(
          find.byType(DaemonUpdateBar),
          matchesGoldenFile('goldens/daemon_update_${width.toInt()}_$name.png'),
        );
        d.dispose();
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }

  testWidgets('a daemon too old to restart itself keeps the Restart daemon '
      'screen, unasked', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: restartWhenIdleApi - 1, build: '7-1000'),
    );
    final d = await _open(tester, fake);
    expect(find.textContaining('The daemon is older than this app'), findsOne);
    expect(find.text('Restart daemon'), findsOneWidget);
    expect(find.text(_bar), findsNothing);
    expect(_asks(fake), 0);
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a daemon newer than the bundled one (an older copy of the app '
      'open) is left alone', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiVersion, build: '7-3000'),
    );
    final d = await _open(tester, fake);
    expect(find.text(_bar), findsNothing);
    expect(_asks(fake), 0);
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a prompt refused while the daemon restarts goes again to the '
      'new one', (tester) async {
    var running = '7-1000';
    var refused = 0;
    final sent = <String>[];
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        PingRequest() when running.isEmpty => throw ConnectException(
          Code.unavailable,
          'no daemon',
        ),
        PingRequest() => PingResponse(apiVersion: apiVersion, build: running),
        SendPromptRequest() when running == '7-1000' => () {
          refused++;
          throw ConnectException(
            Code.unavailable,
            'the daemon is restarting into a newer build',
          );
        }(),
        SendPromptRequest(:final text) => () {
          sent.add(text);
          return SendPromptResponse();
        }(),
        _ => null,
      };
    final d = Daemon(transport: fake);
    await tester.pump();
    var done = false;
    d.sendPrompt(SendPromptRequest(chatId: 'c', text: 'hi')).then((_) {
      done = true;
    }).ignore();
    await tester.pump(const Duration(seconds: 1));
    expect((refused, done), (1, false));
    running = '';
    await tester.pump(const Duration(seconds: 2));
    running = '7-2000';
    await tester.pump(const Duration(seconds: 3));
    expect(done, isTrue);
    expect(sent, ['hi']);
    d.dispose();
  });

  testWidgets("another failure of a prompt is the caller's", (tester) async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is SendPromptRequest
          ? throw ConnectException(Code.unavailable, 'no daemon')
          : null;
    final d = Daemon(transport: fake);
    await tester.pump();
    await expectLater(
      d.sendPrompt(SendPromptRequest(chatId: 'c', text: 'hi')),
      throwsA(isA<ConnectException>()),
    );
    d.dispose();
  });

  // UX review, finding 11: the bar says what it waits for.
  testWidgets('the bar says what the restart waits for, each a link to its '
      'chat', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiVersion, build: '7-1000'),
    );
    final d = await _open(tester, fake, width: 1700);
    await d.ping();
    await tester.pumpAndSettle();
    expect(find.text('Waiting for:'), findsOne);
    expect(find.text(' (working),'), findsOne);
    expect(find.text('a terminal running npm run dev in '), findsOne);
    await tester.tap(find.text('Release notes').last);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'r');
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
