import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/terminals.dart';
import 'package:xterm2/xterm.dart';

import 'terminal_select_fixture.dart';

// A drag held past the edge while output arrives, with the scrollback at
// its limit: each new line drops the oldest, and xterm2 moves a view off
// the end up by the dropped lines so it stays on its text. The held scroll
// steps from there, so the text moves only the way the pointer asks.
//
// The terminal keeps 10,000 lines (terminals.dart sets it, and the fixture
// has no way to make it fewer), so a full scrollback is a replay of more.

/// What a frame of a held drag shows.
typedef _Frame = ({
  // The view's top in text terms: its offset plus the height of the lines
  // dropped from the buffer's start since it opened.
  double text,
  // The number in the `row n` line at the top of the view.
  int top,
  // The same at the bottom.
  int bottom,
  // The selection, start first, in buffer cells, and its start's text.
  (CellOffset, CellOffset)? selection,
  String startText,
  // The rows at the top and bottom of the view.
  (int, int) inView,
});

/// The number in line [y]'s `row n`, or -1 for a line written since.
int _label(TermSession s, int y) {
  final text = s.terminal.buffer.lines[y].getText().trim();
  return text.startsWith('row ') ? int.parse(text.substring(4)) : -1;
}

/// A press at row `row 1010`'s text with that row 10 below the view's top,
/// taken [past] px past the top (below 0) or the bottom (above 0) and held
/// still for 60 frames, [perFrame] new lines written before each; each
/// frame as it shows after it.
Future<List<_Frame>> _hold(
  WidgetTester tester,
  TermSession s, {
  required double past,
  required int perFrame,
}) async {
  final lines = s.terminal.buffer.lines;
  final evictedAtOpen = lines.evictedCount;
  final at = lines.length - 1 - _rowsAfter(s, 1000);
  await scrollToRow(tester, s, at);
  final g = await pressAt(tester, CellOffset(0, at + 10));
  final rows = rowsRect(tester);
  await g.moveTo(
    Offset(rows.left + 1, past < 0 ? rows.top + past : rows.bottom + past),
  );
  await stillFrames(tester, 3);
  final lineHeight = viewOf(tester).renderTerminal.lineHeight;
  final frames = <_Frame>[];
  var n = 0;
  for (var i = 0; i < 60; i++) {
    for (var k = 0; k < perFrame; k++) {
      s.terminal.write('\r\nnew ${n++}');
    }
    await tester.pump(const Duration(milliseconds: 16));
    final (top, bottom) = rowsInView(tester);
    final selection = selectionOf(s);
    frames.add((
      text: s.scroll.offset + (lines.evictedCount - evictedAtOpen) * lineHeight,
      top: _label(s, top),
      bottom: _label(s, bottom),
      selection: selection,
      startText: selection == null
          ? ''
          : lines[selection.$1.y].getText().trim(),
      inView: (top, bottom),
    ));
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 500));
  return frames;
}

/// How many lines come after `row [label]` in the buffer.
int _rowsAfter(TermSession s, int label) {
  final lines = s.terminal.buffer.lines;
  for (var y = lines.length - 1; y >= 0; y--) {
    if (_label(s, y) == label) return lines.length - 1 - y;
  }
  throw StateError('no row $label');
}

/// How far each frame of [frames] moved the view, in text terms.
List<double> _steps(List<_Frame> frames) => [
  for (var i = 1; i < frames.length; i++) frames[i].text - frames[i - 1].text,
];

/// Holds above the top quietly, then again with [perFrame] lines a frame,
/// in a terminal that has shown [rows] numbered lines; checks the text
/// moves up every frame at the quiet pace and the selection runs from the
/// pinned start back to the top row.
Future<void> _heldAbove(WidgetTester tester, int rows, int perFrame) async {
  final (_, s) = await openTerminal(tester, replay: numberedRows(rows));
  final quiet = await _hold(tester, s, past: -50, perFrame: 0);
  final streaming = await _hold(tester, s, past: -50, perFrame: perFrame);
  final quietSteps = _steps(quiet);
  final steps = _steps(streaming);
  for (var i = 0; i < steps.length; i++) {
    expect(steps[i], closeTo(quietSteps[i], 0.01), reason: 'frame $i');
    expect(steps[i], lessThan(0), reason: 'frame $i moves up');
  }
  for (var i = 1; i < streaming.length; i++) {
    expect(
      streaming[i].top,
      lessThanOrEqualTo(streaming[i - 1].top),
      reason: 'frame $i: older text, never newer',
    );
  }
  expect(streaming.last.top, quiet.last.top);
  for (final (i, f) in streaming.indexed) {
    final (start, end) = f.selection!;
    expect(f.startText, 'row 1010', reason: 'frame $i');
    expect(start.x, 1, reason: 'frame $i');
    expect(end, CellOffset(0, f.inView.$1), reason: 'frame $i');
    expect(end.y, lessThan(start.y), reason: 'frame $i');
  }
}

/// The same below the bottom: the text moves down by the step, and the
/// selection runs from the pinned start to the bottom row.
Future<void> _heldBelow(WidgetTester tester, int rows, int perFrame) async {
  final (_, s) = await openTerminal(tester, replay: numberedRows(rows));
  final quiet = await _hold(tester, s, past: 50, perFrame: 0);
  final streaming = await _hold(tester, s, past: 50, perFrame: perFrame);
  final quietSteps = _steps(quiet);
  final steps = _steps(streaming);
  for (var i = 0; i < steps.length; i++) {
    expect(steps[i], closeTo(quietSteps[i], 0.01), reason: 'frame $i');
    expect(steps[i], greaterThan(0), reason: 'frame $i moves down');
  }
  expect(streaming.last.bottom, quiet.last.bottom);
  for (final (i, f) in streaming.indexed) {
    final (start, end) = f.selection!;
    expect(f.startText, 'row 1010', reason: 'frame $i');
    expect(start.x, 0, reason: 'frame $i');
    // The pointer is over the first column: the end is after its cell.
    expect(end, CellOffset(1, f.inView.$2), reason: 'frame $i');
    expect(end.y, greaterThan(start.y), reason: 'frame $i');
  }
}

/// Holds [past] px past an edge, far enough that each frame's step is the
/// cap of three rows, with exactly three lines dropped a frame: the step
/// and the dropped lines are the same height, so the view's offset before
/// layout is where the tick goes. Every frame still moves the text by the
/// step at most, and only the way the pointer asks.
Future<void> _heldAtTheCap(WidgetTester tester, double past) async {
  final (_, s) = await openTerminal(tester, replay: numberedRows(10100));
  final lineHeight = viewOf(tester).renderTerminal.lineHeight;
  final frames = await _hold(tester, s, past: past, perFrame: 3);
  for (final (i, step) in _steps(frames).indexed) {
    final rows = step / lineHeight;
    expect(rows.abs(), lessThanOrEqualTo(3.001), reason: 'frame $i: $rows');
    if (past > 0) {
      expect(rows, greaterThanOrEqualTo(0), reason: 'frame $i: $rows');
    } else {
      expect(rows, lessThanOrEqualTo(0), reason: 'frame $i: $rows');
    }
  }
}

void main() {
  // 10,100 lines: the scrollback is full from the start.
  const full = 10100;
  // 3,000 lines: nothing is dropped.
  const roomy = 3000;

  group('held past the edge with the scrollback full', () {
    testWidgets('above the top, 4 lines a frame: the text moves up at the '
        'quiet pace, and the selection runs back from its start', (
      tester,
    ) async {
      await _heldAbove(tester, full, 4);
    });

    testWidgets('above the top, a line a frame: the same', (tester) async {
      await _heldAbove(tester, full, 1);
    });

    testWidgets('below the bottom, 4 lines a frame: the text moves down by '
        'the step and no more', (tester) async {
      await _heldBelow(tester, full, 4);
    });

    testWidgets('below the bottom, a line a frame: the same', (tester) async {
      await _heldBelow(tester, full, 1);
    });

    testWidgets('150 px below the bottom, 3 lines a frame: each frame moves '
        'the text down by three rows at most', (tester) async {
      await _heldAtTheCap(tester, 150);
    });

    testWidgets('150 px above the top, 3 lines a frame: each frame moves the '
        'text up by three rows at most', (tester) async {
      await _heldAtTheCap(tester, -150);
    });

    testWidgets('past the top, back inside while lines are dropped, then '
        'past again: no frame moves more than the cap', (tester) async {
      // The scroll forgets, as it starts again, the lines dropped while it
      // was stopped: the package has already moved the view for them.
      final (_, s) = await openTerminal(tester, replay: numberedRows(full));
      final lineHeight = viewOf(tester).renderTerminal.lineHeight;
      final lines = s.terminal.buffer.lines;
      double text() => s.scroll.offset / lineHeight + lines.evictedCount;
      final at = lines.length - 1 - _rowsAfter(s, 6000);
      await scrollToRow(tester, s, at);
      final g = await pressAt(tester, CellOffset(0, at + 10));
      final rows = rowsRect(tester);
      final above = Offset(rows.left + 1, rows.top - 50);
      await g.moveTo(above);
      await stillFrames(tester, 5);
      await g.moveTo(rows.center);
      var n = 0;
      for (var i = 0; i < 10; i++) {
        for (var k = 0; k < 20; k++) {
          s.terminal.write('\r\nnew ${n++}');
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.moveTo(above);
      var last = text();
      for (var i = 0; i < 10; i++) {
        for (var k = 0; k < 4; k++) {
          s.terminal.write('\r\nnew ${n++}');
        }
        await tester.pump(const Duration(milliseconds: 16));
        final step = text() - last;
        last = text();
        expect(step, lessThanOrEqualTo(0.001), reason: 'frame $i: $step');
        expect(step, greaterThanOrEqualTo(-3.001), reason: 'frame $i: $step');
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('at the end, output a frame apart keeps the view at the end '
        'and the selection to its last line', (tester) async {
      final (_, s) = await openTerminal(tester, replay: numberedRows(full));
      final g = await pressAt(tester, CellOffset(0, topRow(tester, s) + 2));
      final rows = rowsRect(tester);
      await g.moveTo(Offset(rows.right - 1, rows.bottom + 30));
      await stillFrames(tester, 20);
      for (var i = 0; i < 10; i++) {
        s.terminal.write('\r\nnew ${2 * i}\r\nnew ${2 * i + 1}');
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          s.scroll.offset,
          s.scroll.position.maxScrollExtent,
          reason: 'write $i',
        );
        final lastLine = s.terminal.buffer.lines.length - 1;
        expect(selectionOf(s)?.$2.y, lastLine, reason: 'write $i');
      }
      await stillFrames(tester, 5);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
    });
  });

  group('held past the edge with room in the scrollback, as before', () {
    testWidgets('above the top, 4 lines a frame', (tester) async {
      await _heldAbove(tester, roomy, 4);
    });

    testWidgets('above the top, a line a frame', (tester) async {
      await _heldAbove(tester, roomy, 1);
    });

    testWidgets('below the bottom, 4 lines a frame', (tester) async {
      await _heldBelow(tester, roomy, 4);
    });

    testWidgets('below the bottom, a line a frame', (tester) async {
      await _heldBelow(tester, roomy, 1);
    });
  });
}
