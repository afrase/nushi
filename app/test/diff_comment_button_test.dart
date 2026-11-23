import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/theme/tokens.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// The + at the start of the line under the pointer, on a diff that takes
// comments: it shows, moves with the pointer, moves nothing, and a click
// on it opens the box a click on the line's number opens.

final String _old = [for (var i = 1; i <= 12; i++) 'line $i'].join('\n');

final _change = FileChange(
  path: 'calc.go',
  oldText: _old,
  newText: _old.replaceFirst('line 5', 'line five'),
);

Widget _box({bool review = true, Tokens tokens = Tokens.dark}) => themed(
  DiffBox(
    _change,
    fit: false,
    review: review ? (chat: 'c', where: 'uncommitted', agent: 'Claude') : null,
  ),
  tokens: tokens,
);

final Finder _button = find.byKey(const ValueKey('diff-comment-button'));

DiffViewController _controller(WidgetTester tester) =>
    find.byType(UnifiedDiff).evaluate().isNotEmpty
    ? tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller
    : tester.widget<SideBySideDiff>(find.byType(SideBySideDiff)).controller;

/// The middle of [row]'s code, on screen: in the unified view, or in the
/// pane of [side] side by side.
Offset _row(WidgetTester tester, int row, {PaneSide side = PaneSide.neu}) {
  final c = _controller(tester);
  final unified = find.byType(UnifiedDiff).evaluate().isNotEmpty;
  final g = unified ? c.unifiedGeometry : c.geometry(side);
  final s = unified ? c.unifiedScroll : c.scroll(side);
  final y = g.topOfRow(row) - s.position.pixels + c.resources.lineHeight / 2;
  final box = tester.getRect(
    find.byType(unified ? UnifiedDiff : SideBySideDiff),
  );
  final x = !unified && side == PaneSide.old ? box.width / 4 : box.width * .75;
  return box.topLeft + Offset(unified ? box.width / 2 : x, y);
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
    testWidgets('$view: hovering a line shows the +, which moves with the '
        'pointer and moves nothing', (tester) async {
      viewport(tester, Size(unified ? 500 : 1000, 400));
      await tester.pumpWidget(_box());
      await tester.pump();
      expect(_button, findsNothing);
      // The diff paints its own text: where its rows and code start says
      // whether anything moved.
      final diff = find.byType(unified ? UnifiedDiff : SideBySideDiff);
      (Rect, double, double, double) layout() {
        final c = _controller(tester);
        final g = unified ? c.unifiedGeometry : c.geometry(PaneSide.neu);
        final s = unified ? c.unifiedScroll : c.scroll(PaneSide.neu);
        final m = unified ? c.resources.unifiedGutter : c.resources.gutter;
        return (tester.getRect(diff), g.topOfRow(2), s.offset, m.codeX);
      }

      final before = layout();
      final mouse = await _mouse(tester);
      await mouse.moveTo(_row(tester, 2));
      await tester.pump();
      expect(_button, findsOne);
      // On the hovered row, centred on the change marker's column, right
      // of the numbers.
      final at = tester.getRect(_button);
      expect((at.center.dy - _row(tester, 2).dy).abs(), lessThan(1));
      final pane = unified
          ? tester.getTopLeft(find.byType(UnifiedDiff)).dx
          : tester.getTopLeft(find.byType(DiffPane).last).dx;
      final res = _controller(tester).resources;
      final m = unified ? res.unifiedGutter : res.gutter;
      expect(at.center.dx, closeTo(pane + m.markerX + res.advance / 2, 0.01));
      expect(layout(), before);
      await mouse.moveTo(_row(tester, 6));
      await tester.pump();
      expect(_button, findsOne);
      expect(
        (tester.getCenter(_button).dy - _row(tester, 6).dy).abs(),
        lessThan(1),
      );
      // Off the diff it goes.
      await mouse.moveTo(const Offset(-10, -10));
      await tester.pump();
      expect(_button, findsNothing);
    });

    testWidgets('$view: a click on the + opens the comment box for its '
        'line, as a click on its number does', (tester) async {
      viewport(tester, Size(unified ? 500 : 1000, 400));
      await tester.pumpWidget(_box());
      await tester.pump();
      final mouse = await _mouse(tester);
      await mouse.moveTo(_row(tester, 2));
      await tester.pump();
      final plus = tester.getCenter(_button);
      await mouse.down(plus);
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(ReviewCommentBox), findsOne);
      expect(find.text('Line 3'), findsOne);
      // The new side's pane, side by side.
      if (!unified) {
        expect(
          tester.getTopLeft(find.byType(ReviewCommentBox)).dx,
          greaterThan(500),
        );
      }
    });
  }

  testWidgets("side by side, the old pane's + comments on the old side", (
    tester,
  ) async {
    viewport(tester, const Size(1000, 400));
    await tester.pumpWidget(_box());
    await tester.pump();
    final mouse = await _mouse(tester);
    await mouse.moveTo(_row(tester, 4, side: PaneSide.old));
    await tester.pump();
    expect(tester.getRect(_button).right, lessThan(100));
    await mouse.down(tester.getCenter(_button));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Line 5'), findsOne);
    expect(tester.getTopLeft(find.byType(ReviewCommentBox)).dx, lessThan(500));
  });

  testWidgets('a drag from the + selects lines, as one over the numbers '
      'does', (tester) async {
    viewport(tester, const Size(1000, 400));
    await tester.pumpWidget(_box());
    await tester.pump();
    final mouse = await _mouse(tester);
    await mouse.moveTo(_row(tester, 1));
    await tester.pump();
    await mouse.down(tester.getCenter(_button));
    await tester.pump();
    await mouse.moveTo(
      Offset(tester.getCenter(_button).dx, _row(tester, 3).dy),
    );
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Lines 2–4'), findsOne);
  });

  testWidgets('a diff that takes no comments has no +', (tester) async {
    viewport(tester, const Size(1000, 400));
    await tester.pumpWidget(_box(review: false));
    await tester.pump();
    final mouse = await _mouse(tester);
    await mouse.moveTo(_row(tester, 2));
    await tester.pump();
    expect(_button, findsNothing);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    if (rendering) ('light', Tokens.light),
  ]) {
    for (final unified in [false, true]) {
      testWidgets('renders: the + hovered ($name, '
          '${unified ? 'unified' : 'side by side'})', (tester) async {
        viewport(tester, Size(unified ? 520 : 1000, 300));
        await tester.pumpWidget(_box(tokens: tokens));
        await tester.pump();
        final mouse = await _mouse(tester);
        await mouse.moveTo(_row(tester, 4));
        await tester.pump();
        expect(_button, findsOne);
        await render(
          tester,
          find.byType(MaterialApp),
          'diff-plus-${unified ? 'unified' : 'side'}-$name',
        );
      });
    }
  }
}
