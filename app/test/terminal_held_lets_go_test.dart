import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/terminal_session.dart';
import 'package:xterm2/xterm.dart';

import 'harness.dart';
import 'terminal_select_fixture.dart';

// A drag held past the edge sits on xterm2, which moves the view and the
// selection for its own reasons. Where the buffer under the press changes
// (a full-screen program's alternate screen) or is cleared (⌘K), the press
// lets go: its pinned start is released, the held scroll stops, and the
// rest of that press pins nothing more (terminal_select.dart).

/// A press three rows below the view's top, taken 30 px above the top and
/// held still for a few frames, scrolling up.
Future<TestGesture> _heldAbove(WidgetTester tester, TermSession s) async {
  final g = await pressAt(tester, CellOffset(2, topRow(tester, s) + 3));
  final rows = rowsRect(tester);
  await g.moveTo(Offset(rows.left + 1, rows.top - 30));
  await stillFrames(tester, 5);
  expect(tester.hasRunningAnimations, isTrue, reason: 'it scrolls');
  return g;
}

/// A new press held below the bottom scrolls and selects from its start,
/// as any.
Future<void> _newPressWorks(WidgetTester tester, TermSession s) async {
  await scrollToRow(tester, s, 0);
  final g = await pressAt(tester, const CellOffset(0, 5));
  final rows = rowsRect(tester);
  await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
  await stillFrames(tester, 5);
  final from = s.scroll.offset;
  await stillFrames(tester, 20);
  final lineHeight = viewOf(tester).renderTerminal.lineHeight;
  expect(s.scroll.offset - from, greaterThan(3 * lineHeight));
  final (_, last) = rowsInView(tester);
  expect(selectionOf(s), (const CellOffset(0, 5), CellOffset(1, last)));
  await g.up();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('a held press lets go', () {
    testWidgets('when a full-screen program starts under it with the pointer '
        'still: nothing throws or scrolls, and after it the press selects '
        'nothing, still or moved', (tester) async {
      final (_, s) = await openTerminal(tester);
      final g = await _heldAbove(tester, s);
      s.terminal.write('\x1b[?1049h\x1b[Hfull screen');
      await tester.pump(const Duration(milliseconds: 16));
      expect(s.terminal.isUsingAltBuffer, isTrue);
      final there = s.scroll.offset;
      await stillFrames(tester, 10);
      expect(tester.takeException(), isNull);
      expect(s.scroll.offset, there);
      expect(tester.hasRunningAnimations, isFalse);

      s.terminal.write('\x1b[?1049l');
      for (var i = 0; i < 5; i++) {
        s.terminal.write('\r\nafter $i');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await stillFrames(tester, 10);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      // The rest of the press selects nothing, moved or not: the package
      // would select from the screen point it began at, over other text.
      final rows = rowsRect(tester);
      await g.moveTo(rows.center);
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(7, 9));
        await tester.pump(const Duration(milliseconds: 16));
        expect(selectionOf(s), isNull, reason: 'move $i');
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);

      await _newPressWorks(tester, s);
    });

    testWidgets('when a full-screen program starts inside a synchronized '
        'update, before the view hears of it: a frame finds it, and nothing '
        'throws', (tester) async {
      // During a program's synchronized update (DEC 2026) the package tells
      // no listener of what it writes, so the held scroll's next frame is
      // the first to meet the program's screen.
      final (_, s) = await openTerminal(tester);
      final g = await _heldAbove(tester, s);
      s.terminal.write('\x1b[?2026h\x1b[?1049h\x1b[Hfull screen');
      // The frame that met it scrolled a step first, which shows the
      // scrollbar until it fades.
      await stillFrames(tester, 60);
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      s.terminal.write('\x1b[?2026l');
      await stillFrames(tester, 5);
      s.terminal.write('\x1b[?1049l\r\nafter');
      await stillFrames(tester, 10);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('when a full-screen program comes and goes while nothing '
        'scrolls: output after it gives a scrollback, and selects nothing', (
      tester,
    ) async {
      // Output that fits the view leaves nothing to scroll, so no frame of
      // the held scroll sees the program's screen; the press lets go as
      // the buffer changes all the same.
      final (_, s) = await openTerminal(tester, replay: numberedRows(5));
      final g = await pressAt(tester, const CellOffset(2, 3));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.top - 30));
      await stillFrames(tester, 5);
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing to scroll');
      s.terminal.write('\x1b[?1049h\x1b[Hfull screen');
      await tester.pump(const Duration(milliseconds: 16));
      s.terminal.write('\x1b[?1049l');
      await tester.pump(const Duration(milliseconds: 16));
      s.terminal.write(
        '\r\n${[for (var i = 5; i < 300; i++) 'row $i'].join('\r\n')}',
      );
      await stillFrames(tester, 20);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));

      await _newPressWorks(tester, s);
    });

    testWidgets('when ⌘K clears the terminal under it: no selection is left, '
        'nothing ticks, and ⌘C copies nothing, after output too', (
      tester,
    ) async {
      // A full scrollback: the start's line goes with the clear, as it
      // would were it trimmed, but no line was dropped from the start.
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      await scrollToRow(tester, s, 6000);
      final g = await _heldAbove(tester, s);
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true, settle: false);
      await stillFrames(tester, 5);
      expect(s.terminal.buffer.scrollBack, 0);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      for (var i = 0; i < 60; i++) {
        s.terminal.write('\r\nafter $i');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await stillFrames(tester, 40);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), isNull);

      await _newPressWorks(tester, s);
    });

    testWidgets("when the shell's clear empties the scrollback under it: no "
        'selection is left and nothing ticks, after output too', (
      tester,
    ) async {
      // `clear` writes these: the scrollback is cut, no line is dropped
      // from the start, and the package's own clear is not called.
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 200);
      final g = await _heldAbove(tester, s);
      s.terminal.write('\x1b[H\x1b[2J\x1b[3J');
      await stillFrames(tester, 5);
      for (var i = 0; i < 60; i++) {
        s.terminal.write('\r\nafter $i');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await stillFrames(tester, 60);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), isNull);
    });

    testWidgets("when the shell's clear comes after the start was trimmed "
        'out of a full scrollback: no selection is left, nothing ticks and '
        '⌘C copies nothing', (tester) async {
      // Output drops the start's line first, so the selection starts at
      // the oldest line kept; the clear then must not be taken for more
      // of the same.
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      await scrollToRow(tester, s, 150);
      final g = await _heldAbove(tester, s);
      for (var i = 0; i < 40; i++) {
        s.terminal.write(
          [for (var n = 0; n < 20; n++) '\r\nmore $i.$n'].join(),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(selectionOf(s)?.$1, const CellOffset(0, 0), reason: 'trimmed');
      s.terminal.write('\x1b[H\x1b[2J\x1b[3J\$ ');
      await stillFrames(tester, 5);
      for (var i = 0; i < 30; i++) {
        s.terminal.write('\r\nafter $i');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await stillFrames(tester, 30);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), isNull);
    });

    testWidgets('when one write clears a full scrollback and prints it full '
        'again: the reprint is not selected, and nothing ticks', (
      tester,
    ) async {
      // An inline program's clear and reprint: lines are dropped and the
      // count is full again in the one change, as trimming would leave it.
      final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
      await scrollToRow(tester, s, 6000);
      final g = await _heldAbove(tester, s);
      s.terminal.write(
        '\x1b[H\x1b[2J\x1b[3J'
        '${[for (var n = 0; n < 10100; n++) 'reprint $n'].join('\r\n')}',
      );
      await stillFrames(tester, 40);
      expect(tester.takeException(), isNull);
      expect(selectionOf(s), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), isNull);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), isNull);
    });
  });
}
