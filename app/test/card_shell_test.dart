import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/controls.dart';

import 'harness.dart';

// A card of the GitHub inbox's or Jira's task list (CardShell): its title
// drags it and the grip says so, the pointer anywhere on it, as the
// details panel's widgets do (panel_widget_test.dart): both through the
// one DragTitle.

Widget _cards({bool open = true}) => themed(
  SizedBox(
    width: 360,
    height: 400,
    child: CardList(
      onReorder: (_, _) {},
      children: [
        for (final (i, name) in ['Review', 'Mine'].indexed)
          CardShell(
            key: ValueKey(name),
            index: i,
            open: open,
            onToggle: () {},
            title: Text(name),
            trailing: const Text('3'),
            body: Text('$name body'),
          ),
      ],
    ),
  ),
);

Future<TestGesture> _pointer(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

void main() {
  testWidgets('the pointer anywhere on a card shows its grip; its title '
      'shows the open hand, and the closed one while dragged', (tester) async {
    await tester.pumpWidget(_cards());
    expect(find.byType(DragGrip), findsNothing, reason: 'plain at rest');
    final mouse = await _pointer(tester);

    await mouse.moveTo(tester.getCenter(find.text('Review body')));
    await tester.pumpAndSettle();
    expect(find.byType(DragGrip), findsOneWidget, reason: 'on its body');
    expect(_cursor(), isNot(SystemMouseCursors.grab));

    await mouse.moveTo(tester.getCenter(find.text('Review')));
    await tester.pumpAndSettle();
    expect(find.byType(DragGrip), findsOneWidget);
    expect(_cursor(), SystemMouseCursors.grab);

    await mouse.down(tester.getCenter(find.text('Review')));
    await tester.pump(kLongPressTimeout);
    await mouse.moveBy(const Offset(0, 30));
    await tester.pump();
    await mouse.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.grabbing);
    expect(find.byType(DragGrip), findsWidgets, reason: 'dragged');
    await mouse.up();
    await tester.pumpAndSettle();

    await mouse.moveTo(const Offset(1, 390));
    await tester.pumpAndSettle();
    expect(find.byType(DragGrip), findsNothing, reason: 'plain again');
  });

  testWidgets("folded, the grip takes its summary's place", (tester) async {
    await tester.pumpWidget(_cards(open: false));
    final summary = tester.getRect(find.text('3').first);
    final mouse = await _pointer(tester);
    await mouse.moveTo(tester.getCenter(find.text('Review')));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget, reason: "the other card's");
    final grip = tester.getRect(find.byType(DragGrip));
    expect(grip.right, moreOrLessEquals(summary.right, epsilon: 1));
  });
}
