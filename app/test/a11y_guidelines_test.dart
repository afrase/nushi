import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Flutter's accessibility guidelines on the main screens: every control
// the pointer can press is labelled for VoiceOver; on the phone, each is a
// finger's 44 points.

void main() {
  setUpAll(loadFonts);

  testWidgets('the Mac’s window on a chat: every control labelled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    viewport(tester, const Size(1400, 900));
    final fake = FakeDaemon([
      chat('a', 'claude', 'Fix the login redirect'),
      chat('b', 'codex', 'Write the release notes'),
    ]);
    final d = await fake.connect(tester);
    d.select('a');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    // A sidebar row is a button, which the keyboard reaches and presses.
    final row = find
        .ancestor(
          of: find.text('Write the release notes'),
          matching: find.byType(Tap),
        )
        .first;
    expect(
      tester.getSemantics(row),
      isSemantics(isButton: true, isEnabled: true, isFocusable: true),
    );
    Focus.of(
      tester.element(
        find.descendant(of: row, matching: find.byType(PressWatch)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'b');
    await closeView(tester, d);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the phone’s chats: every control labelled and a finger’s '
      'size', (tester) async {
    final semantics = tester.ensureSemantics();
    viewport(tester, const Size(390, 844), ratio: 3);
    final phone = await startPhone(
      tester,
      FakeDaemon([
        chat('a', 'claude', 'Fix the login redirect'),
        chat('b', 'codex', 'Write the release notes'),
      ]),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await endPhone(tester, phone);
    semantics.dispose();
  });
}
