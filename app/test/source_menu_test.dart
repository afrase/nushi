import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart' show wrapLines;
import 'package:nushi/source_view.dart';
import 'package:nushi/transcript_find.dart' show FindBar;
import 'package:re_editor/re_editor.dart';

import 'fake_desktop.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// The right-click menu in a file's source in the Files pane (issue 75):
// in the editor and in a read-only source, each row doing its job.

/// Lines ending both in CRLF and LF: shown read-only.
final List<int> _mixed = utf8.encode('package main\r\n\nfunc main() {\n}\n');

/// The clipboard as the app sees it: what it was given, in order; a
/// paste reads [pasted].
List<String> _clipboard(WidgetTester tester, {String pasted = ''}) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => switch (call.method) {
      'Clipboard.setData' => () {
        copied.add((call.arguments as Map)['text'] as String);
      }(),
      'Clipboard.getData' => {'text': pasted},
      _ => null,
    },
  );
  return copied;
}

/// The menu's row [label].
Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

/// Whether row [label] can be picked.
bool _on(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(_row(label)).onPressed != null;

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  await tester.tapAt(
    at,
    buttons: kSecondaryButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(_row(label));
  await tester.pumpAndSettle();
}

/// The editor on main.go, lines 6 to 8 selected (to `label`).
Future<Daemon> _editing(WidgetTester tester) async {
  final (d, _) = await openEditor(tester, {'main.go': utf8.encode(tabbed)});
  editOf(d).controller.selection = const CodeLineSelection(
    baseIndex: 5,
    baseOffset: 0,
    extentIndex: 7,
    extentOffset: 6,
  );
  await tester.pumpAndSettle();
  return d;
}

/// A point inside the editor, over its text.
Offset _inEditor(WidgetTester tester) =>
    tester.getRect(find.byType(CodeEditor)).topLeft + const Offset(160, 140);

const _selected = 'type point struct {\n\tx, y\tint    // across\n\tlabel';

void main() {
  testWidgets('in the editor: Copy copies the selection, which stays, and '
      'Copy path gives its first line', (tester) async {
    final copied = _clipboard(tester);
    final d = await _editing(tester);
    final before = editOf(d).controller.selection;
    await _rightClick(tester, _inEditor(tester));
    expect(editOf(d).controller.selection, before);
    for (final label in ['Cut', 'Copy', 'Paste', 'Copy path', 'Find…']) {
      expect(_on(tester, label), isTrue, reason: label);
    }
    await _pick(tester, 'Copy');
    expect(copied, [_selected]);
    expect(_row('Copy'), findsNothing);
    expect(editOf(d).controller.selection, before);

    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Copy path');
    expect(copied.last, 'main.go:6');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('in the editor with nothing selected: Copy, Cut and Quote '
      'in reply are off; Copy path gives the line clicked', (tester) async {
    final copied = _clipboard(tester);
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(tabbed)});
    final editor = tester.getRect(find.byType(CodeEditor));
    // The first line, at the editor's top inset.
    await _rightClick(tester, editor.topLeft + const Offset(160, 28));
    expect(_on(tester, 'Copy'), isFalse);
    expect(_on(tester, 'Cut'), isFalse);
    expect(_on(tester, 'Quote in reply'), isFalse);
    await _pick(tester, 'Copy path');
    expect(copied, ['main.go:1']);
    // Past the last line: the last.
    await _rightClick(tester, editor.bottomLeft + const Offset(160, -20));
    await _pick(tester, 'Copy path');
    expect(copied.last, 'main.go:17');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('Quote in reply puts the lines in the box as a reply card', (
    tester,
  ) async {
    final d = await _editing(tester);
    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Quote in reply');
    final cards = chatC(d).draft.replies.value;
    expect(cards, hasLength(1));
    expect(cards.single.quote, '`main.go`, lines 6–8:\n```go\n$_selected\n```');
    expect(cards.single.text, isEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('Show in Finder and Open in your editor ask the file manager', (
    tester,
  ) async {
    final d = await _editing(tester);
    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Show in Finder');
    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Open in your editor');
    expect(fakeDesktop(), [
      ['-R', '/Users/me/nushi/main.go'],
      ['-t', '/Users/me/nushi/main.go'],
    ]);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("Cut and Paste edit; Find opens the editor's find", (
    tester,
  ) async {
    final copied = _clipboard(tester, pasted: 'X');
    final d = await _editing(tester);
    final e = editOf(d);
    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Cut');
    expect(copied, [_selected]);
    expect(e.text, isNot(contains('type point')));
    expect(e.unsaved, isTrue);

    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Paste');
    expect(e.text, contains('X'));

    expect(find.byType(FindBar), findsNothing);
    await _rightClick(tester, _inEditor(tester));
    await _pick(tester, 'Find…');
    expect(find.byType(FindBar), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('with the menu open the editor keeps the focus and ⌘C; Esc '
      'closes it', (tester) async {
    final copied = _clipboard(tester);
    final d = await _editing(tester);
    await _rightClick(tester, _inEditor(tester));
    expect(_row('Copy'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, [_selected]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_row('Copy'), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('in a read-only source: the selection stays, Copy and Quote '
      'in reply take it; Find, but no Cut or Paste', (tester) async {
    final copied = _clipboard(tester);
    final (d, _) = await openEditor(
      tester,
      {'mixed.go': _mixed},
      open: const ['mixed.go'],
    );
    expect(find.byType(SourceView), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);
    Finder line(String text) => find.text(text, findRichText: true);

    // Nothing selected: the line clicked.
    await _rightClick(tester, tester.getCenter(line('func main() {')));
    // Find is the source's own (issue 63); Cut and Paste the editor's.
    expect(find.text('Find…'), findsOneWidget);
    for (final label in ['Cut', 'Paste']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(_on(tester, 'Copy'), isFalse);
    expect(_on(tester, 'Quote in reply'), isFalse);
    await _pick(tester, 'Copy path');
    expect(copied, ['mixed.go:3']);

    // Lines 3 (from its second letter) and 4 selected by a drag; a
    // right-click on line 1.
    final mouse = await tester.startGesture(
      // Inside `func`: a press at a line's very start can take the line
      // before's end.
      Offset(
        tester.getTopLeft(line('func main() {')).dx + 12,
        tester.getCenter(line('func main() {')).dy,
      ),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(tester.getBottomRight(line('}')) + const Offset(0, -4));
    await mouse.up();
    await tester.pumpAndSettle();
    await _rightClick(
      tester,
      tester.getCenter(find.textContaining('package main', findRichText: true)),
    );
    expect(_on(tester, 'Copy'), isTrue);
    await _pick(tester, 'Copy');
    expect(copied.last, 'unc main() {\n}\n');
    await _rightClick(
      tester,
      tester.getCenter(find.textContaining('package main', findRichText: true)),
    );
    await _pick(tester, 'Copy path');
    expect(copied.last, 'mixed.go:3');
    await _rightClick(
      tester,
      tester.getCenter(find.textContaining('package main', findRichText: true)),
    );
    await _pick(tester, 'Quote in reply');
    expect(
      chatC(d).draft.replies.value.single.quote,
      '`mixed.go`, lines 3–4:\n```go\nunc main() {\n}\n```',
    );
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('lines unwrapped: Copy path gives the line clicked, or the '
      'first line of a selection', (tester) async {
    wrapLines.value = false;
    final copied = _clipboard(tester);
    final (d, _) = await openEditor(
      tester,
      {'mixed.go': _mixed},
      open: const ['mixed.go'],
    );
    Finder line(String text) => find.text(text, findRichText: true);
    await _rightClick(tester, tester.getCenter(line('}')));
    await _pick(tester, 'Copy path');
    expect(copied, ['mixed.go:4']);
    final mouse = await tester.startGesture(
      tester.getTopLeft(line('func main() {')) + const Offset(12, 8),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(tester.getTopLeft(line('}')) + const Offset(30, 8));
    await mouse.up();
    await tester.pumpAndSettle();
    await _rightClick(tester, tester.getCenter(line('}')));
    await _pick(tester, 'Copy path');
    expect(copied.last, 'mixed.go:3');
    await endEditor(tester, d);
  }, variant: onMac);
}
