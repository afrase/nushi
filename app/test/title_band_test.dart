import 'package:connectrpc/connect.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings_view.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// What the window was asked of `nushi/window`.
List<String> _windowCalls() {
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(const MethodChannel('nushi/window'), (
          c,
        ) async {
          calls.add(c.method);
          return null;
        });
  addTearDown(
    () => messenger.setMockMethodCallHandler(
      const MethodChannel('nushi/window'),
      null,
    ),
  );
  return calls;
}

Future<void> _drag(WidgetTester tester, Offset at) async {
  await tester.timedDragFrom(
    at,
    const Offset(60, 30),
    const Duration(milliseconds: 200),
  );
  await tester.pumpAndSettle();
}

Future<void> _double(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

/// The app on a daemon whose Ping answers [ping] (null: none answers).
Future<Daemon> _open(WidgetTester tester, PingResponse? Function() ping) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  viewport(tester, const Size(1200, 700));
  final fake = FakeDaemon([chat('c', 'claude', 'Fix the login')])
    ..answer = (input) => switch (input) {
      PingRequest() =>
        ping() ?? (throw ConnectException(Code.unavailable, 'no daemon')),
      _ => null,
    };
  final d = Daemon(transport: fake)..bundled = '7-2000';
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  // AppKit's title bar no longer takes the window's top strip (ADR 0080),
  // so what covers the headers has a band of its own to move the window.
  testWidgets('with Settings open, the top of the dim moves the window, and '
      'a click there still shuts Settings', (tester) async {
    final calls = _windowCalls();
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    const top = Offset(1500, 20);
    await _drag(tester, top);
    expect(calls, ['drag']);
    // Below the band, the dim's a drag of nothing.
    await _drag(tester, const Offset(1500, 120));
    expect(calls, ['drag']);
    expect(d.settingsOpen, isNotNull);

    await tester.tapAt(top);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(find.byType(SettingsView), findsNothing);
    d.dispose();
  }, variant: mac);

  testWidgets('with no daemon yet, the top of the window moves and zooms it', (
    tester,
  ) async {
    final calls = _windowCalls();
    final d = await _open(tester, () => null);
    expect(find.text('Daemon not running'), findsOne);
    const top = Offset(600, 20);
    await _drag(tester, top);
    expect(calls, ['drag']);
    await tester.pump(const Duration(seconds: 1));
    await _double(tester, top);
    expect(calls, ['drag', 'zoom']);
    // The middle of the window is no title bar.
    await _drag(tester, const Offset(600, 300));
    expect(calls, ['drag', 'zoom']);
    d.dispose();
  }, variant: mac);

  testWidgets("the outdated daemon's screen moves the window from its top", (
    tester,
  ) async {
    final calls = _windowCalls();
    final d = await _open(
      tester,
      () => PingResponse(apiVersion: restartWhenIdleApi - 1, build: '7-1000'),
    );
    expect(find.byType(OutdatedScreen), findsOne);
    await _drag(tester, const Offset(600, 20));
    expect(calls, ['drag']);
    d.dispose();
  }, variant: mac);
}
