// The phone's rows press as its buttons do (docs/design.md: every press
// control shows a press at once): a finger held on a chat in the list
// tints it before the chat's screen slides in, and lifting it opens the
// chat. In a list that scrolls, a finger's tint waits a moment
// (Waits.pressInScroll), so a touch that turns into a scroll tints
// nothing, and a quick tap still shows its press as it lifts.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/artifacts_screen.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone.dart';
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
        // A finger (startGesture's pointer is a touch), held.
        final finger = await tester.startGesture(
          tester.getCenter(find.text('Write the release notes')),
        );
        await tester.pump();
        await tester.pump(Waits.pressInScroll);
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

  /// A phone on a list of chats long enough to scroll.
  Future<Phone> longList(WidgetTester tester) async {
    viewport(tester, const Size(390, 844), ratio: 2);
    final phone = await startPhone(
      tester,
      FakeDaemon([
        for (var i = 0; i < 30; i++) chat('c$i', 'claude', 'Chat number $i'),
      ]),
    );
    await tester.pumpAndSettle();
    return phone;
  }

  testWidgets('a finger that scrolls the chat list tints no row, on any '
      'frame', (tester) async {
    final phone = await longList(tester);
    final rows = find.byType(ChatRow);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('Chat number 3')),
    );
    Iterable<Color?> fills() => [
      for (final e in rows.evaluate())
        _fill(tester, (e.widget as ChatRow).chat.shownTitle),
    ];
    await tester.pump();
    expect(fills().whereType<Color>(), isEmpty, reason: 'down');
    for (var i = 0; i < 8; i++) {
      await finger.moveBy(const Offset(0, -8));
      await tester.pump(const Duration(milliseconds: 8));
      expect(fills().whereType<Color>(), isEmpty, reason: 'move $i');
    }
    await finger.up();
    await tester.pump();
    expect(fills().whereType<Color>(), isEmpty, reason: 'lifted');
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    await endPhone(tester, phone);
  });

  testWidgets('a quick tap on a chat row still shows its press as it '
      'lifts, then opens the chat', (tester) async {
    final phone = await longList(tester);
    final t = NushiTheme.of(tester.element(find.byType(ChatRow).first)).t;
    final finger = await tester.startGesture(
      tester.getCenter(find.text('Chat number 3')),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_fill(tester, 'Chat number 3'), isNull);
    await finger.up();
    await tester.pump();
    expect(_fill(tester, 'Chat number 3'), t.pressed);
    await render(tester, find.byType(PhoneApp), 'phone_row_quick_tap');
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOne);
    await endPhone(tester, phone);
  });

  testWidgets('a mouse press in a list tints its row at once, as before', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        ListView(
          children: [
            for (var i = 0; i < 3; i++)
              Tap(onTap: () {}, child: Text('Row $i')),
          ],
        ),
      ),
    );
    final t = NushiTheme.of(tester.element(find.text('Row 1'))).t;
    final mouse = await tester.startGesture(
      tester.getCenter(find.text('Row 1')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(_fill(tester, 'Row 1'), t.pressed);
    await mouse.up();
  });
}
