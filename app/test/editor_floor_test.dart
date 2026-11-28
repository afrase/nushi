import 'dart:convert';

import 'package:flutter/material.dart' show EditableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/editor_floor.dart';
import 'package:nushi/settings.dart' show scrollPastEnd;
import 'package:nushi/transcript_find.dart' show FindBar;
import 'package:re_editor/re_editor.dart';

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

  // How it was met (the owner's report): with Scroll past end on, a short
  // file can scroll, and re_editor, bringing a find's match to the middle
  // of the view, jumps to a place above the file's start.
  testWidgets('a find in a short file with Scroll past end on: re_editor '
      'asks for an offset above the start, and the editor still lays out', (
    tester,
  ) async {
    scrollPastEnd.value = true;
    final text = [
      'FROM golang:1.25 AS build',
      'ARG VERSION=dev',
      for (var i = 0; i < 45; i++) 'ENV KEY_$i=value_$i',
      'CMD ["serve"]',
      '',
    ].join('\n');
    final (d, _) = await openEditor(
      tester,
      {'Dockerfile': utf8.encode(text)},
      open: const ['Dockerfile'],
    );
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    final bar = tester.widget<EditorFindBar>(find.byType(EditorFindBar));
    final field = find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    );
    final before = flooredAsks;
    for (final query in ['a', 'ar', 'arg']) {
      await tester.enterText(field, query);
      await untilReal(tester, () => !bar.find.looking);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: query);
      }
      expect(bar.down.position.pixels, greaterThanOrEqualTo(0));
    }
    // The floor was needed: without it this test is a stack overflow.
    expect(flooredAsks - before, greaterThan(0));
    await endEditor(tester, d);
  }, variant: onMac);
}
