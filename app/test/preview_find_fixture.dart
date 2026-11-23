/// What the preview's find tests share (issue 63): the bar, typing in it,
/// stepping, and the routing of ⌘F between a preview and the chat.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/main.dart';
import 'package:nushi/transcript_find.dart';

import 'file_edit_helpers.dart';
import 'harness.dart';

/// The find bar.
Finder get findBar => find.byType(FindBar);

/// The find bar in the Files pane.
Finder get paneBar =>
    find.descendant(of: find.byType(FilesPane), matching: findBar);

/// The bar's field.
Finder get findField =>
    find.descendant(of: findBar, matching: find.byType(EditableText));

/// The open bar's find.
Find barFind(WidgetTester tester) => tester.widget<FindBar>(findBar).find;

/// Types [q] in the bar, settled.
Future<void> look(WidgetTester tester, String q) async {
  await tester.enterText(findField, q);
  await tester.pumpAndSettle();
}

/// ⏎ in the bar, or ⇧⏎ with [back].
Future<void> stepFind(WidgetTester tester, {bool back = false}) async {
  if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

/// Whether [r] is inside the Files pane and not under the find bar.
bool inSight(WidgetTester tester, Rect r) {
  final pane = tester.getRect(find.byType(FilesPane));
  final bar = findBar.evaluate().isEmpty ? null : tester.getRect(findBar);
  return r.top >= pane.top &&
      r.bottom <= pane.bottom &&
      r.left >= pane.left &&
      r.right <= pane.right &&
      (bar == null || !bar.overlaps(r));
}

/// ⌘F with the preview focused (by a tap on [inPreview]) opens the file's
/// bar, not the chat's; Esc closes it and the focus is the preview's
/// again; with the prompt box focused, ⌘F is the chat's.
Future<void> expectRouting(
  WidgetTester tester,
  Daemon d,
  Finder inPreview,
) async {
  await tester.tap(inPreview);
  await tester.pumpAndSettle();
  final before = FocusManager.instance.primaryFocus;
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  expect(paneBar, findsOne);
  expect(find.text('Find in the file'), findsOne);
  expect(chatC(d).find.query, isNull);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'find');
  // ⌘F again, from the bar, stays there.
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  expect(paneBar, findsOne);
  expect(chatC(d).find.query, isNull);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(findBar, findsNothing);
  expect(FocusManager.instance.primaryFocus, before);
  // The prompt box: the chat's find; the file's stays shut.
  await tester.tap(
    find.descendant(
      of: find.byType(Composer),
      matching: find.byType(EditableText),
    ),
  );
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  expect(chatC(d).find.query, '');
  expect(find.text('Find in the chat'), findsOne);
  expect(paneBar, findsNothing);
  // Back in the preview, its own again, the chat's left as it was.
  chatC(d).find.close();
  await tester.pumpAndSettle();
  await tester.tap(inPreview);
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  expect(paneBar, findsOne);
  expect(chatC(d).find.query, isNull);
}

/// Renders the window, [name] in light and dark at 1700 and 720 wide, by
/// [build] (which opens the bar with matches) each time.
Future<void> renderFind(
  WidgetTester tester,
  String name,
  Future<Daemon> Function(double width, Brightness b) build,
) async {
  for (final b in Brightness.values) {
    for (final w in [1700.0, 720.0]) {
      final d = await build(w, b);
      await render(
        tester,
        find.byType(NushiApp),
        '$name-${w.toInt()}-${b.name}',
      );
      await endEditor(tester, d);
    }
  }
}
