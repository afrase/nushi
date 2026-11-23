import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

// The box in command mode (a text starting with "!") beside the ordinary
// box: wide and narrow, dark and light, on the Mac and on Linux.
// Renders, looked at, never compared (NUSHI_RENDERS).

void main() {
  setUpAll(loadFonts);

  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 900), 'narrow'),
  ]) {
    for (final brightness in Brightness.values) {
      for (final linux in [false, true]) {
        final os = linux ? 'linux' : 'mac';
        testWidgets('the box, $os, $sizeName, ${brightness.name}', (
          tester,
        ) async {
          if (linux) native.conventions = linuxConventions;
          showDetails.value = false;
          final fake = FakeDaemon([chat('c', 'claude', 'Commands')]);
          final shells = FakeShells(fake)
            ..commands['git status --short'] = (
              output: ' M app/lib/run_text.dart\r\n',
              exit: 0,
            );
          addTearDown(shells.close);
          final d = await openApp(
            tester,
            fake,
            size: size,
            brightness: brightness,
          );
          final field = find.descendant(
            of: find.byType(Composer),
            matching: find.byType(TextField),
          );
          final name = 'box_${os}_${sizeName}_${brightness.name}';
          await tester.enterText(field, 'Also the README');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_ordinary');
          await tester.enterText(field, '!git log --oneline -5');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await render(tester, find.byType(NushiApp), '${name}_command');
          await tester.enterText(field, '!');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_empty');
          await tester.enterText(field, '!git status --short');
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await frames(tester, 10);
          await tester.enterText(field, '!npm test');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_card');
          d.daemonApi = commandTerminalApi - 1;
          await tester.enterText(field, '!ls');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_old');
          await closeView(tester, d);
          await tester.pump(const Duration(seconds: 2)); // a session's retry
        }, variant: onMac);
      }
    }
  }
}
