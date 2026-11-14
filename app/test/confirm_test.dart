import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/widgets.dart';

import 'harness.dart';

/// Opens `confirm` from a page and answers it with Enter: what it gave,
/// and the label of the button that had the focus.
Future<(bool?, String?)> _enter(
  WidgetTester tester, {
  required bool destructive,
}) async {
  bool? answer;
  await tester.pumpWidget(
    themed(
      Builder(
        builder: (context) => Center(
          child: Button(
            label: 'Open',
            onPressed: () async => answer = await confirm(
              context,
              'Delete “Tidy the note list”?',
              'Its transcript goes too.',
              'Delete',
              destructive: destructive,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  final focused = focusedButton(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  return (answer, focused);
}

void main() {
  testWidgets('a destructive confirm focuses Cancel: Enter never deletes', (
    tester,
  ) async {
    final (answer, focused) = await _enter(tester, destructive: true);
    expect(focused, 'Cancel');
    expect(answer, isFalse);
  });

  testWidgets('any other confirm focuses its action: Enter does it', (
    tester,
  ) async {
    final (answer, focused) = await _enter(tester, destructive: false);
    expect(focused, 'Delete');
    expect(answer, isTrue);
  });
}
