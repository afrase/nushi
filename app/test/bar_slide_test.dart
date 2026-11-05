import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/slides.dart';

import 'harness.dart';

// Bars that slide open and shut (BarSlide, on Presence): the fluidity
// review's idea 11.

/// A bar of 30 saying [text], or none, over a strip whose top says how
/// tall the bar is.
Widget _bar(String? text, {bool still = false}) => themed(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BarSlide(
        child: text == null
            ? null
            : SizedBox(
                height: 30,
                child: TextButton(onPressed: () {}, child: Text(text)),
              ),
      ),
      const SizedBox(key: ValueKey('below'), height: 10),
    ],
  ),
  still: still,
);

double _height(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('below'))).dy;

void main() {
  testWidgets('a bar opens down over Motion.standard and closes over '
      'Motion.exit, saying what it said until it is gone and taking no '
      'pointer meanwhile', (tester) async {
    await tester.pumpWidget(_bar(null));
    expect(_height(tester), 0);
    await tester.pumpWidget(_bar('Ready'));
    expect(_height(tester), 0);
    await tester.pump(Motion.standard ~/ 2);
    expect(_height(tester), inExclusiveRange(0, 30));
    await tester.pump(Motion.standard);
    expect(_height(tester), 30);

    await tester.pumpWidget(_bar(null));
    expect(find.text('Ready'), findsOneWidget);
    final ignoring = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.text('Ready'),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ignoring.any((w) => w.ignoring), isTrue);
    await tester.pump(Motion.exit ~/ 2);
    expect(_height(tester), inExclusiveRange(0, 30));
    expect(find.text('Ready'), findsOneWidget);
    await tester.pump(Motion.exit);
    expect(find.text('Ready'), findsNothing);
    expect(_height(tester), 0);
  });

  testWidgets('one that comes back as it goes opens from where it is', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(null));
    await tester.pumpWidget(_bar('Ready'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_bar(null));
    await tester.pump(Motion.exit ~/ 2);
    final mid = _height(tester);
    expect(mid, inExclusiveRange(0, 30));
    await tester.pumpWidget(_bar('Again'));
    expect(_height(tester), moreOrLessEquals(mid, epsilon: 0.5));
    expect(find.text('Again'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30));
    expect(_height(tester), greaterThan(mid));
    await tester.pumpAndSettle();
    expect(_height(tester), 30);
  });

  testWidgets('with Reduce Motion a bar is there and gone at once', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(null, still: true));
    await tester.pumpWidget(_bar('Ready', still: true));
    expect(_height(tester), 30);
    await tester.pumpWidget(_bar(null, still: true));
    expect(find.text('Ready'), findsNothing);
    expect(_height(tester), 0);
  });
}
