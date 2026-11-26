import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'harness.dart';
import 'outside_fixture.dart' show answerBrowser;
import 'terminal_select_fixture.dart';

// Shift+click selects between two places screens apart and grows a
// selection; ⌘-click opens a link; ⌘A selects the whole buffer.
// terminal_select_shift.dart does Shift+click, which xterm2 lacks.

void main() {
  group('Shift+click', () {
    testWidgets('selects from the last click to this one, screens later', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      s.scroll.jumpTo(0);
      await tester.pump();
      await clickAt(tester, const CellOffset(2, 5));
      await scrollToRow(tester, s, 100);
      await clickAt(tester, const CellOffset(3, 110), shift: true);
      expect(selectionOf(s), (
        const CellOffset(2, 5),
        const CellOffset(4, 110),
      ));
      expect(await copyNow(tester, s), 'w 5\n${rowLines(6, 109)}\nrow');
    });

    testWidgets('selects backwards to a click before the last one', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 295);
      await clickAt(tester, const CellOffset(3, 300));
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(1, 10), shift: true);
      expect(selectionOf(s), (
        const CellOffset(4, 300),
        const CellOffset(1, 10),
      ), reason: 'from after the first click’s cell, back to the second’s');
      expect(await copyNow(tester, s), 'ow 10\n${rowLines(11, 299)}\nrow');
    });

    testWidgets('after a drag selection, moves its end to a click after it '
        'and its start to one before it, keeping the rest', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      await g.moveTo(cellCenter(tester, const CellOffset(2, 6)));
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectionOf(s), (const CellOffset(0, 5), const CellOffset(3, 6)));
      await scrollToRow(tester, s, 190);
      await clickAt(tester, const CellOffset(4, 200), shift: true);
      expect(selectionOf(s), (
        const CellOffset(0, 5),
        const CellOffset(5, 200),
      ));
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(1, 2), shift: true);
      expect(selectionOf(s), (
        const CellOffset(5, 200),
        const CellOffset(1, 2),
      ), reason: 'before its start: from the click to its end');
      expect(await copyNow(tester, s), 'ow 2\n${rowLines(3, 199)}\nrow 2');
    });

    testWidgets('after a double click, extends by whole words, both ways', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester, replay: wordRows(40));
      await scrollToRow(tester, s, 0);
      await clicksAt(tester, const CellOffset(7, 5), 2);
      expect(selectionOf(s), (const CellOffset(6, 5), const CellOffset(11, 5)));
      await clickAt(tester, const CellOffset(14, 8), shift: true);
      expect(selectionOf(s), (const CellOffset(6, 5), const CellOffset(17, 8)));
      expect(
        await copyNow(tester, s),
        'beta5 gamma\n${wordLines(6, 8)}',
        reason: "to the end of the click's word",
      );
      await clickAt(tester, const CellOffset(2, 2), shift: true);
      expect(selectionOf(s), (const CellOffset(17, 8), const CellOffset(0, 2)));
      expect(
        await copyNow(tester, s),
        wordLines(2, 8),
        reason: "from the start of the click's word, the rest kept",
      );
    });

    testWidgets('after a double click and then ⌘A, extends by cells', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester, replay: wordRows(40));
      await scrollToRow(tester, s, 0);
      await clicksAt(tester, const CellOffset(7, 5), 2);
      expect(selectionOf(s), (const CellOffset(6, 5), const CellOffset(11, 5)));
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA, cmd: true);
      expect(selectionOf(s)!.$1, const CellOffset(0, 0));
      // ⌘A replaced the word: what the Shift+click extends was not made by
      // the double click, so its end lands on the click's cell, not its
      // word's edge.
      await clickAt(tester, const CellOffset(14, 8), shift: true);
      expect(selectionOf(s), (const CellOffset(0, 0), const CellOffset(15, 8)));
      expect(await copyNow(tester, s), '${wordLines(0, 7)}\nalpha beta8 gam');
    });

    testWidgets('after a triple click, extends by whole lines, both ways', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester, replay: wordRows(40));
      await scrollToRow(tester, s, 0);
      await clicksAt(tester, const CellOffset(7, 5), 3);
      expect(selectionOf(s), (const CellOffset(0, 5), const CellOffset(17, 5)));
      await clickAt(tester, const CellOffset(8, 2), shift: true);
      expect(selectionOf(s), (const CellOffset(17, 5), const CellOffset(0, 2)));
      expect(await copyNow(tester, s), wordLines(2, 5));
      await clickAt(tester, const CellOffset(3, 9), shift: true);
      expect(selectionOf(s), (const CellOffset(0, 2), const CellOffset(17, 9)));
      expect(await copyNow(tester, s), wordLines(2, 9));
    });

    testWidgets('after an Option-drag, grows the block to the click', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final g = await pressAt(tester, const CellOffset(2, 5));
      await g.moveTo(cellCenter(tester, const CellOffset(3, 7)));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 500));
      await clickAt(tester, const CellOffset(1, 9), shift: true);
      final range = s.controller.selectionFor(s.terminal.buffer)!;
      expect(range, isA<BufferRangeBlock>());
      expect(
        (range.begin, range.end),
        (const CellOffset(1, 5), const CellOffset(4, 9)),
      );
    });

    testWidgets('after an Option-drag and a plain click, selects a run of '
        'text, not a block', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final g = await pressAt(tester, const CellOffset(2, 5));
      await g.moveTo(cellCenter(tester, const CellOffset(4, 8)));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        s.controller.selectionFor(s.terminal.buffer),
        isA<BufferRangeBlock>(),
      );
      await clickAt(tester, const CellOffset(0, 2));
      await clickAt(tester, const CellOffset(1, 10), shift: true);
      final range = s.controller.selectionFor(s.terminal.buffer)!;
      expect(range, isA<BufferRangeLine>());
      expect(
        (range.begin, range.end),
        (const CellOffset(0, 2), const CellOffset(2, 10)),
      );
      expect(await copyNow(tester, s), 'row 2\n${rowLines(3, 9)}\nro');
    });

    testWidgets('with no click or selection, selects from the cursor', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      final cursor = s.terminal.buffer.absoluteCursorY;
      expect(s.terminal.buffer.cursorX, 2);
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(0, 10), shift: true);
      expect(selectionOf(s), (CellOffset(3, cursor), const CellOffset(0, 10)));
    });

    testWidgets('takes a wide character at the right edge whole, either '
        'way', (tester) async {
      final (_, s) = await openTerminal(tester, replay: '');
      final w = s.terminal.viewWidth;
      s.terminal.write('${'x' * (w - 2)}漢\r\ntail\r\n\$ ');
      await tester.pump();
      // From a click on its right half, forward.
      await clickAt(tester, CellOffset(w - 1, 0));
      await clickAt(tester, const CellOffset(2, 1), shift: true);
      expect(selectionOf(s), (CellOffset(w - 2, 0), const CellOffset(3, 1)));
      expect(await copyNow(tester, s), '漢\ntai');
      // To a click on its right half, backward.
      await clickAt(tester, const CellOffset(2, 1));
      await clickAt(tester, CellOffset(w - 1, 0), shift: true);
      expect(selectionOf(s), (const CellOffset(3, 1), CellOffset(w - 2, 0)));
      expect(await copyNow(tester, s), '漢\ntai');
    });

    testWidgets('from a last click whose line was trimmed from the '
        'scrollback, starts at the oldest line kept', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(9990));
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(2, 3));
      // 10 lines over the limit of 10000: rows 0 to 9 go.
      s.terminal.write(
        '\r\n${[for (var i = 0; i < 20; i++) 'new $i'].join('\r\n')}',
      );
      await tester.pump();
      expect(s.terminal.buffer.lines[0].getText().trimRight(), 'row 10');
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(3, 8), shift: true);
      expect(selectionOf(s), (const CellOffset(0, 0), const CellOffset(4, 8)));
      expect(await copyNow(tester, s), '${rowLines(10, 17)}\nrow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a plain click after it clears the selection', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(0, 2));
      await clickAt(tester, const CellOffset(0, 8), shift: true);
      expect(selectionOf(s), isNotNull);
      await clickAt(tester, const CellOffset(0, 9));
      expect(selectionOf(s), isNull);
    });

    testWidgets('with ⌘ held opens a link and selects nothing', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      await clickAt(tester, const CellOffset(0, 2));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await clickAt(tester, const CellOffset(0, 8), shift: true);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(selectionOf(s), isNull);
    });

    testWidgets("in a program that reads the mouse, follows the package's "
        'rule for Shift', (tester) async {
      final (shells, s) = await openTerminal(tester);
      s.terminal.write('\x1b[?1000h\x1b[?1006h');
      final top = topRow(tester, s);
      await clickAt(tester, CellOffset(0, top + 2));
      expect(shells.typedAll.join(), contains('\x1b[<0;1;3M'));
      await clickAt(tester, CellOffset(3, top + 8), shift: true);
      final cursor = s.terminal.buffer.absoluteCursorY;
      expect(
        selectionOf(s),
        (CellOffset(3, cursor), CellOffset(3, top + 8)),
        reason:
            'Shift takes the click from the program; the plain click was '
            "the program's, so it selects from the cursor",
      );
      s.terminal.write('\x1b[>1s'); // the program keeps Shift-clicks too
      shells.typedAll.clear();
      await clickAt(tester, CellOffset(0, top + 9));
      await clickAt(tester, CellOffset(3, top + 12), shift: true);
      expect(selectionOf(s), isNull);
      expect(shells.typedAll.join(), contains('\x1b[<4;4;13M'));
    });
  });

  group('⌘-click', () {
    testWidgets('opens the URL in the browser and shows the file under the '
        'pointer', (tester) async {
      final folder = Directory.systemTemp.createTempSync('nushi-links');
      addTearDown(() => folder.deleteSync(recursive: true));
      File('${folder.path}/notes.txt').writeAsStringSync('made up');
      final browser = answerBrowser((_) => null);
      final shown = <String>[];
      final (_, s) = await openTerminal(
        tester,
        replay: 'see https://example.com/radish\r\nat notes.txt\r\n\$ ',
        folder: folder.path,
        showChange: (path) async {
          shown.add(path);
          return true;
        },
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tapAt(
        cellCenter(tester, const CellOffset(8, 0)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(
        cellCenter(tester, const CellOffset(5, 1)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(
        [for (final c in browser) (c.method, c.arguments)],
        [('open', 'https://example.com/radish')],
      );
      expect(shown, [File('${folder.path}/notes.txt').absolute.path]);
      expect(selectionOf(s), isNull);
    });
  });

  group('⌘A', () {
    testWidgets('selects the whole buffer, scrollback too, and ⌘C copies it '
        'with a wrapped line whole', (tester) async {
      final long = List.filled(40, 'radish').join(' ');
      final (_, s) = await openTerminal(
        tester,
        replay: '${numberedRows(300)}\r\n$long',
      );
      expect(s.terminal.buffer.lines.toList().last.isWrapped, isTrue);
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA, cmd: true);
      final (base, _) = selectionOf(s)!;
      expect(base, const CellOffset(0, 0));
      expect(await copyNow(tester, s), '${rowLines(0, 299)}\n$long');
    });
  });
}
