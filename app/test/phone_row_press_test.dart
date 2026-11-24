// The phone's rows press as its buttons do (docs/design.md: every press
// control shows a press at once): a finger down on a chat in the list
// tints it before the chat's screen slides in, and lifting it opens the
// chat.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/phone/artifacts_screen.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The fill the press path draws on the row holding [text].
Color? _fill(WidgetTester tester, String text) {
  final box = find.descendant(
    of: find.ancestor(of: find.text(text), matching: find.byType(Tap)).first,
    matching: find.byType(Container),
  );
  final deco = tester.widget<Container>(box.first).decoration;
  return (deco! as BoxDecoration).color;
}

void main() {
  setUpAll(loadFonts);

  for (final size in const [Size(390, 844), Size(430, 932), Size(844, 390)]) {
    for (final b in renderThemes) {
      final name = '${size.width.toInt()}x${size.height.toInt()}_${b.name}';
      testWidgets('a finger on a chat row tints it at once, $name', (
        tester,
      ) async {
        viewport(tester, size, ratio: 2, brightness: b);
        final phone = await startPhone(
          tester,
          FakeDaemon([
            chat('a', 'claude', 'Fix the login redirect'),
            chat('b', 'codex', 'Write the release notes'),
          ]),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChatRow), findsNWidgets(2));
        final t = NushiTheme.of(tester.element(find.byType(ChatRow).first)).t;
        expect(_fill(tester, 'Write the release notes'), isNull);
        // A finger (startGesture's pointer is a touch).
        final finger = await tester.startGesture(
          tester.getCenter(find.text('Write the release notes')),
        );
        await tester.pump();
        expect(_fill(tester, 'Write the release notes'), t.pressed);
        expect(_fill(tester, 'Fix the login redirect'), isNull);
        await render(tester, find.byType(PhoneApp), 'phone_row_press_$name');
        await finger.up();
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsOne);
        await endPhone(tester, phone);
      });
    }
  }

  testWidgets('the bar’s Artifacts chip presses as a 44-high pill, not '
      'the bar’s whole height', (tester) async {
    await tester.pumpWidget(
      themed(
        TouchTargets(
          child: SizedBox(
            height: 52, // the phone's bar
            child: Row(children: [ArtifactsAction(3, onTap: () {})]),
          ),
        ),
      ),
    );
    final tap = find.descendant(
      of: find.byType(ArtifactsAction),
      matching: find.byType(Tap),
    );
    expect(tester.getSize(tap).height, touch);
  });
}
