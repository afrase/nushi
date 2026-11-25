import 'package:diff_view/diff_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/window_drag_linux.dart';

// The mouse on a diff's code and gutter, by the new side's lines and
// columns, for the tests of selecting and copying text in a diff.

/// A made-up change: line 2 changed, line 3 added.
final totalChange = FileChange(
  path: 'total.go',
  oldText: 'func total(xs []int) int {\n  sum := 0\n  return sum\n}\n',
  newText:
      'func total(xs []int) int {\n  sum := start\n'
      '  for _, x := range xs { sum += x }\n  return sum\n}\n',
);

/// Linux's command key (Control) and window (no menu bar) when the test
/// runs as on Linux, so `press`'s `cmd` is the key the app's Linux build
/// copies with.
void platformKeys() {
  if (defaultTargetPlatform == TargetPlatform.linux) {
    native
      ..conventions = linuxConventions
      ..window = const LinuxWindow();
  }
}

/// The diff view in [within] (the only one when null): unified or side by
/// side, whichever is laid out.
Finder diffView({Finder? within}) {
  Finder of(Type t) => within == null
      ? find.byType(t)
      : find.descendant(of: within, matching: find.byType(t));
  final unified = of(UnifiedDiff);
  return unified.evaluate().isNotEmpty ? unified : of(SideBySideDiff);
}

/// The controller of the diff in [within].
DiffViewController diffController(WidgetTester tester, {Finder? within}) {
  final w = tester.widget(diffView(within: within));
  return w is UnifiedDiff ? w.controller : (w as SideBySideDiff).controller;
}

/// Where column [column] of the new side's [line] is drawn, on screen, a
/// fifth of a character in; with [gutter], the middle of its line number.
Offset codeAt(
  WidgetTester tester,
  int line,
  int column, {
  Finder? within,
  bool gutter = false,
}) {
  final view = diffView(within: within);
  final c = diffController(tester, within: within);
  final unified = tester.widget(view) is UnifiedDiff;
  final box = tester.getRect(view);
  final res = c.resources;
  final g = unified ? c.unifiedGeometry : c.geometry(PaneSide.neu);
  final s = unified ? c.unifiedScroll : c.scroll(PaneSide.neu);
  final row = unified ? c.unifiedRows.rowOf(PaneSide.neu, line) : line;
  final y = g.topOfRow(row) - s.position.pixels + res.lineHeight / 2;
  final m = unified ? res.unifiedGutter : res.gutter;
  final paneLeft = unified
      ? 0.0
      : box.width - (box.width - c.resources.theme.dividerWidth) / 2;
  final x = gutter
      ? m.numberRight - res.advance / 2
      : m.codeX + (column + 0.2) * res.advance - c.horizontal.value;
  return box.topLeft + Offset(paneLeft + x, y);
}

Future<TestGesture> _mouse(WidgetTester tester, Offset at) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: at);
  return mouse;
}

/// The mouse dragged over the code from `(line, column)` [from] to [to].
Future<void> dragCode(
  WidgetTester tester, {
  required (int, int) from,
  required (int, int) to,
  Finder? within,
}) async {
  final a = codeAt(tester, from.$1, from.$2, within: within);
  final b = codeAt(tester, to.$1, to.$2, within: within);
  final mouse = await _mouse(tester, a);
  await mouse.down(a);
  await tester.pump();
  for (var i = 1; i <= 4; i++) {
    await mouse.moveTo(Offset.lerp(a, b, i / 4)!);
    await tester.pump();
  }
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

/// One click of the mouse on [line]'s code at [column].
Future<void> clickCode(
  WidgetTester tester,
  int line,
  int column, {
  Finder? within,
}) async {
  final at = codeAt(tester, line, column, within: within);
  final mouse = await _mouse(tester, at);
  await mouse.down(at);
  await tester.pump();
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

/// A double click of the mouse on [line]'s code at [column].
Future<void> doubleClickCode(
  WidgetTester tester,
  int line,
  int column, {
  Finder? within,
}) async {
  // A click before, on the double click's timer still, would count.
  await tester.pump(kDoubleTapTimeout * 2);
  final at = codeAt(tester, line, column, within: within);
  final mouse = await _mouse(tester, at);
  for (var i = 0; i < 2; i++) {
    await mouse.down(at);
    await tester.pump(const Duration(milliseconds: 20));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 20));
  }
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

/// The mouse dragged down the line numbers from [first] to [last].
Future<void> dragGutter(
  WidgetTester tester,
  int first,
  int last, {
  Finder? within,
}) async {
  final a = codeAt(tester, first, 0, within: within, gutter: true);
  final b = codeAt(tester, last, 0, within: within, gutter: true);
  final mouse = await _mouse(tester, a);
  await mouse.down(a);
  await tester.pump();
  await mouse.moveTo(b);
  await tester.pump();
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}
