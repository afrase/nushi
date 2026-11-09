import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/window_drag_linux.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// ⌘F in the preview's editor (ADR 0096): it finds in the file while the
// focus is in it, the chat's find otherwise; ⏎ and ⇧⏎ step, Esc closes, and
// nothing typed in the bar edits the file or saves it.

/// A file with "print" five times, the first on its first line.
const _source =
    'package main // print, print\n'
    '\n'
    'func main() {\n'
    '\tprintln("hi")\n'
    '\tPrintln("there")\n'
    '\tfmt.Print(1)\n'
    '}\n';

Finder get _bar => find.byType(FindBar);

Finder get _field =>
    find.descendant(of: _bar, matching: find.byType(EditableText));

EditorFind _findOf(WidgetTester tester) =>
    tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find;

/// The editor focused, the caret at its start, then ⌘F.
Future<void> _openFind(WidgetTester tester, Daemon d) async {
  await tester.tap(find.byType(CodeEditor));
  await tester.pump();
  editOf(d).controller.selection = const CodeLineSelection.collapsed(
    index: 0,
    offset: 0,
  );
  await cmd(tester, LogicalKeyboardKey.keyF);
}

/// Types [q] in the bar and waits for re_editor's isolate to find it.
Future<void> _look(WidgetTester tester, String q, String count) async {
  await tester.enterText(_field, q);
  await untilReal(tester, () => find.text(count).evaluate().isNotEmpty);
  await tester.pumpAndSettle();
}

/// The editor's selection, as (line, start, end).
(int, int, int) _selected(Daemon d) {
  final s = editOf(d).controller.selection;
  return (s.startIndex, s.startOffset, s.endOffset);
}

Future<void> _shiftEnter(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the editor finds in the file; in the prompt box, the '
      'chat', (tester) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await _openFind(tester, d);
    expect(_bar, findsOne);
    expect(find.text('Find in the file'), findsOne);
    expect(
      find.descendant(of: find.byType(PreviewPane), matching: _bar),
      findsOne,
    );
    expect(chatC(d).find.query, isNull);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'find');
    // ⌘F again, from the bar, stays there.
    await cmd(tester, LogicalKeyboardKey.keyF);
    expect(_bar, findsOne);
    expect(chatC(d).find.query, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    // The prompt box: the chat's find, the file's stays shut.
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    await cmd(tester, LogicalKeyboardKey.keyF);
    expect(chatC(d).find.query, '');
    expect(find.text('Find in the chat'), findsOne);
    expect(find.text('Find in the file'), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('the count, ⏎ and ⇧⏎ through the matches (case aside) as the '
      'selection, round; Esc leaves the last selected', (tester) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await _openFind(tester, d);
    await _look(tester, 'print', '1 of 5');
    final f = _findOf(tester);
    expect(f.hits, ['0:16', '0:23', '3:1', '4:1', '5:5']);
    expect(_selected(d), (0, 16, 21));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of 5'), findsOne);
    expect(_selected(d), (0, 23, 28));
    await _shiftEnter(tester);
    await _shiftEnter(tester);
    expect(find.text('5 of 5'), findsOne);
    expect(_selected(d), (5, 5, 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1 of 5'), findsOne);
    // The selected match isn't tinted with the others.
    final marking = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(marking.findController!.allMatchSelections, hasLength(4));
    await _look(tester, 'nowhere', 'None');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
    expect(_selected(d), (0, 16, 21));
    expect(marking.findController!.value, isNull);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('typing in the bar neither edits the file nor saves it; the '
      'editor edits as before once it closes', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(_source),
    });
    final e = editOf(d);
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 0,
    );
    await typeIn(tester, e, '// ');
    expect(e.unsaved, isTrue);
    await cmd(tester, LogicalKeyboardKey.keyF);
    await _look(tester, 'main', '1 of 2');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(e.text, '// $_source');
    expect(fake.writes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(fake.writes, isEmpty);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 0,
    );
    await typeIn(tester, e, 'x');
    expect(e.text, 'x// $_source');
    // The prompt box still saves.
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(utf8.decode(fake.writes.single.data), 'x// $_source');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("× with the focus in the prompt box: the editor doesn't take "
      "it, and what is typed next doesn't edit the file", (tester) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await _openFind(tester, d);
    await _look(tester, 'print', '1 of 5');
    final prompt = find.byType(EditableText).first;
    await tester.tap(prompt);
    await tester.pumpAndSettle();
    await tester.enterText(prompt, 'half a prompt');
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot(anyOf('editor', 'find')),
    );
    // The click unfocuses the prompt box (a text field's tap outside, as on
    // any button) before × closes the bar.
    await tester.tap(
      find.descendant(of: _bar, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('editor'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();
    expect(editOf(d).text, _source);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('typed fast, the count never says "None" for a text with '
      'matches while re_editor looks', (tester) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await _openFind(tester, d);
    final f = _findOf(tester);
    final counts = <String>[];
    f.addListener(() => counts.add(f.count));
    // As the bar's field does, with no frame between the keys.
    for (final q in ['p', 'pr', 'pri', 'prin', 'print']) {
      f.query = q;
    }
    expect(f.looking, isTrue);
    expect(f.count, '');
    await untilReal(tester, () => !f.looking && f.hits.isNotEmpty);
    await tester.pumpAndSettle();
    expect(counts, isNot(contains('None')));
    expect(counts.last, '1 of 5');
    expect(f.hits, ['0:16', '0:23', '3:1', '4:1', '5:5']);
    // Then one with none: "None", once it's looked.
    await _look(tester, 'nowhere', 'None');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('an edit while the bar is open is found again', (tester) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await _openFind(tester, d);
    await _look(tester, 'println', '1 of 2');
    final e = editOf(d)
      ..controller.selection = const CodeLineSelection.collapsed(
        index: 6,
        offset: 1,
      );
    await typeIn(tester, e, '\nprintln()');
    await untilReal(tester, () => _findOf(tester).hits.length == 3);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('Control+F on Linux', (tester) async {
    native
      ..conventions = linuxConventions
      ..window = const LinuxWindow();
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(_source)});
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Find in the file'), findsOne);
    expect(chatC(d).find.query, isNull);
    await endEditor(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a match under the bar at the top: the text starts below it', (
    tester,
  ) async {
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('${'x' * 120} needle\n$_source'),
    }, width: 1100);
    await _openFind(tester, d);
    await _look(tester, 'needle', '1 of 1');
    final f = _findOf(tester);
    expect(f.roomAbove.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(f.roomAbove.value, isFalse);
    await endEditor(tester, d);
  }, variant: onMac);

  for (final brightness in Brightness.values) {
    testWidgets('the bar over the file (${brightness.name})', (tester) async {
      final (d, _) = await openEditor(tester, {
        'main.go': utf8.encode(_source),
      }, brightness: brightness);
      await _openFind(tester, d);
      await _look(tester, 'print', '1 of 5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await untilReal(tester, () => editOf(d).highlighted);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PreviewPane),
        matchesGoldenFile('goldens/editor_find_${brightness.name}.png'),
      );
      // The window, wide and narrow, to look at.
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 900), brightness: brightness);
        await tester.pumpAndSettle();
        final bar = tester.getRect(_bar);
        final pane = tester.getRect(find.byType(PreviewPane));
        expect(bar.right, lessThanOrEqualTo(pane.right));
        expect(bar.left, greaterThanOrEqualTo(pane.left));
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'editor_find_${width.toInt()}_${brightness.name}',
        );
      }
      await endEditor(tester, d);
    }, variant: onMac);
  }
}
