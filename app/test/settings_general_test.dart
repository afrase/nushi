import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// Settings › General open on a fake daemon: sleep after 30 minutes,
/// copies kept 90 days, two of them, remote access off.
Future<(FakeDaemon, Daemon)> _open(WidgetTester tester, Tokens tokens) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>['Menlo', 'SF Mono'],
      );
  final now = DateTime.now().millisecondsSinceEpoch;
  final fake = FakeDaemon([])
    ..settings = Settings(
      sleepAfterMinutes: 30,
      debugLog: false,
      keepTranscripts: true,
      transcriptDays: 90,
    )
    ..answer = (input) => switch (input) {
      ListTranscriptsRequest() => ListTranscriptsResponse(
        totalBytes: Int64(5 << 20),
        copies: [
          TranscriptCopy(
            chatId: 'a',
            title: 'Fix the login redirect',
            bytes: Int64(4 << 20),
            lastWrittenMs: Int64(now - 2 * 3600 * 1000),
          ),
          TranscriptCopy(
            chatId: 'b',
            title: 'Review the diff view',
            bytes: Int64(1 << 20),
            lastWrittenMs: Int64(now - 26 * 3600 * 1000),
          ),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => showSettings(context, d.client),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, Settings › General, $name', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(620, 1180) * 2;
      addTearDown(tester.view.reset);
      final (_, d) = await _open(tester, tokens);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/settings_general_$name.png'),
      );
      d.dispose();
    });
  }

  testWidgets('the font, its size and the sleep time are menus that look it; '
      'Show logs is a button', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(620, 1180) * 2;
    addTearDown(tester.view.reset);
    final (fake, d) = await _open(tester, Tokens.dark);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<MouseCursor> over(String text) async {
      await mouse.moveTo(tester.getCenter(find.text(text)));
      await tester.pump();
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
    }

    for (final control in [
      'JetBrains Mono',
      '12.5',
      'After 30 minutes',
      '90 days',
      'Show logs',
    ]) {
      expect(await over(control), SystemMouseCursors.click, reason: control);
    }
    expect(await over('Font'), SystemMouseCursors.basic);
    expect(await over('Sleep idle'), SystemMouseCursors.basic);

    await tester.tap(find.text('After 30 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.sleepAfterMinutes, 60);
    d.dispose();
  });
}
