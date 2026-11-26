import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'harness.dart';
import 'terminal_select_fixture.dart';

// A drag's start stays on its text while the view scrolls under it, past
// the edge or as output arrives. xterm2 keeps a drag's start as a point on
// the screen (docs/development.md's Dependencies); terminal_select.dart
// pins it. A drag held still past the edge: terminal_held_scroll_test.dart.

void main() {
  group('a drag across what scrolls', () {
    testWidgets('down past the bottom edge, from row 5 of 500, keeps its '
        'start and copies every line between', (tester) async {
      final (_, s) = await openTerminal(tester);
      s.scroll.jumpTo(0);
      await tester.pump();
      final g = await pressAt(tester, const CellOffset(0, 5));
      final below = viewBounds(tester).bottomLeft + const Offset(200, 20);
      await holdAt(tester, g, below);
      final top = topRow(tester, s);
      expect(top, greaterThan(5), reason: 'the view scrolled past row 5');
      await g.up();
      await tester.pump();
      final (base, extent) = selectionOf(s)!;
      expect(base, const CellOffset(0, 5), reason: 'the base stayed on row 5');
      expect(extent.y, greaterThan(top + s.terminal.viewHeight - 3));
      expect(await copyNow(tester, s), rowLines(5, extent.y));
    });

    testWidgets('up past the top edge keeps its start', (tester) async {
      final (_, s) = await openTerminal(tester);
      final start = topRow(tester, s) + 3;
      final g = await pressAt(tester, CellOffset(2, start));
      await holdAt(
        tester,
        g,
        viewBounds(tester).topLeft + const Offset(1, -20),
      );
      final top = topRow(tester, s);
      expect(top, lessThan(start - s.terminal.viewHeight));
      await g.up();
      await tester.pump();
      final (base, extent) = selectionOf(s)!;
      expect(base, CellOffset(3, start), reason: 'after its first cell');
      expect(extent.x, 0, reason: 'to the start of the line above the top');
      expect(extent.y, lessThanOrEqualTo(top));
      expect(await copyNow(tester, s), '${rowLines(extent.y, start - 1)}\nrow');
    });

    testWidgets('output arriving during the drag leaves the start on its '
        'text', (tester) async {
      final (_, s) = await openTerminal(tester);
      final start = topRow(tester, s) + 4;
      final g = await pressAt(tester, CellOffset(0, start));
      await g.moveBy(const Offset(0, 30));
      await tester.pump();
      s.terminal.write(
        '\r\n${[for (var i = 0; i < 20; i++) 'new $i'].join('\r\n')}',
      );
      await tester.pump();
      await g.moveBy(const Offset(0, 4));
      await tester.pump();
      await g.up();
      final (base, _) = selectionOf(s)!;
      expect(base, CellOffset(0, start));
      expect(
        s.terminal.buffer.lines[base.y].getText().trimRight(),
        'row $start',
      );
    });

    testWidgets('a start trimmed out of the scrollback mid-drag moves to the '
        'oldest line kept, and nothing throws', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(9990));
      s.scroll.jumpTo(0);
      await tester.pump();
      final g = await pressAt(tester, const CellOffset(0, 3));
      await g.moveTo(cellCenter(tester, const CellOffset(0, 15)));
      await tester.pump();
      // 10 lines over the limit of 10000: rows 0 to 9 go, row 15 is now 5.
      s.terminal.write(
        '\r\n${[for (var i = 0; i < 20; i++) 'new $i'].join('\r\n')}',
      );
      await tester.pump();
      expect(s.terminal.buffer.lines.length, 10000);
      expect(s.terminal.buffer.lines[0].getText().trimRight(), 'row 10');
      expect(selectionOf(s), (const CellOffset(0, 0), const CellOffset(1, 5)));
      final range = s.controller.selectionFor(s.terminal.buffer)!;
      expect(s.terminal.buffer.getText(range), '${rowLines(10, 14)}\nr');
      await g.moveBy(const Offset(0, 2));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(selectionOf(s)?.$1, const CellOffset(0, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a double-click drag selects whole words across a scroll', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      s.scroll.jumpTo(0);
      await tester.pump();
      final at = cellCenter(tester, const CellOffset(1, 5));
      final click = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
      );
      await click.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 150));
      await holdAt(
        tester,
        g,
        viewBounds(tester).bottomLeft + const Offset(10, 20),
      );
      await g.up();
      await tester.pump();
      final (base, extent) = selectionOf(s)!;
      expect(base, const CellOffset(0, 5), reason: 'from the word "row"');
      expect(extent.x, 3, reason: 'to the end of the word "row"');
      expect(extent.y, greaterThan(5 + s.terminal.viewHeight));
    });

    testWidgets('an Option-drag selects a block across a scroll', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      s.scroll.jumpTo(0);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final g = await pressAt(tester, const CellOffset(2, 5));
      await holdAt(
        tester,
        g,
        cellCenter(tester, CellOffset(4, 5 + s.terminal.viewHeight)) +
            Offset(0, viewBounds(tester).bottom),
      );
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      final range = s.controller.selectionFor(s.terminal.buffer)!;
      expect(range, isA<BufferRangeBlock>());
      expect(range.begin, const CellOffset(2, 5));
      expect(range.end.x, 5);
      expect(range.end.y, greaterThan(5 + s.terminal.viewHeight));
    });

    testWidgets('a drag while find is open keeps its start and leaves the '
        'marks', (tester) async {
      final (_, s) = await openTerminal(tester);
      await press(tester, LogicalKeyboardKey.keyF, cmd: true, settle: false);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'row 1');
      await tester.pump();
      List<BufferRangeLine?> marks() => [
        for (final h in s.controller.searchHighlights)
          h.rangeFor(s.terminal.buffer),
      ];
      final before = marks();
      expect(before, isNotEmpty);
      s.scroll.jumpTo(0);
      await tester.pump();
      final g = await pressAt(tester, const CellOffset(0, 5));
      await holdAt(
        tester,
        g,
        viewBounds(tester).bottomLeft + const Offset(9, 20),
      );
      await g.up();
      await tester.pump();
      expect(selectionOf(s)!.$1, const CellOffset(0, 5));
      expect(marks(), before);
    });

    testWidgets("a find's mark arriving as a press goes down doesn't pin the "
        'selection that was there', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final first = await pressAt(tester, const CellOffset(0, 5));
      await first.moveTo(cellCenter(tester, const CellOffset(2, 6)));
      await first.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), (const CellOffset(0, 5), const CellOffset(3, 6)));
      final g = await tester.startGesture(
        cellCenter(tester, const CellOffset(0, 10)),
        kind: PointerDeviceKind.mouse,
      );
      // Before the package's tap clears the old selection.
      s.controller.setSearchHighlights(s.terminal.buffer, [
        BufferRangeLine(const CellOffset(0, 1), const CellOffset(3, 1)),
      ]);
      await g.moveTo(cellCenter(tester, const CellOffset(2, 12)));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(selectionOf(s), (
        const CellOffset(0, 10),
        const CellOffset(3, 12),
      ));
    });

    testWidgets('⌘K after a drag clears as it does', (tester) async {
      final (_, s) = await openTerminal(tester);
      s.scroll.jumpTo(0);
      await tester.pump();
      final g = await pressAt(tester, const CellOffset(0, 5));
      await holdAt(
        tester,
        g,
        viewBounds(tester).bottomLeft + const Offset(9, 20),
      );
      await g.up();
      await tester.pump();
      expect(selectionOf(s)!.$1, const CellOffset(0, 5));
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true);
      expect(s.terminal.buffer.scrollBack, 0);
      expect(s.terminal.buffer.lines[0].getText().trimRight(), r'$');
      expect(selectionOf(s), isNull);
    });

    testWidgets('in a program that reads the mouse a drag is its own, and '
        'a Shift-drag selects', (tester) async {
      final (shells, s) = await openTerminal(tester);
      s.terminal.write('\x1b[?1002h\x1b[?1006h');
      s.scroll.jumpTo(0);
      await tester.pump();
      final g = await pressAt(tester, const CellOffset(0, 5));
      await g.moveBy(const Offset(0, 40));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(selectionOf(s), isNull);
      expect(shells.typedAll.join(), contains('\x1b[<0;'), reason: 'reported');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final shift = await pressAt(tester, const CellOffset(0, 5));
      await holdAt(
        tester,
        shift,
        viewBounds(tester).bottomLeft + const Offset(9, 20),
      );
      await shift.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      // The package holds the scrollback still while a program reads the
      // mouse, so the Shift-drag selects only what is in view.
      expect(selectionOf(s)!.$1, const CellOffset(0, 5));
    });

    testWidgets('on the alternate screen a drag selects as before, and one '
        'begun before it lets go', (tester) async {
      final (_, s) = await openTerminal(tester);
      final g = await pressAt(tester, CellOffset(0, topRow(tester, s) + 2));
      final screen = [for (var i = 0; i < 8; i++) 'alt $i'].join('\r\n');
      s.terminal.write('\x1b[?1049h\x1b[H$screen');
      await tester.pump();
      expect(s.terminal.isUsingAltBuffer, isTrue);
      // The buffer changed under the press, so it lets go and selects
      // nothing more over the program's screen (terminal_held_lets_go's
      // tests hold the rest of that rule).
      await g.moveTo(cellCenter(tester, const CellOffset(1, 4)));
      await tester.pump();
      expect(selectionOf(s), isNull);
      await g.up();
      final alt = await pressAt(tester, const CellOffset(0, 1));
      await alt.moveTo(cellCenter(tester, const CellOffset(2, 3)));
      await tester.pump();
      await alt.up();
      await tester.pump();
      expect(selectionOf(s), (const CellOffset(0, 1), const CellOffset(3, 3)));
      expect(await copyNow(tester, s), 'alt 1\nalt 2\nalt');
      expect(tester.takeException(), isNull);
    });
  });
}
