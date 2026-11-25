import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/theme/tokens.dart';

import 'diff_select.dart';
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// Selecting text in a diff's code with the mouse and copying it with the
// app's copy key (diff_view 0.3.0), in a diff on its own: the gutter
// still selects lines for a comment, and a comment box keeps its keys.

Widget _box({bool review = false, Tokens tokens = Tokens.dark}) => themed(
  DiffBox(
    totalChange,
    fit: false,
    review: review ? (chat: 'c', where: 'uncommitted', agent: 'Claude') : null,
  ),
  tokens: tokens,
);

void main() {
  setUpAll(loadFonts);

  for (final unified in [false, true]) {
    final view = unified ? 'unified' : 'side by side';
    testWidgets('$view: a drag across the code, then the copy key, copies '
        'exactly what it covers', (tester) async {
      viewport(tester, Size(unified ? 500 : 1000, 400));
      platformKeys();
      final copied = clipboardCopies(tester);
      await tester.pumpWidget(_box(review: true));
      await tester.pump();
      await dragCode(tester, from: (1, 2), to: (2, 9));
      expect(find.byType(ReviewCommentBox), findsNothing);
      await press(tester, LogicalKeyboardKey.keyC, cmd: true);
      expect(copied, ['sum := start\n  for _, ']);
    }, variant: macAndLinux);
  }

  testWidgets('a double click copies the word', (tester) async {
    viewport(tester, const Size(1000, 400));
    platformKeys();
    final copied = clipboardCopies(tester);
    await tester.pumpWidget(_box());
    await tester.pump();
    await doubleClickCode(tester, 1, 10);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['start']);
  }, variant: macAndLinux);

  testWidgets('a click in the code starts no comment and selects nothing', (
    tester,
  ) async {
    viewport(tester, const Size(1000, 400));
    await tester.pumpWidget(_box(review: true));
    await tester.pump();
    await clickCode(tester, 1, 4);
    expect(find.byType(ReviewCommentBox), findsNothing);
    expect(diffController(tester).textSelection.value, isNull);
  });

  testWidgets('a drag on the line numbers still opens the comment box', (
    tester,
  ) async {
    viewport(tester, const Size(1000, 400));
    await tester.pumpWidget(_box(review: true));
    await tester.pump();
    await dragGutter(tester, 1, 2);
    expect(find.text('Lines 2–3'), findsOneWidget);
    expect(diffController(tester).textSelection.value, isNull);
  });

  testWidgets('with code selected, the comment box keeps its own copy and '
      'Escape while it has the focus', (tester) async {
    viewport(tester, const Size(1000, 400));
    platformKeys();
    final copied = clipboardCopies(tester);
    await tester.pumpWidget(_box(review: true));
    await tester.pump();
    await dragGutter(tester, 3, 3);
    await dragCode(tester, from: (0, 5), to: (0, 10));
    expect(diffController(tester).textSelection.value, isNotNull);
    final field = find.descendant(
      of: find.byType(ReviewCommentBox),
      matching: find.byType(EditableText),
    );
    await tester.tap(field);
    await tester.enterText(field, 'rename it');
    tester.widget<EditableText>(field).controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['rename']);
    await press(tester, LogicalKeyboardKey.escape);
    // The box's Escape dropped the comment, not the code's selection.
    expect(find.byType(ReviewCommentBox), findsNothing);
    expect(diffController(tester).textSelection.value, isNotNull);
  }, variant: macAndLinux);

  testWidgets('the copy key with nothing selected is left to the app', (
    tester,
  ) async {
    viewport(tester, const Size(1000, 400));
    platformKeys();
    final copied = clipboardCopies(tester);
    var heard = 0;
    await tester.pumpWidget(
      Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.keyC) {
            heard++;
          }
          return KeyEventResult.ignored;
        },
        child: _box(),
      ),
    );
    await tester.pump();
    await clickCode(tester, 1, 4);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(heard, 1);
    expect(copied, isEmpty);
  }, variant: macAndLinux);

  testWidgets("a right-click on selected code opens the app's menu, whose "
      'Copy copies it', (tester) async {
    viewport(tester, const Size(1000, 400));
    final copied = clipboardCopies(tester);
    await tester.pumpWidget(_box(review: true));
    await tester.pump();
    await dragCode(tester, from: (1, 2), to: (1, 5));
    final at = codeAt(tester, 1, 3);
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await mouse.addPointer(location: at);
    addTearDown(mouse.removePointer);
    await mouse.down(at);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    // The selection stays, and no comment opened.
    expect(diffController(tester).textSelection.value, isNotNull);
    expect(find.byType(ReviewCommentBox), findsNothing);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, ['sum']);
  });

  testWidgets('a drag of the scrollbar selects no text', (tester) async {
    viewport(tester, const Size(600, 400));
    String text(String s) => [for (var i = 0; i < 400; i++) '$s $i'].join('\n');
    await tester.pumpWidget(
      themed(
        DiffBox(
          FileChange(path: 'a.txt', oldText: text('a'), newText: text('b')),
          fit: false,
        ),
      ),
    );
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 200));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(594, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await mouse.down(const Offset(594, 10));
    await tester.pump();
    await mouse.moveBy(const Offset(0, 150));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    final c = diffController(tester);
    expect(c.scroll(PaneSide.neu).offset, greaterThan(1000));
    expect(c.textSelection.value, isNull);
  }, variant: onMac);
}
