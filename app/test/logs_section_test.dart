import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/logs_section.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

Widget _app(Widget child) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('Show logs reveals them; the switch sets debug lines', (
    tester,
  ) async {
    var revealed = 0;
    final set = <bool>[];
    await tester.pumpWidget(
      _app(
        LogsSection(
          debug: false,
          onDebug: set.add,
          reveal: () async => revealed++,
        ),
      ),
    );
    await tester.tap(find.text('Show logs'));
    await tester.tap(find.byType(Switch));
    expect(revealed, 1);
    expect(set, [true]);
    expect(find.text('Debug lines'), findsOneWidget);
  });

  testWidgets('no switch until the daemon says', (tester) async {
    await tester.pumpWidget(
      _app(LogsSection(debug: null, onDebug: (_) {}, reveal: () async {})),
    );
    expect(find.text('Show logs'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Settings sets debug lines and keeps the sleep time', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    final fake = FakeDaemon([])
      ..settings = Settings(sleepAfterMinutes: 60, debugLog: false);
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSettings(context, d.client),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Debug lines'));
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Debug lines'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.debugLog, isTrue);
    expect(fake.setSettings.single.sleepAfterMinutes, 60);
    d.dispose();
  });
}
