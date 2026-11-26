import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/terminal_panel.dart';
import 'package:xterm2/xterm.dart';

import 'terminal_select_fixture.dart';

// A drag held past the view's top or bottom edge goes on scrolling a frame
// at a time, where xterm2's own edge scroll steps only on a pointer move
// (docs/development.md's Dependencies); terminal_held_scroll.dart scrolls
// it and terminal_select.dart keeps the selection's far end at that edge.

void main() {
  group('a drag held still past the edge', () {
    testWidgets('30 px below the bottom goes on scrolling a frame at a time, '
        'to the last row in view, and copies every line between', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.right - 1, rows.bottom + 30));
      await tester.pump(const Duration(milliseconds: 16));
      final first = s.scroll.offset;
      await stillFrames(tester, 30);
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      expect(
        s.scroll.offset - first,
        greaterThan(5 * lineHeight),
        reason: 'more than the step a move makes',
      );
      final (_, last) = rowsInView(tester);
      expect(selectionOf(s), (
        const CellOffset(0, 5),
        CellOffset(s.terminal.viewWidth, last),
      ));
      expect(await copyNow(tester, s), rowLines(5, last));
      await g.up();
    });

    testWidgets('30 px above the top goes on scrolling up, to the first row '
        'in view', (tester) async {
      final (_, s) = await openTerminal(tester);
      final start = topRow(tester, s) + 3;
      final g = await pressAt(tester, CellOffset(2, start));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.top - 30));
      await tester.pump(const Duration(milliseconds: 16));
      final first = s.scroll.offset;
      await stillFrames(tester, 30);
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      expect(first - s.scroll.offset, greaterThan(5 * lineHeight));
      final (top, _) = rowsInView(tester);
      expect(selectionOf(s), (CellOffset(3, start), CellOffset(0, top)));
      expect(await copyNow(tester, s), '${rowLines(top, start - 1)}\nrow');
      await g.up();
    });

    testWidgets("moving past the edge, the package's step in flight never "
        'gets a frame, so a frame scrolls by its own step, and the selection '
        'stays in view', (tester) async {
      // Each move starts the package's own edge step, an animation created
      // after this ticker: the next frame's tick jumps the scroll first,
      // which ends that animation before it ever ticks. So no frame takes
      // the package's step, nor adds this one to it; HeldScroll's rule of
      // the further of the two is a guard this can't reach.
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 5);
      var last = s.scroll.offset;
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(0, i.isEven ? 1 : -1));
        final (_, bottom) = rowsInView(tester);
        expect(selectionOf(s)!.$2.y, lessThanOrEqualTo(bottom), reason: '$i');
        await tester.pump(const Duration(milliseconds: 16));
        // 31 px past at most: 31 × 30 px a second, for 16 ms.
        expect(s.scroll.offset - last, inInclusiveRange(1, 15), reason: '$i');
        last = s.scroll.offset;
      }
      await g.up();
    });

    testWidgets('a single long frame held 500 px past scrolls three rows '
        'at most', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 500));
      await stillFrames(tester, 5);
      final from = s.scroll.offset;
      await tester.pump(const Duration(milliseconds: 200));
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      // 100 px past counts, for 200 ms: 600 px but for the cap.
      expect(s.scroll.offset - from, greaterThan(0));
      expect(s.scroll.offset - from, lessThanOrEqualTo(3 * lineHeight));
      await g.up();
    });

    testWidgets('the further past the edge, the faster, a few rows a frame '
        'at most', (tester) async {
      final (_, s) = await openTerminal(tester);
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      Future<double> pace(double past) async {
        await scrollToRow(tester, s, 0);
        final g = await pressAt(tester, const CellOffset(0, 5));
        final rows = rowsRect(tester);
        await g.moveTo(Offset(rows.left + 1, rows.bottom + past));
        await stillFrames(tester, 10);
        final from = s.scroll.offset;
        await stillFrames(tester, 10);
        final pace = (s.scroll.offset - from) / 10;
        await g.up();
        await tester.pump(const Duration(milliseconds: 500));
        return pace;
      }

      final (near, far, farther) = (
        await pace(5),
        await pace(50),
        await pace(500),
      );
      expect(near, greaterThan(0));
      expect(far, greaterThan(near * 5));
      expect(farther, greaterThan(far));
      expect(farther, lessThanOrEqualTo(3 * lineHeight));
    });

    testWidgets('coming back inside stops it at once', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 10);
      await g.moveTo(rows.center);
      final there = s.scroll.offset;
      await stillFrames(tester, 20);
      expect(s.scroll.offset, there);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
    });

    testWidgets('at the end of the buffer it stops, and nothing throws', (
      tester,
    ) async {
      final (_, s) = await openTerminal(tester);
      final start = topRow(tester, s) + 2;
      final g = await pressAt(tester, CellOffset(0, start));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.right - 1, rows.bottom + 30));
      await stillFrames(tester, 20);
      expect(s.scroll.offset, s.scroll.position.maxScrollExtent);
      expect(tester.hasRunningAnimations, isFalse);
      final lastLine = s.terminal.buffer.lines.length - 1;
      expect(selectionOf(s)?.$2.y, lastLine);
      expect(tester.takeException(), isNull);
      await g.up();
    });

    testWidgets('at the end of the buffer, output that arrives is selected '
        'to its last line', (tester) async {
      final (_, s) = await openTerminal(tester);
      final g = await pressAt(tester, CellOffset(0, topRow(tester, s) + 2));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.right - 1, rows.bottom + 30));
      await stillFrames(tester, 20);
      expect(tester.hasRunningAnimations, isFalse, reason: 'at the end');
      s.terminal.write('\r\nnew 0\r\nnew 1\r\nnew 2');
      await stillFrames(tester, 3);
      final lastLine = s.terminal.buffer.lines.length - 1;
      expect(s.scroll.offset, s.scroll.position.maxScrollExtent);
      expect(selectionOf(s)?.$2.y, lastLine);
      expect(await copyNow(tester, s), endsWith('\$\nnew 0\nnew 1\nnew 2'));
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
    });

    testWidgets('at the end of the buffer, output a frame apart is selected '
        'to its last line each frame, and then nothing ticks', (tester) async {
      final (_, s) = await openTerminal(tester);
      final g = await pressAt(tester, CellOffset(0, topRow(tester, s) + 2));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.right - 1, rows.bottom + 30));
      await stillFrames(tester, 20);
      for (var i = 0; i < 10; i++) {
        s.terminal.write('\r\nnew $i');
        await tester.pump(const Duration(milliseconds: 16));
        final lastLine = s.terminal.buffer.lines.length - 1;
        expect(selectionOf(s)?.$2.y, lastLine, reason: 'write $i');
      }
      await stillFrames(tester, 5);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await copyNow(tester, s), endsWith('new 8\nnew 9'));
      await g.up();
    });

    testWidgets('above the top of output that fits the view, it waits, and '
        'scrolls up once output gives it a scrollback', (tester) async {
      // Nothing to scroll, so the held scroll stops; with the pointer
      // still, only the catch-up after output's layout starts it again.
      final (_, s) = await openTerminal(tester, replay: numberedRows(5));
      final g = await pressAt(tester, const CellOffset(2, 3));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.top - 30));
      await stillFrames(tester, 10);
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing to scroll');
      s.terminal.write(
        '\r\n${[for (var i = 5; i < 300; i++) 'row $i'].join('\r\n')}',
      );
      await tester.pump(const Duration(milliseconds: 16));
      final first = s.scroll.offset;
      expect(first, s.scroll.position.maxScrollExtent);
      await stillFrames(tester, 20);
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      expect(first - s.scroll.offset, greaterThan(5 * lineHeight));
      final (top, _) = rowsInView(tester);
      // Still below the press's row: the selection runs on from it.
      expect(selectionOf(s), (const CellOffset(2, 3), CellOffset(1, top)));
      await g.up();
    });

    testWidgets('released past the edge, it stops', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 10);
      await g.up();
      final there = s.scroll.offset;
      await stillFrames(tester, 20);
      expect(s.scroll.offset, there);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets("released far past the edge right after a move, the package's "
        'step in flight ends too', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 2000));
      await stillFrames(tester, 5);
      // The move starts the package's own edge step, an animation of its
      // own that the release lands in the middle of.
      await g.moveBy(const Offset(0, 1));
      await g.up();
      final there = s.scroll.offset;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(s.scroll.offset, there, reason: 'frame $i');
      }
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets("released inside the view, the package's step in flight "
        'goes on', (tester) async {
      final (_, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      // The move past starts the package's own edge step, an animation
      // the held scroll's first frame leaves alone; the pointer comes back
      // inside and lets go while it is in flight.
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 15));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveTo(rows.center);
      await g.up();
      final there = s.scroll.offset;
      await tester.pump(const Duration(milliseconds: 16));
      expect(s.scroll.offset, greaterThan(there));
      await tester.pumpAndSettle();
    });

    testWidgets('the session ending stops it for that press, moved or not, '
        'and a new press scrolls again', (tester) async {
      final (shells, s) = await openTerminal(tester);
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 10);
      shells.ends('a');
      tester
          .widget<TerminalPanel>(find.byType(TerminalPanel))
          .terms
          .apply('chat', shells.list);
      await tester.pump();
      var there = s.scroll.offset;
      await stillFrames(tester, 20);
      expect(s.scroll.offset, there);
      expect(tester.hasRunningAnimations, isFalse);
      // A hand is never still: a move after the end takes the package's
      // own steps, which end, but the frame scroll does not start again.
      for (var i = 0; i < 3; i++) {
        await g.moveBy(const Offset(0, 1));
        await stillFrames(tester, 10);
      }
      for (var i = 0; i < 120 && tester.hasRunningAnimations; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.hasRunningAnimations, isFalse);
      there = s.scroll.offset;
      await stillFrames(tester, 20);
      expect(s.scroll.offset, there);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));

      // Selecting in an ended terminal is still a selection: a new press
      // held past the edge scrolls as any.
      await scrollToRow(tester, s, 0);
      final again = await pressAt(tester, const CellOffset(0, 5));
      await again.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 10);
      final from = s.scroll.offset;
      await stillFrames(tester, 20);
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      expect(s.scroll.offset - from, greaterThan(3 * lineHeight));
      await again.up();
    });

    testWidgets('the chat switched while it scrolls throws nothing', (
      tester,
    ) async {
      // Held 30 px past, where the package's own edge scroll has already
      // ended: this shows the held scroll adds nothing on a switch. With
      // the pointer far past, the package's own step can still throw its
      // "Terminal viewport is not mounted" on a switch, with no frame of
      // Nushi's; this test is no proof that error is gone.
      final (shells, s) = await openTerminal(tester);
      final terms = tester
          .widget<TerminalPanel>(find.byType(TerminalPanel))
          .terms;
      await scrollToRow(tester, s, 0);
      final g = await pressAt(tester, const CellOffset(0, 5));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.left + 1, rows.bottom + 30));
      await stillFrames(tester, 10);
      shells.list
        ..clear()
        ..add(
          pb.Terminal(
            id: 'b',
            chatId: 'other',
            folder: '/tmp/kale',
            shell: 'zsh',
          ),
        );
      shells.replay['b'] = numberedRows(40);
      await showPanel(tester, terms, 'other');
      await stillFrames(tester, 20);
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
