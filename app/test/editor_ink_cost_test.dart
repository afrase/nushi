import 'dart:convert';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' show EditableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/settings.dart' show wrapLines;
import 'package:nushi/transcript_find.dart' show FindBar;
import 'package:re_editor/re_editor.dart';

import 'big_sql.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// What the file editor's ink costs on a long line (issue 117): it draws
// code on the find's hits the editor paints (those in and around what's
// in sight), each line's worked out once while they're the same, and on
// the selected part, so a key or a step of the selection costs what's in
// sight, not the line; a window taken anew draws again, to compare, only
// the lines whose marks changed. Counted, not timed.

/// A dump whose longest lines are over a hundred kilobytes.
final String _dump = bigSql(400 << 10, rows: 600);

/// One of many lines of ten kilobytes and a few short ones between.
final String _rows = bigSql(1000 << 10, rows: 150);

/// The editor on [text], its find open on [query] and answered, the
/// caret in the longest of its first lines near its start: that line's
/// index.
Future<(Daemon, EditorFind, int)> _open(
  WidgetTester tester, {
  String? text,
  String query = 's',
}) async {
  final (d, _) = await openEditor(
    tester,
    {'dump.sql': utf8.encode(text ?? _dump)},
    open: const ['dump.sql'],
  );
  final e = editOf(d, 'dump.sql');
  final lines = e.controller.codeLines;
  var long = 0;
  for (var i = 0; i < 40 && i < lines.length; i++) {
    if (lines[i].length > lines[long].length) long = i;
  }
  expect(lines[long].length, greaterThan(text == null ? 100 << 10 : 2000));
  await tester.tap(find.byType(CodeEditor));
  await tester.pump();
  e.controller.selection = CodeLineSelection.collapsed(index: long, offset: 5);
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  final f = tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find;
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    query,
  );
  await untilReal(tester, () => !f.looking);
  await tester.pumpAndSettle();
  e.controller.selection = CodeLineSelection.collapsed(index: long, offset: 5);
  await tester.pumpAndSettle();
  return (d, f, long);
}

/// What each window taken anew costs: `EditorSight` is heard after the
/// ink, so each count is its cost at that retake. A line drawn again to
/// compare is a long one, whose part of the window moved, and nothing is
/// laid out again unless a line compared is drawn otherwise.
VoidCallback _expectRetakesCheap(EditorFind f, List<int> retakes) {
  var last = f.ink.cost;
  void heard() {
    final now = f.ink.cost;
    final long = f.sight.lines.value!.paragraphs.where((p) => p.length > 2000);
    final compared = now.compared - last.compared;
    expect(compared, lessThanOrEqualTo(long.length));
    if (now.forced > last.forced) expect(compared, greaterThan(0));
    retakes.add(compared);
    last = now;
  }

  f.sight.addListener(heard);
  return () => f.sight.removeListener(heard);
}

/// [tester]'s mouse wheel over the editor, 40 steps of 300 px down and
/// back up, a frame each.
Future<void> _wheel(WidgetTester tester) async {
  final mouse = TestPointer(7, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(
    mouse.hover(tester.getCenter(find.byType(CodeEditor))),
  );
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.sendEventToBinding(
      mouse.scroll(Offset(0, i < 20 ? 300 : -300)),
    );
    await tester.pump();
  }
}

/// The hits re_editor paints on line [index].
int _paintedOn(EditorFind f, int index) =>
    f.painted.where((m) => m.startIndex == index).length;

void main() {
  testWidgets('a key in a long line inks the hits in sight, not the '
      "line's, and forces no repaint, nor does the answer after it", (
    tester,
  ) async {
    final (d, f, long) = await _open(tester);
    final c = editOf(d, 'dump.sql').controller;
    final painted = _paintedOn(f, long);
    expect(painted, greaterThan(5));
    expect('s'.allMatches(c.codeLines[long].text).length, greaterThan(3000));
    f.ink.countAfresh();
    c.replaceSelection('x');
    await tester.pump();
    expect(f.ink.cost.hits, lessThanOrEqualTo(painted + 2));
    expect(f.ink.cost.lines, 1);
    expect(f.ink.cost.forced, 0);
    // re_editor's answer for the edited text moves nothing in sight that
    // draws otherwise: nothing is laid out again for it.
    expect(f.answered, isFalse);
    await untilReal(tester, () => f.answered);
    await tester.pump();
    expect(f.ink.cost.forced, 0);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("a step of the selection in a long line inks the line's part "
      'in sight, and forces no repaint', (tester) async {
    final (d, f, long) = await _open(tester);
    final c = editOf(d, 'dump.sql').controller;
    final painted = _paintedOn(f, long);
    for (var i = 0; i < 3; i++) {
      f.ink.countAfresh();
      c.selection = CodeLineSelection(
        baseIndex: long,
        baseOffset: 5,
        extentIndex: long,
        extentOffset: 6 + i,
      );
      await tester.pump();
      expect(f.ink.cost.lines, 1);
      expect(f.ink.cost.hits, lessThanOrEqualTo(painted + 2));
      expect(f.ink.cost.forced, 0);
      // The line's hits are as they were: none is worked out again.
      expect(f.ink.cost.worked, 0);
    }
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('with find closed, a key inks nothing and a step of the '
      'selection only its part, and neither forces a repaint', (tester) async {
    final (d, f, long) = await _open(tester);
    final c = editOf(d, 'dump.sql').controller;
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(f.query, isNull);
    c.selection = CodeLineSelection.collapsed(index: long, offset: 5);
    await tester.pump();
    f.ink.countAfresh();
    c.replaceSelection('x');
    await tester.pump();
    expect((f.ink.cost.lines, f.ink.cost.hits, f.ink.cost.forced), (0, 0, 0));
    c.selection = CodeLineSelection(
      baseIndex: long,
      baseOffset: 5,
      extentIndex: long,
      extentOffset: 8,
    );
    await tester.pump();
    expect((f.ink.cost.lines, f.ink.cost.hits, f.ink.cost.forced), (1, 0, 0));
    await endEditor(tester, d);
  }, variant: onMac);
  for (final wrap in [true, false]) {
    final how = wrap ? 'wrapped' : 'unwrapped';
    testWidgets('a wheel scroll over lines of ten kilobytes, $how, find '
        'open, draws only long lines again to compare, and lays out '
        'nothing for a line drawn as it was', (tester) async {
      wrapLines.value = wrap;
      final (d, f, _) = await _open(tester, text: _rows, query: 'e');
      f.ink.countAfresh();
      final retakes = <int>[];
      final stop = _expectRetakesCheap(f, retakes);
      await _wheel(tester);
      stop();
      expect(retakes.length, greaterThan(5));
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('with find closed, a wheel scroll over a selection, $how, '
        'draws nothing again to compare and lays nothing out for it', (
      tester,
    ) async {
      wrapLines.value = wrap;
      final (d, f, _) = await _open(tester, text: _rows, query: 'e');
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final c = editOf(d, 'dump.sql').controller;
      c.selection = CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: c.codeLines.length - 1,
        extentOffset: 0,
      );
      await tester.pumpAndSettle();
      f.ink.countAfresh();
      await _wheel(tester);
      expect(f.ink.cost.compared, 0);
      expect(f.ink.cost.forced, 0);
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets('keys typed while the view moves to the caret, unwrapped, '
      'find open, draw only long lines again to compare', (tester) async {
    wrapLines.value = false;
    final (d, f, long) = await _open(tester, text: _rows, query: 'e');
    final c = editOf(d, 'dump.sql').controller;
    // Out of sight, the caret's line is scrolled to as the keys come.
    final bar = tester.widget<EditorFindBar>(find.byType(EditorFindBar));
    bar.down.jumpTo(bar.down.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    c
      ..selection = CodeLineSelection.collapsed(index: long, offset: 5)
      ..makeCursorVisible();
    await tester.pump();
    f.ink.countAfresh();
    final retakes = <int>[];
    final stop = _expectRetakesCheap(f, retakes);
    for (var i = 0; i < 10; i++) {
      c.replaceSelection('x');
      await tester.pump();
    }
    stop();
    expect(retakes, isNotEmpty);
    await endEditor(tester, d);
  }, variant: onMac);
}
