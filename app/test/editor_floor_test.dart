import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/editor_floor.dart';

import 'file_edit_helpers.dart';
import 'harness.dart';

// The file editor's scroll never goes above its start: below zero,
// re_editor's layout calls itself until the stack overflows, at every
// frame (the window froze and the text went undrawn). Without the floor
// the first pump here throws "Stack Overflow".
void main() {
  testWidgets('an offset below zero is refused, however it is asked: the '
      'editor lays out and keeps its text', (tester) async {
    final text = List.generate(48, (i) => 'ENV KEY_$i=value_$i').join('\n');
    final (d, _) = await openEditor(
      tester,
      {'notes.txt': utf8.encode(text)},
      open: const ['notes.txt'],
    );
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await tester.pump();
    final down = tester.widget<EditorFindBar>(find.byType(EditorFindBar)).down;
    final before = flooredAsks;
    down.jumpTo(-5);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(down.position.pixels, 0);
    down.position.correctBy(-9);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(down.position.pixels, 0);
    down.position.correctPixels(-3);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(down.position.pixels, 0);
    expect(flooredAsks - before, 3);
    expect(editOf(d, 'notes.txt').controller.codeLines.length, 48);
    await endEditor(tester, d);
  }, variant: onMac);
}
