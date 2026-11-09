import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/fonts_linux.dart';
import 'package:nushi/native.dart';
import 'package:nushi/place.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

// Settings in Linux's words and with its fonts (ADR 0104), as a Linux
// machine shows them: its conventions, window and platform together.

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

void _onLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow()
  ..fonts = LinuxFonts(
    run: (_, _) async => ProcessResult(
      1,
      0,
      'DejaVu Sans Mono,DejaVu Sans Mono Book\nLiberation Mono\n'
          'JetBrains Mono\nAdwaita Mono\n',
      '',
    ),
  );

void main() {
  setUpAll(loadFonts);

  for (final width in [1700.0, 720.0]) {
    testWidgets('Notifications say the app icon’s badge and this computer, '
        '${width.toInt()} wide', (tester) async {
      _onLinux();
      final d = await FakeDaemon([]).connect(tester);
      await pumpSettings(
        tester,
        d,
        SettingsSection.general,
        size: Size(width, 1100),
      );
      await tester.scrollUntilVisible(
        find.text('App icon badge'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Dock badge'), findsNothing);
      expect(find.textContaining('They stay on this computer.'), findsOne);
      expect(find.textContaining('Mac'), findsNothing);
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(MaterialApp),
        'linux_settings_notifications_${width.toInt()}',
      );
      d.dispose();
    }, variant: _linux);

    testWidgets('Terminal offers fontconfig’s monospaced families, '
        '${width.toInt()} wide', (tester) async {
      _onLinux();
      final d = await FakeDaemon([]).connect(tester);
      await pumpSettings(
        tester,
        d,
        SettingsSection.terminal,
        size: Size(width, 1100),
      );
      await tester.tap(find.text(NushiTheme.codeFont).first);
      await tester.pumpAndSettle();
      for (final f in ['Adwaita Mono', 'DejaVu Sans Mono', 'Liberation Mono']) {
        expect(find.text(f, findRichText: true), findsOne, reason: f);
      }
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(MaterialApp),
        'linux_settings_terminal_${width.toInt()}',
      );
      d.dispose();
    }, variant: _linux);
  }
}
