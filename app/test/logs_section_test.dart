import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/logs_section.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'settings_harness.dart';

Future<Daemon> _section(
  WidgetTester tester, {
  required bool? debug,
  required ValueChanged<bool> onDebug,
  required Future<void> Function() reveal,
}) async {
  final d = await FakeDaemon([]).connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: LogsSection(
          daemon: d,
          debug: debug,
          onDebug: onDebug,
          reveal: reveal,
        ),
      ),
    ),
  );
  return d;
}

void main() {
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
    final set = <bool>[];
    final d = await _section(
      tester,
      debug: false,
      onDebug: set.add,
      reveal: () async => revealed++,
    );
    await tester.tap(find.text('Show logs'));
    await tester.tap(find.byType(Switch));
    expect(revealed, 1);
    expect(set, [true]);
    expect(find.text('Debug lines'), findsOneWidget);
    expect(find.text('API $apiVersion'), findsOneWidget);
    d.dispose();
  });

  testWidgets('no switch until the daemon says', (tester) async {
    final d = await _section(
      tester,
      debug: null,
      onDebug: (_) {},
      reveal: () async {},
    );
    expect(find.text('Show logs'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    d.dispose();
  });

  testWidgets('Settings sets debug lines and keeps the sleep time', (
    tester,
  ) async {
    final fake = FakeDaemon([])
      ..settings = Settings(sleepAfterMinutes: 60, debugLog: false);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.logs);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.debugLog, isTrue);
    expect(fake.setSettings.single.sleepAfterMinutes, 60);
    d.dispose();
  });
}
