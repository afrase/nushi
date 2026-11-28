import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/theme/tokyo_night.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// A selection in the file viewer keeps its start while the find's query
// changes under it: a line that holds a hit is split into runs at the
// hit's edges (issue 117), and a new split must not lose the selection,
// or a shift-click that extends it starts from the wrong line.

/// Made-up Go: "total" on several lines, "xs" on two others.
const _code =
    'package tally\n'
    '\n'
    '// total is what Sum gives back.\n'
    'func Sum(xs []int) int {\n'
    '\ttotal := 0 // the total so far\n'
    '\tfor _, x := range xs {\n'
    '\t\ttotal += x\n'
    '\t}\n'
    '\treturn total\n'
    '}\n';

Finder _line(String text) =>
    find.textContaining(text, findRichText: true).first;

/// The viewer showing [_code], its find open on "total".
Future<FindSlot> _open(WidgetTester tester) async {
  viewport(tester, const Size(560, 260));
  final slot = FindSlot();
  await tester.pumpWidget(
    themed(
      tokens: tokyoNightDark,
      banner: false,
      SizedBox(
        width: 520,
        height: 230,
        child: FindSlotScope(
          slot: slot,
          child: const SourceView(_code, path: 'tally.go'),
        ),
      ),
    ),
  );
  await untilReal(
    tester,
    () => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((r) => r.text.toPlainText().contains('// total is')),
  );
  slot.view!
    ..open()
    ..query = 'total';
  await tester.pumpAndSettle();
  return slot;
}

/// Drags from the start of the line holding [from] to the end of the
/// one holding [to].
Future<void> _select(WidgetTester tester, String from, String to) async {
  final start = tester.getRect(_line(from));
  final end = tester.getRect(_line(to));
  final drag = await tester.startGesture(
    start.topLeft + const Offset(1, 6),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await drag.moveTo(Offset(end.right - 2, end.top + 6));
  await tester.pump();
  await drag.up();
  await tester.pumpAndSettle();
}

/// A shift-click at the end of the line holding [text].
Future<void> _shiftClickEnd(WidgetTester tester, String text) async {
  final end = tester.getRect(_line(text));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final click = await tester.startGesture(
    Offset(end.right - 2, end.top + 6),
    kind: PointerDeviceKind.mouse,
  );
  await click.up();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

Future<String> _copy(WidgetTester tester) async {
  final copied = clipboardCopies(tester);
  await press(tester, LogicalKeyboardKey.keyC, cmd: true);
  expect(copied, isNotEmpty, reason: 'something was copied');
  return copied.last;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a selection over three lines keeps its start while the query '
      'changes twice; a shift-click extends it from there', (tester) async {
    final slot = await _open(tester);
    await _select(tester, '// total is', 'the total so far');
    // Typed in the find's field, as a user changes it, then set.
    await tester.enterText(find.byType(EditableText), 'xs');
    await tester.pumpAndSettle();
    expect(slot.view!.query, 'xs');
    slot.view!.query = 'tot';
    await tester.pumpAndSettle();
    await _shiftClickEnd(tester, 'return total');
    expect(
      await _copy(tester),
      '// total is what Sum gives back.\n'
      'func Sum(xs []int) int {\n'
      '\ttotal := 0 // the total so far\n'
      '\tfor _, x := range xs {\n'
      '\t\ttotal += x\n'
      '\t}\n'
      '\treturn total\n',
    );
  }, variant: onMac);

  testWidgets('a drag that goes on after the query changed keeps its start', (
    tester,
  ) async {
    final slot = await _open(tester);
    final start = tester.getRect(_line('// total is'));
    final drag = await tester.startGesture(
      start.topLeft + const Offset(1, 6),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final mid = tester.getRect(_line('the total so far'));
    await drag.moveTo(Offset(mid.right - 2, mid.top + 6));
    await tester.pump();
    slot.view!.query = 'xs';
    await tester.pumpAndSettle();
    final end = tester.getRect(_line('return total'));
    await drag.moveTo(Offset(end.right - 2, end.top + 6));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(await _copy(tester), startsWith('// total is what Sum'));
  }, variant: onMac);
}
