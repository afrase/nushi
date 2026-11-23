import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/diff_comment_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/tokens.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// The + on lines whose numbers fill the gutter (three digits and more):
// it covers no digit of either column, in either view, on either side,
// and a click on it still opens the comment box.

/// A file of [count] lines whose line [line] (1-based) changed: its
/// gutter is as wide as [count]'s digits (three at least).
(String, String) _texts(int count, int line) {
  final old = [for (var i = 1; i <= count; i++) '$i'].join('\n');
  final lines = old.split('\n');
  lines[line - 1] = '$line changed';
  return (old, lines.join('\n'));
}

/// The hovered lines, each in a file only as long as it needs: the number
/// is as wide as the gutter's numbers. 10250 is past what `DiffBox` diffs
/// ([maxDiffLines]), so these build the view themselves.
const _lines = [(7, 12), (42, 60), (128, 150), (1204, 1210), (10250, 10260)];

final Finder _button = find.byKey(const ValueKey('diff-comment-button'));

/// The diff of [count] lines with [line] changed, as `DiffBox` shows one
/// that takes comments.
DiffViewController _diff(
  WidgetTester tester,
  int count,
  int line,
  Tokens tokens,
) {
  final (old, neu) = _texts(count, line);
  final diff = TextDiff.compute(old, neu, path: 'long.txt');
  final c = DiffViewController(
    document: diff.document,
    lines: diff.lines,
    theme: diffTheme(tokens),
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  addTearDown(c.dispose);
  return c;
}

Widget _noInlay(BuildContext context, InlaySpec spec) =>
    const SizedBox.shrink();

Widget _view(DiffViewController c, {required bool unified, Tokens? tokens}) {
  final theme = diffTheme(tokens ?? Tokens.dark);
  return themed(
    DiffCommentButton(
      controller: c,
      unified: unified,
      theme: theme,
      child: unified
          ? UnifiedDiff(controller: c, theme: theme, inlayBuilder: _noInlay)
          : SideBySideDiff(controller: c, theme: theme, inlayBuilder: _noInlay),
    ),
    tokens: tokens ?? Tokens.dark,
  );
}

/// Where [line]'s numbers are, on screen: each column's text rect (one in
/// a pane, the old and new in the unified view).
List<Rect> _numbers(
  WidgetTester tester,
  DiffViewController c,
  int line, {
  required bool unified,
  PaneSide side = PaneSide.neu,
}) {
  final g = unified ? c.unifiedGeometry : c.geometry(side);
  final s = unified ? c.unifiedScroll : c.scroll(side);
  final row = unified ? c.unifiedRows.rowOf(side, line - 1) : line - 1;
  final pane = unified
      ? tester.getTopLeft(find.byType(UnifiedDiff))
      : tester.getTopLeft(find.byType(DiffPane).at(side.index));
  final m = unified ? c.resources.unifiedGutter : c.resources.gutter;
  final top = pane.dy + g.topOfRow(row) - s.position.pixels;
  // Right-aligned on the column's right edge, one advance a digit.
  final width = '$line'.length * c.resources.advance;
  return [
    for (final right in {m.oldNumberRight, m.numberRight})
      Rect.fromLTWH(
        pane.dx + right - width,
        top,
        width,
        c.resources.lineHeight,
      ),
  ];
}

/// Shows [line] and puts the pointer on its number, in the gutter, where
/// the package would draw its own +.
Future<void> _hover(
  WidgetTester tester,
  DiffViewController c,
  TestGesture mouse,
  int line, {
  required bool unified,
  PaneSide side = PaneSide.neu,
}) async {
  c.jumpToLine(side, line - 1, viewportY: 60);
  await tester.pump();
  final number = _numbers(tester, c, line, unified: unified, side: side);
  await mouse.moveTo(number.last.center);
  await tester.pump();
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

void main() {
  setUpAll(loadFonts);

  for (final unified in [false, true]) {
    final view = unified ? 'unified' : 'side by side';
    for (final (line, count) in _lines) {
      for (final side in unified ? [PaneSide.neu] : PaneSide.values) {
        testWidgets('$view: the + on line $line (${side.name}) covers none '
            'of its numbers', (tester) async {
          viewport(tester, Size(unified ? 520 : 1000, 300));
          final c = _diff(tester, count, line, Tokens.dark);
          await tester.pumpWidget(_view(c, unified: unified));
          await tester.pump();
          final mouse = await _mouse(tester);
          await _hover(tester, c, mouse, line, unified: unified, side: side);
          expect(_button, findsOne);
          final button = tester.getRect(_button);
          final numbers = _numbers(
            tester,
            c,
            line,
            unified: unified,
            side: side,
          );
          for (final number in numbers) {
            expect(button.overlaps(number), isFalse, reason: '$number');
          }
          // On the row, inside the gutter: a press there reaches the
          // numbers' selection.
          expect(
            (button.center.dy - numbers.last.center.dy).abs(),
            lessThan(1),
          );
          final pane = unified
              ? tester.getTopLeft(find.byType(UnifiedDiff)).dx
              : tester.getTopLeft(find.byType(DiffPane).at(side.index)).dx;
          final m = unified ? c.resources.unifiedGutter : c.resources.gutter;
          expect(button.left, greaterThanOrEqualTo(pane));
          expect(button.right, lessThanOrEqualTo(pane + m.gutterWidth));
        });
      }
    }
  }

  // DiffBox's own, on a four-digit line: the click goes through to the
  // numbers wherever the + sits.
  for (final unified in [false, true]) {
    testWidgets('${unified ? 'unified' : 'side by side'}: a click on the + '
        'of line 1204 opens its comment box', (tester) async {
      viewport(tester, Size(unified ? 520 : 1000, 400));
      final (old, neu) = _texts(1210, 1204);
      await tester.pumpWidget(
        themed(
          DiffBox(
            FileChange(path: 'long.txt', oldText: old, newText: neu),
            fit: false,
            review: (chat: 'c', where: 'uncommitted', agent: 'Claude'),
          ),
        ),
      );
      await tester.pump();
      final c = unified
          ? tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller
          : tester
                .widget<SideBySideDiff>(find.byType(SideBySideDiff))
                .controller;
      final mouse = await _mouse(tester);
      await _hover(tester, c, mouse, 1204, unified: unified);
      await mouse.down(tester.getCenter(_button));
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(ReviewCommentBox), findsOne);
      expect(find.text('Line 1204'), findsOne);
    });
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    if (rendering) ('light', Tokens.light),
  ]) {
    for (final unified in [false, true]) {
      for (final (line, count) in _lines) {
        final view = unified ? 'unified' : 'side';
        testWidgets('renders: the + on line $line ($name, $view)', (
          tester,
        ) async {
          viewport(tester, Size(unified ? 520 : 1000, 160), ratio: 2);
          final c = _diff(tester, count, line, tokens);
          await tester.pumpWidget(_view(c, unified: unified, tokens: tokens));
          await tester.pump();
          final mouse = await _mouse(tester);
          await _hover(tester, c, mouse, line, unified: unified);
          expect(_button, findsOne);
          await render(
            tester,
            find.byType(MaterialApp),
            'diff-plus-$view-$line-$name',
          );
        });
      }
    }
  }
}
