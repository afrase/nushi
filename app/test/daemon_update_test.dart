import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

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

/// The app on [fake], bundling a daemon built at time 2000 ([bundled]:
/// null when it bundles none).
Future<Daemon> _open(
  WidgetTester tester,
  FakeDaemon fake, {
  double width = 900,
  String? bundled = '7-2000',
}) async {
  viewport(tester, Size(width, 500));
  final d = Daemon(transport: fake)..bundled = bundled;
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

int _asks(FakeDaemon fake) =>
    fake.calls.whereType<RestartWhenIdleRequest>().length;

const _bar = 'Nushi will update its daemon when the chats are idle.';

void main() {
  setUpAll(loadFonts);

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
    final banner = tester.getRect(find.byType(DaemonBanner));
    expect(banner.left, greaterThanOrEqualTo(200)); // clear of the lights
    running = '7-2000';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Starting the new daemon…'), findsNothing);
    expect(find.text(_bar), findsNothing);
    final after = _asks(fake);
    await tester.pump(const Duration(seconds: 4));
    expect(_asks(fake), after);
    d.dispose();
  }, variant: onMac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    if (rendering) ('light', Brightness.light),
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
        // A row under the main pane's header, across it (ADR 0128).
        expect(bar.top, greaterThan(PaneHeader.height));
        expect(bar.right, width - NushiTheme.windowPad);
        expect(button.right, lessThan(bar.right)); // inside it, at its end
        await render(
          tester,
          find.byType(DaemonUpdateBar),
          'daemon_update_${width.toInt()}_$name',
        );
        d.dispose();
      }, variant: onMac);
    }
  }

  // ADR 0004: below the floor, the Restart screen alone; the pings still
  // ask the daemon to restart once idle, so the screen clears by itself.
  testWidgets('a daemon below the floor gets the Restart screen alone, '
      'asked to restart when idle; the new one clears it', (tester) async {
    var running = PingResponse(apiVersion: apiFloor - 1, build: '7-1000');
    final fake = _daemon(() => running);
    final d = await _open(tester, fake);
    d.select('c');
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(OutdatedScreen), findsOne);
    expect(find.text('Restart daemon'), findsOneWidget);
    expect(find.text(_bar), findsNothing);
    expect(find.text('Fix the login redirect'), findsNothing);
    final asked = _asks(fake);
    expect(asked, greaterThan(0));
    await tester.pump(const Duration(seconds: 4));
    expect(_asks(fake), greaterThan(asked));
    // Behind the screen the window shows nothing: the daemon isn't told.
    expect(fake.calls.whereType<SetDeviceViewRequest>(), isEmpty);

    // Idle, it restarts into the bundled one: the app comes back.
    running = PingResponse(apiVersion: apiVersion, build: '7-2000');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(OutdatedScreen), findsNothing);
    expect(find.text('Fix the login redirect'), findsWidgets);
    final after = _asks(fake);
    await tester.pump(const Duration(seconds: 4));
    expect(_asks(fake), after);
    d.dispose();
  }, variant: onMac);

  // The screen hides the chats, so it says what the restart waits for, and
  // Restart daemon asks before it stops a running turn.
  testWidgets('below the floor the Restart screen says it restarts by '
      'itself and what it waits for, and asks before restarting', (
    tester,
  ) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiFloor - 1, build: '7-1000'),
    );
    final d = await _open(tester, fake);
    // Chat c's turn runs, as its hold says.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(9),
        status: ChatStatus(busy: true),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(OutdatedScreen), findsOne);
    expect(find.textContaining('by itself once the chats are idle'), findsOne);
    expect(
      find.text(
        'Waiting for: Fix the login redirect (working), a terminal running '
        'npm run dev in Release notes',
      ),
      findsOne,
    );
    await tester.tap(find.text('Restart daemon'));
    await tester.pumpAndSettle();
    expect(find.text('Restart the daemon?'), findsOne);
    expect(find.textContaining('stops 1 running turn'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(d.restarting, isFalse);
    d.dispose();
  }, variant: onMac);

  for (final b in Brightness.values) {
    for (final width in [1700.0, 720.0]) {
      renderTest('the Restart screen, waiting, ${width.toInt()} wide '
          '(${b.name})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = b;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final fake = _daemon(
          () => PingResponse(apiVersion: apiFloor - 1, build: '7-1000'),
        );
        final d = await _open(tester, fake, width: width);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'outdated_screen_${width.toInt()}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);
    }
  }

  // The menu bar, keys and palette sit above the screen: what acts on the
  // chat hidden behind it does nothing, and the palette doesn't open.
  testWidgets('behind the Restart screen the chat acts do nothing; Restart '
      'daemon still asks', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiFloor - 1, build: '7-1000'),
    );
    final d = await _open(tester, fake);
    d.select('c');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(d.blocked, isTrue);
    final context = tester.element(find.byType(OutdatedScreen));
    for (final act in [Act.archive, Act.stop, Act.pin, Act.newChat]) {
      runAct(context, d, act);
    }
    runAct(context, d, Act.palette);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<ArchiveChatRequest>(), isEmpty);
    expect(fake.calls.whereType<PinChatsRequest>(), isEmpty);
    expect(find.byType(OutdatedScreen), findsOne);
    expect(find.byType(EditableText), findsNothing); // no palette, no dialog
    d.dispose();
  }, variant: onMac);

  // From the floor up, the app works on while the daemon waits for idle.
  for (final api in [apiFloor, apiFloor + 1]) {
    testWidgets('a daemon at API $api, at or above the floor, keeps the app '
        'with the bar, asked to restart when idle', (tester) async {
      final fake = _daemon(
        () => PingResponse(apiVersion: api, build: '7-1000'),
      );
      final d = await _open(tester, fake);
      d.select('c');
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(OutdatedScreen), findsNothing);
      expect(find.text(_bar), findsOneWidget);
      expect(find.text('Fix the login redirect'), findsWidgets);
      expect(_asks(fake), greaterThan(0));
      expect(fake.calls.whereType<SetDeviceViewRequest>(), isNotEmpty);
      d.dispose();
    }, variant: onMac);
  }

  testWidgets('a daemon too old to know RestartWhenIdle keeps the Restart '
      'screen, its refusal ignored', (tester) async {
    final fake = _daemon(() => PingResponse(apiVersion: 76, build: '7-1000'));
    var refused = 0;
    fake.on((input) {
      if (input is! RestartWhenIdleRequest) return null;
      refused++;
      throw ConnectException(Code.unimplemented, 'unknown procedure');
    });
    final d = await _open(tester, fake);
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('The daemon is older than this app'), findsOne);
    expect(find.text('Restart daemon'), findsOneWidget);
    expect(find.text(_bar), findsNothing);
    // It won't restart by itself, so the screen doesn't say it will.
    expect(find.textContaining('by itself'), findsNothing);
    expect(find.textContaining('Waiting for'), findsNothing);
    expect(refused, greaterThan(0));
    expect(tester.takeException(), isNull);
    d.dispose();
  }, variant: onMac);

  testWidgets('with no bundled daemon to restart into, an older daemon gets '
      'the Restart screen, unasked', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiFloor, build: '7-1000'),
    );
    final d = await _open(tester, fake, bundled: null);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(OutdatedScreen), findsOne);
    expect(_asks(fake), 0);
    d.dispose();
  }, variant: onMac);

  testWidgets('a daemon newer than the bundled one (an older copy of the app '
      'open) is left alone', (tester) async {
    final fake = _daemon(
      () => PingResponse(apiVersion: apiVersion, build: '7-3000'),
    );
    final d = await _open(tester, fake);
    expect(find.text(_bar), findsNothing);
    expect(_asks(fake), 0);
    d.dispose();
  }, variant: onMac);

  // The daemon's reason says so (Nushi-Reason: restarting).
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
            "the message goes once it's back",
            metadata: Headers()..add('nushi-reason', 'restarting'),
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
    for (final e in [
      ConnectException(Code.unavailable, 'no daemon'),
      // Another reason wins over the words.
      ConnectException(
        Code.unavailable,
        'restarting',
        metadata: Headers()..add('nushi-reason', 'other'),
      ),
    ]) {
      final fake = FakeDaemon([])
        ..answer = (input) => input is SendPromptRequest ? throw e : null;
      final d = Daemon(transport: fake);
      await tester.pump();
      await expectLater(
        d.sendPrompt(SendPromptRequest(chatId: 'c', text: 'hi')),
        throwsA(isA<ConnectException>()),
      );
      d.dispose();
    }
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
  }, variant: onMac);
}
