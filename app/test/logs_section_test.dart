import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/controls.dart' show Button, Toggle;
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/logs_section.dart';

import 'fake_app_install.dart';
import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// The section on [fake]'s daemon, its settings asked for as Settings
/// asks (disposed with the test).
Future<Daemon> _section(
  WidgetTester tester,
  FakeDaemon fake, {
  Future<void> Function() reveal = _nothing,
}) async {
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(LogsSection(daemon: d, settings: _settings(d), reveal: reveal)),
  );
  await tester.pump();
  return d;
}

DaemonSettings _settings(Daemon d) {
  final s = DaemonSettings(d);
  addTearDown(s.dispose);
  return s;
}

Future<void> _nothing() async {}

void main() {
  setUpAll(loadFonts);

  test("a daemon build's time", () {
    expect(buildTime('1234-1761555000000'), isNotNull);
    expect(
      buildTime('1234-1761555000000')!.millisecondsSinceEpoch,
      1761555000000,
    );
    expect(buildTime(''), isNull);
    expect(buildTime('garbage'), isNull);
  });

  testWidgets('Show logs reveals them; the switch sets debug lines', (
    tester,
  ) async {
    var revealed = 0;
    final fake = FakeDaemon([])..settings = Settings(debugLog: false);
    final d = await _section(tester, fake, reveal: () async => revealed++);
    await tester.tap(find.text('Show logs'));
    await tester.tap(find.byType(Toggle));
    await tester.pump();
    expect(revealed, 1);
    expect([for (final s in fake.setSettings) s.debugLog], [true]);
    expect(find.text('Debug lines'), findsOneWidget);
    expect(find.text('API $apiVersion'), findsOneWidget);
    d.dispose();
  });

  testWidgets('the debug switch sends once, however often it is clicked', (
    tester,
  ) async {
    final sent = Completer<SetSettingsResponse>();
    final fake = FakeDaemon([])
      ..settings = Settings(debugLog: false)
      ..on((input) => input is SetSettingsRequest ? sent.future : null);
    final d = await _section(tester, fake);
    await tester.tap(find.byType(Toggle));
    await tester.pump();
    await tester.tap(find.byType(Toggle));
    await tester.pump();
    expect(fake.setSettings, hasLength(1));
    sent.complete(SetSettingsResponse());
    await tester.pump();
    d.dispose();
  });

  testWidgets("a packaged daemon's release shows beside its API", (
    tester,
  ) async {
    final fake = FakeDaemon([])
      ..answer = (r) => r is PingRequest
          ? PingResponse(apiVersion: apiVersion, version: '1.2.0')
          : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      themed(LogsSection(daemon: d, settings: _settings(d))),
    );
    expect(find.text('Version 1.2.0, API $apiVersion'), findsOneWidget);
    d.dispose();
  });

  testWidgets('Restart shows for a packaged daemon, and not without one: '
      'here nor in the palette', (tester) async {
    fakeInstall.daemon = '/opt/nushi/lib/nushid';
    final d = await FakeDaemon([]).connect(tester);
    late BuildContext context;
    Future<void> show() async {
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (c) {
              context = c;
              return LogsSection(daemon: d, settings: _settings(d));
            },
          ),
        ),
      );
      await tester.pump();
    }

    bool restartRow() =>
        appActions(context, d).any((a) => a.act == Act.restart && a.enabled);

    await show();
    expect(find.text('Restart'), findsOneWidget);
    expect(restartRow(), isTrue);
    fakeInstall.daemon = null;
    await show();
    expect(find.text('Restart'), findsNothing);
    expect(restartRow(), isFalse);
    d.dispose();
  });

  testWidgets('Restart keeps its place and width while it reads '
      'Restarting…', (tester) async {
    fakeInstall.daemon = '/opt/nushi/lib/nushid';
    final d = await _section(tester, FakeDaemon([]));
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    final rest = tester.getRect(button('Restart'));
    Object? failed;
    unawaited(
      d.restartDaemon().then((_) {}, onError: (Object e) => failed = e),
    );
    await tester.pump();
    expect(tester.getRect(button('Restarting…')), rest);
    // The fake daemon never stops: the restart gives up.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(failed, isA<StateError>());
    expect(tester.getRect(button('Restart')), rest);
    d.dispose();
  });

  for (final size in const [Size(1700, 1000), Size(720, 900)]) {
    renderTest('Logs & advanced, Restart and Restarting…, at '
        '${size.width.round()} wide', (tester) async {
      for (final b in Brightness.values) {
        fakeInstall.daemon = '/opt/nushi/lib/nushid';
        final d = await pumpSettingsApp(
          tester,
          settingsFake(),
          SettingsSection.logs,
          size: size,
          brightness: b,
        );
        final name = 'settings_logs_restart_${size.width.round()}_${b.name}';
        await render(tester, find.byType(MaterialApp), name);
        Object? failed;
        unawaited(
          d.restartDaemon().then((_) {}, onError: (Object e) => failed = e),
        );
        await tester.pump();
        await render(tester, find.byType(MaterialApp), '${name}_restarting');
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
        expect(failed, isA<StateError>());
        await closeView(tester, d);
      }
    }, variant: onMac);
  }

  testWidgets('no switch until the daemon says', (tester) async {
    final asked = Completer<GetSettingsResponse>();
    final fake = FakeDaemon([])
      ..on((input) => input is GetSettingsRequest ? asked.future : null);
    final d = await _section(tester, fake);
    expect(find.text('Show logs'), findsOneWidget);
    expect(find.byType(Toggle), findsNothing);
    asked.complete(GetSettingsResponse(settings: Settings(debugLog: true)));
    await tester.pumpAndSettle();
    expect(find.byType(Toggle), findsOneWidget);
    d.dispose();
  });

  testWidgets('Settings sets debug lines and keeps the sleep time', (
    tester,
  ) async {
    final fake = FakeDaemon([])
      ..settings = Settings(sleepAfterMinutes: 60, debugLog: false);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.logs);
    await tester.tap(find.byType(Toggle));
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.debugLog, isTrue);
    expect(fake.setSettings.single.sleepAfterMinutes, 60);
    d.dispose();
  });
}
