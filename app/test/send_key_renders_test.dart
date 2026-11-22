import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The composer in the window with Settings › General's "Enter starts a
// new line" off and on (ADR 0147): idle with text (Send), busy with
// nothing written (the hint) and busy with text (Queue, Stop and send),
// wide and narrow, dark and light. Renders, looked
// at, never compared (NUSHI_RENDERS).

void main() {
  setUpAll(loadFonts);

  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 900), 'narrow'),
  ]) {
    for (final brightness in Brightness.values) {
      for (final on in [false, true]) {
        testWidgets('the composer, $sizeName, ${brightness.name}, Enter '
            'starts a new line ${on ? 'on' : 'off'}', (tester) async {
          enterStartsLine.value = on;
          viewport(tester, size, brightness: brightness);
          showDetails.value = false;
          final fake = FakeDaemon([chat('c', 'claude', 'Send keys')]);
          final d = await fake.connect(tester);
          d.select('c');
          await tester.pumpWidget(NushiApp(daemon: d));
          await tester.pumpAndSettle();
          final field = find.descendant(
            of: find.byType(Composer),
            matching: find.byType(TextField),
          );
          final name =
              'composer_${sizeName}_${brightness.name}${on ? '_lines' : ''}';
          await tester.enterText(field, 'Also the README');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_idle');
          d.chats['c']!
            ..busy = true
            ..started = clock()
            ..notifyListeners();
          await tester.enterText(field, '');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_busy_hint');
          await tester.enterText(field, 'Also the README');
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '${name}_busy');
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
