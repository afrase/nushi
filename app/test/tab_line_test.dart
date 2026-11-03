import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/theme/theme.dart';

// The tabs' line slides to the tab picked (TabLine): the fluidity review's
// idea 12.

Widget _tabs(int value, ValueChanged<int> onChanged, {bool still = false}) =>
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PlainTabs<int>(
              value: value,
              tabs: const [(0, 'Chat'), (1, 'Changes'), (2, 'Pull request')],
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );

/// The tabs' 2 px lines, as drawn.
List<Rect> _lines(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(PlainTabs<int>),
            matching: find.byType(ColoredBox),
          )
          .evaluate())
    if (tester.getSize(find.byWidget(e.widget)).height == 2)
      tester.getRect(find.byWidget(e.widget)),
];

void main() {
  testWidgets('the line slides from the tab that showed to the one picked; '
      'at rest it is the tab’s own', (tester) async {
    var value = 0;
    Future<void> pick(int v) async {
      value = v;
      await tester.pumpWidget(_tabs(value, (_) {}));
    }

    await tester.pumpWidget(_tabs(value, (_) {}));
    final rest = _lines(tester);
    expect(rest, hasLength(1));
    final chat = tester.getRect(find.text('Chat'));
    final changes = tester.getRect(find.text('Changes'));
    expect(rest.single.center.dx, moreOrLessEquals(chat.center.dx, epsilon: 1));

    await pick(1);
    expect(_lines(tester).single, rest.single); // where it was
    await tester.pump(Motion.standard ~/ 3);
    final mid = _lines(tester).single;
    expect(mid.center.dx, inExclusiveRange(chat.center.dx, changes.center.dx));
    await tester.pumpAndSettle();
    final there = _lines(tester).single;
    expect(there.center.dx, moreOrLessEquals(changes.center.dx, epsilon: 1));

    // Picked again mid-slide: from where it is.
    await pick(2);
    await tester.pump(Motion.standard ~/ 3);
    final going = _lines(tester).single;
    await pick(0);
    expect(
      _lines(tester).single.left,
      moreOrLessEquals(going.left, epsilon: 1),
    );
    await tester.pumpAndSettle();
    expect(
      _lines(tester).single.center.dx,
      moreOrLessEquals(chat.center.dx, epsilon: 1),
    );
  });

  testWidgets('a tab takes a click mid-slide', (tester) async {
    var value = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) => _tabs(value, (v) => set(() => value = v)),
      ),
    );
    await tester.tap(find.text('Pull request'));
    await tester.pump(Motion.standard ~/ 4);
    await tester.tap(find.text('Changes'));
    expect(value, 1);
    await tester.pumpAndSettle();
    expect(
      _lines(tester).single.center.dx,
      moreOrLessEquals(tester.getCenter(find.text('Changes')).dx, epsilon: 1),
    );
  });

  testWidgets('with Reduce Motion the line jumps', (tester) async {
    await tester.pumpWidget(_tabs(0, (_) {}, still: true));
    await tester.pumpWidget(_tabs(2, (_) {}, still: true));
    expect(
      _lines(tester).single.center.dx,
      moreOrLessEquals(
        tester.getCenter(find.text('Pull request')).dx,
        epsilon: 1,
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
