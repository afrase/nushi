import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('the arrow keys move the caret when renaming from the sidebar', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 900));
    showDetails.value = false;
    final c = chat('c', 'claude', 'Pick me');
    final fake = FakeDaemon([c])
      ..answer = (input) =>
          input is GetChatRequest ? GetChatResponse(chat: c) : null;
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.text('Pick me').first),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    final text = tester
        .widget<TextField>(
          find.descendant(
            of: find.byType(RenameField),
            matching: find.byType(TextField),
          ),
        )
        .controller!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(text.selection, const TextSelection.collapsed(offset: 7));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(text.selection.baseOffset, 5);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(text.selection.isCollapsed, isFalse);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
