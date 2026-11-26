import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminals.dart';
import 'package:xterm2/xterm.dart';

import 'fake_daemon.dart' show FakeDaemon;
import 'fake_shells.dart';
import 'harness.dart';

// What terminal_select_test.dart (a drag), terminal_held_scroll_test.dart
// (a drag held past the edge) and terminal_shift_click_test.dart
// (Shift+click, ⌘-click and ⌘A) share:
// a terminal panel on the real TerminalView, filled with numbered lines,
// and mouse gestures and copies on it, in buffer cells.

/// [n] made-up lines, line i reading `row i`, so a line's text names its
/// row in the buffer while nothing has been trimmed.
String numberedRows(int n) =>
    [for (var i = 0; i < n; i++) 'row $i'].join('\r\n');

/// The terminal panel on one terminal in [folder] that has shown
/// [replay], settled; [showChange] is what a ⌘-click on a file calls.
Future<(FakeShells, TermSession)> openTerminal(
  WidgetTester tester, {
  String? replay,
  String folder = '/tmp/veg',
  Future<bool> Function(String path)? showChange,
}) async {
  final fake = FakeDaemon([]);
  final info = pb.Terminal(
    id: 'a',
    chatId: 'chat',
    folder: folder,
    shell: 'zsh',
  );
  final shells = FakeShells(fake, terminals: [info])
    ..replay['a'] = replay ?? '${numberedRows(500)}\r\n\$ ';
  final terms = Terminals(NushiServiceClient(fake));
  await showPanel(tester, terms, 'chat', showChange: showChange);
  return (shells, terms.session(info));
}

/// Chat [chatId]'s terminal panel, settled.
Future<void> showPanel(
  WidgetTester tester,
  Terminals terms,
  String chatId, {
  Future<bool> Function(String path)? showChange,
}) async {
  await tester.pumpWidget(
    themed(
      TerminalPanel(
        key: ValueKey(chatId),
        chatId: chatId,
        terms: terms,
        onHide: () {},
        showChange: showChange ?? (_) async => false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The terminal's view, as drawn.
TerminalViewState viewOf(WidgetTester tester) =>
    tester.state<TerminalViewState>(find.byType(TerminalView));

/// The middle of the cell at [cell] (buffer coordinates) on the screen.
Offset cellCenter(WidgetTester tester, CellOffset cell) {
  final r = viewOf(tester).renderTerminal;
  return r.localToGlobal(
    r.getOffset(cell) + Offset(r.cellSize.width / 2, r.lineHeight / 2),
  );
}

/// The buffer's row at the top of the view.
int topRow(WidgetTester tester, TermSession s) =>
    (s.scroll.offset / viewOf(tester).renderTerminal.lineHeight).round();

/// The view's rectangle on the screen.
Rect viewBounds(WidgetTester tester) =>
    tester.getRect(find.byType(TerminalView));

/// The rectangle the rows scroll in, on the screen (the view's, inside
/// its padding).
Rect rowsRect(WidgetTester tester) {
  final r = viewOf(tester).renderTerminal;
  return r.localToGlobal(Offset.zero) & r.size;
}

/// The buffer's rows at the top and at the bottom of the view, as far as
/// any of them shows.
(int, int) rowsInView(WidgetTester tester) {
  final r = viewOf(tester).renderTerminal;
  return (
    r.getCellOffset(Offset.zero).y,
    r.getCellOffset(Offset(0, r.size.height - 1)).y,
  );
}

/// [count] frames with the pointer held still.
Future<void> stillFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The selection in buffer cells, base first.
(CellOffset, CellOffset)? selectionOf(TermSession s) {
  final r = s.controller.selectionFor(s.terminal.buffer);
  return r == null ? null : (r.begin, r.end);
}

/// [n] made-up lines of three words, line i reading `alpha betai gamma`.
String wordRows(int n) =>
    [for (var i = 0; i < n; i++) 'alpha beta$i gamma'].join('\r\n');

/// Lines [from] to [to] of [wordRows], as a copy joins them.
String wordLines(int from, int to) =>
    [for (var i = from; i <= to; i++) 'alpha beta$i gamma'].join('\n');

/// Lines [from] to [to] (inclusive) as a copy joins them.
String rowLines(int from, int to) =>
    [for (var i = from; i <= to; i++) 'row $i'].join('\n');

/// What ⌘C copies now.
Future<String?> copyNow(WidgetTester tester, TermSession s) async {
  final copied = clipboardCopies(tester);
  s.focus.requestFocus();
  await tester.pump();
  await press(tester, LogicalKeyboardKey.keyC, cmd: true);
  return copied.lastOrNull;
}

/// A mouse press at [cell], moved a little so the drag starts.
Future<TestGesture> pressAt(WidgetTester tester, CellOffset cell) async {
  final g = await tester.startGesture(
    cellCenter(tester, cell),
    kind: PointerDeviceKind.mouse,
  );
  await g.moveBy(const Offset(4, 0));
  await tester.pump();
  return g;
}

/// The pointer taken to [to] and jiggled there for [count] frames: the
/// package's edge scroll moves the view at most a step for each move past
/// the edge (Flutter's EdgeDraggingAutoScroller), so a hand held still
/// past it scrolls no further.
Future<void> holdAt(
  WidgetTester tester,
  TestGesture g,
  Offset to, {
  int count = 60,
}) async {
  await g.moveTo(to);
  for (var i = 0; i < count; i++) {
    await g.moveBy(Offset(0, i.isEven ? 1 : -1));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A mouse click at [cell], Shift held when [shift]; then long enough that
/// the next is not a double click.
Future<void> clickAt(
  WidgetTester tester,
  CellOffset cell, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(cellCenter(tester, cell), kind: PointerDeviceKind.mouse);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump(const Duration(milliseconds: 500));
}

/// [count] quick mouse clicks at [cell]: a double or triple click; then
/// long enough that the next is not one more.
Future<void> clicksAt(WidgetTester tester, CellOffset cell, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.tapAt(cellCenter(tester, cell), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// The view scrolled to put [row] at its top.
Future<void> scrollToRow(WidgetTester tester, TermSession s, int row) async {
  s.scroll.jumpTo(row * viewOf(tester).renderTerminal.lineHeight);
  await tester.pump();
}
