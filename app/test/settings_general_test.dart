import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_nav.dart';

import 'fake_daemon.dart';
import 'settings_harness.dart';

/// Settings at [section] on a fake daemon: sleep after 30 minutes.
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester,
  SettingsSection section,
) async {
  final fake = FakeDaemon([])
    ..settings = Settings(
      sleepAfterMinutes: 30,
      debugLog: false,
      keepTranscripts: true,
      transcriptDays: 90,
    );
  final d = await fake.connect(tester);
  await pumpSettings(tester, d, section);
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the font, its size and the sleep time are menus that look '
      'it; Show logs is a button', (tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<MouseCursor> over(String text) async {
      await mouse.moveTo(tester.getCenter(find.text(text)));
      await tester.pump();
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
    }

    for (final (section, control, label) in [
      (SettingsSection.terminal, 'JetBrains Mono', 'Font'),
      (SettingsSection.terminal, '12.5', 'Size'),
      (SettingsSection.general, 'After 30 minutes', 'Sleep idle chats'),
      (SettingsSection.logs, 'Show logs', 'Debug lines'),
    ]) {
      final (_, d) = await _open(tester, section);
      expect(await over(control), SystemMouseCursors.click, reason: control);
      expect(await over(label), SystemMouseCursors.basic, reason: label);
      d.dispose();
    }
  });

  testWidgets('a sleep time picked is set', (tester) async {
    final (fake, d) = await _open(tester, SettingsSection.general);
    await tester.tap(find.text('After 30 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.sleepAfterMinutes, 60);
    d.dispose();
  });
}
