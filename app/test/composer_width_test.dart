import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_plus.dart' show plusTooltip;

import 'fake_daemon.dart';
import 'harness.dart';

// Deep review 2026-11-13, finding 4: the box's text field moves into its
// row and out as the box crosses Composer.pickersFrom; made again there,
// it kept focus but lost its connection to the text input, and typed keys
// went nowhere until the box was clicked.

void main() {
  setUpAll(loadFonts);

  for (final (from, to) in [(640.0, 380.0), (380.0, 640.0)]) {
    testWidgets('typing goes on as the box goes from $from to $to wide', (
      tester,
    ) async {
      final d = await FakeDaemon([]).connect(tester);
      final chat = ChatState('c', '/Users/me/nushi')
        ..agent = 'claude'
        ..loaded = true;
      d.chats['c'] = chat;
      final width = ValueNotifier(from);
      addTearDown(width.dispose);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder(
              valueListenable: width,
              builder: (context, w, _) => SizedBox(
                width: w,
                child: Composer(chat: chat, daemon: d),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.enterText('half a sente');
      await tester.pump();
      final state = tester.state(find.byType(EditableText));
      final roomyBefore = _roomy(tester);

      width.value = to;
      await tester.pump();
      expect(_roomy(tester), isNot(roomyBefore), reason: 'it crossed 400');
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('half a sentence');
      await tester.pump();
      expect(chat.draft.text.text, 'half a sentence');
      d.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}

/// Whether the box is laid out roomy: its text above the row of the +
/// and send, rather than between them.
bool _roomy(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(TextField)).dy <=
    tester.getTopLeft(find.byTooltip(plusTooltip)).dy;
