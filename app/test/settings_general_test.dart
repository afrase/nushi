import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_general.dart';
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

  // The preview draws its Nerd Font icons as the terminal does: through
  // the bundled fallback, not the picked font's ?-box (NOTES, [controls]).
  testWidgets('the terminal preview draws its icons from the bundled Nerd '
      'Font', (tester) async {
    final (_, d) = await _open(tester, SettingsSection.terminal);
    final preview = tester.widget<Text>(
      find.byKey(const ValueKey('terminal-preview')),
    );
    final style = preview.style!;
    expect(style.fontFamilyFallback, terminalStyle().fontFamilyFallback);
    double width(String s, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final icons = {
      for (final r in preview.data!.runes)
        if (r >= 0xe000 && r <= 0xf8ff) String.fromCharCode(r),
    };
    expect(icons, hasLength(6)); // two folders, branch, Go, Dart, Markdown
    final symbols = TextStyle(
      fontFamily: 'Symbols Nerd Font Mono',
      fontSize: style.fontSize,
    );
    final alone = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
    );
    for (final icon in icons) {
      final code = icon.runes.single.toRadixString(16);
      expect(width(icon, style), width(icon, symbols), reason: code);
      // JetBrains Mono alone draws its ?-box, of another width.
      expect(width(icon, alone), isNot(width(icon, symbols)), reason: code);
    }
    d.dispose();
  });

  // UX review, finding 15: remembered, not the View menu's state alone.
  testWidgets('the appearance is a setting, kept in app.json', (tester) async {
    Directory(dataDir).createSync(recursive: true);
    final (_, d) = await _open(tester, SettingsSection.general);
    expect(find.text('As the system'), findsOne);
    await tester.tap(find.text('As the system'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(appearance.value, ThemeMode.dark);
    expect(readSaved()['appearance'], 'dark');
    expect(find.text('Dark'), findsOne); // the field says it
    d.dispose();
  });
}
