import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/terminal_session.dart';
import 'package:xterm2/xterm.dart';

import 'harness.dart';
import 'terminal_select_fixture.dart';

// The checks a held press makes before it pins or lets go
// (terminal_select.dart and its parts), each in a case only it holds:
// a start trimmed out of the scrollback then cleared by ⌘K or by a
// program's screen erase, a full-screen program met before the view
// hears of it, and lines dropped while the buffer shrank (issue #125).

/// A press held 30 px above the top of a full scrollback, whose start
/// output has since trimmed out of it: the selection starts at the oldest
/// line kept.
Future<TestGesture> _trimmedHeld(WidgetTester tester, TermSession s) async {
  await scrollToRow(tester, s, 150);
  final g = await pressAt(tester, CellOffset(2, topRow(tester, s) + 3));
  final rows = rowsRect(tester);
  await g.moveTo(Offset(rows.left + 1, rows.top - 30));
  await stillFrames(tester, 5);
  for (var i = 0; i < 40; i++) {
    s.terminal.write([for (var n = 0; n < 20; n++) '\r\nmore $i.$n'].join());
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(selectionOf(s)?.$1, const CellOffset(0, 0), reason: 'trimmed');
  return g;
}

/// Lets [g] go and checks nothing was left selected.
Future<void> _up(WidgetTester tester, TestGesture g, TermSession s) async {
  await g.up();
  await tester.pump(const Duration(milliseconds: 500));
  expect(selectionOf(s), isNull);
  expect(tester.takeException(), isNull);
}

void main() {
  group('a held press', () {
    // The clear-generation check: the start was already trimmed, so its
    // line being gone says nothing, and ⌘K erases no screen.
    testWidgets('whose start was trimmed lets go at ⌘K: no selection is '
        'left, nothing ticks, and ⌘C copies nothing', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      final g = await _trimmedHeld(tester, s);
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true, settle: false);
      await stillFrames(tester, 30);
      expect(s.terminal.buffer.scrollBack, 0);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      // The rest of the press selects nothing, moved inside the view or
      // held above it as output gives a scrollback again.
      final rows = rowsRect(tester);
      await g.moveTo(rows.center);
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(7, 9));
        await tester.pump(const Duration(milliseconds: 16));
        expect(selectionOf(s), isNull, reason: 'move $i');
      }
      await g.moveTo(Offset(rows.left + 1, rows.top - 30));
      for (var i = 0; i < 100; i++) {
        s.terminal.write('\r\nafter $i');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await stillFrames(tester, 30);
      expect(selectionOf(s), isNull);
      expect(await copyNow(tester, s), isNull);
      await _up(tester, g, s);
    });

    // Letting go clears the selection: a screen erase leaves the oldest
    // line kept, where the selection starts, in the scrollback.
    testWidgets('whose start was trimmed lets go at a screen erase, and '
        'the selection from the oldest line kept goes', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      final g = await _trimmedHeld(tester, s);
      s.terminal.write('\x1b[H\x1b[2J\$ ');
      await tester.pump();
      expect(selectionOf(s), isNull);
      await stillFrames(tester, 30);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      await _up(tester, g, s);
    });

    // The buffer's identity in what a pin holds: a trimmed start is held
    // by no line, so only the buffer tells the alternate screen apart.
    testWidgets('whose start was trimmed, moved after a full-screen program '
        'started before the view heard of it, lets go: nothing is selected '
        'or thrown', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(9990));
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 3));
      await g.moveTo(cellCenter(tester, const CellOffset(0, 15)));
      await tester.pump();
      // 10 lines over the limit of 10000: the start's row 3 goes.
      s.terminal.write(
        '\r\n${[for (var i = 0; i < 20; i++) 'new $i'].join('\r\n')}',
      );
      await tester.pump();
      expect(selectionOf(s), (const CellOffset(0, 0), const CellOffset(1, 5)));
      s.terminal.write('\x1b[?2026h\x1b[?1049h\x1b[Hfull screen');
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(9, 7));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'move $i');
        expect(selectionOf(s), isNull, reason: 'move $i');
      }
      s.terminal.write('\x1b[?2026l\x1b[?1049l');
      await stillFrames(tester, 10);
      expect(selectionOf(s), isNull);
      await _up(tester, g, s);
    });

    // The let-go where the package's selection changes: a move selects in
    // the alternate screen before the terminal's listener has heard of it.
    testWidgets('moved after a full-screen program started before the view '
        'heard of it lets go: nothing is selected or thrown', (tester) async {
      final (_, s) = await openTerminal(tester);
      final g = await pressAt(tester, CellOffset(2, topRow(tester, s) + 3));
      await g.moveTo(cellCenter(tester, CellOffset(6, topRow(tester, s) + 8)));
      await tester.pump();
      expect(selectionOf(s), isNotNull);
      s.terminal.write('\x1b[?2026h\x1b[?1049h\x1b[Hfull screen');
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(9, 7));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'move $i');
        expect(selectionOf(s), isNull, reason: 'move $i');
      }
      s.terminal.write('\x1b[?2026l\x1b[?1049l');
      await stillFrames(tester, 10);
      expect(selectionOf(s), isNull);
      await _up(tester, g, s);
    });

    // The line count in "lines were dropped": a buffer that dropped lines
    // and grew no shorter was trimmed; one that also shrank (a write in a
    // synchronized update, then a resize that ends it, heard as one
    // change) is not plain trimming, so the press lets go.
    testWidgets('lets go when lines are dropped and the buffer shrinks in '
        'one change', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 3));
      await g.moveTo(cellCenter(tester, const CellOffset(0, 15)));
      await tester.pump();
      expect(selectionOf(s)?.$1, const CellOffset(0, 3));
      // 10 lines over the limit drop the start's line, not the end's; the
      // cursor goes home, so a shorter screen drops rows from the bottom.
      final t = s.terminal
        ..write(
          '\x1b[?2026h'
          '${[for (var i = 0; i < 10; i++) '\r\nnew $i'].join()}'
          '\x1b[H',
        );
      final lines = t.buffer.lines.length;
      t.resize(t.viewWidth, t.viewHeight - 5);
      expect(t.buffer.lines.length, lines - 5);
      expect(selectionOf(s), isNull);
      await stillFrames(tester, 10);
      expect(selectionOf(s), isNull);
      await _up(tester, g, s);
    });
  });
}
