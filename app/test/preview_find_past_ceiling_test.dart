import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/line_search.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/source_view.dart';

import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a read-only source with more matches than it keeps (10,000): ⏎
// and ⇧⏎ still reach every one, the search looking on past those kept.

/// How many matches of [_q] the text has: [_each] on each of its lines.
const _rows = 25000;
const _each = 10;

/// The query: [_each] times on each line, nowhere else.
const _q = 'zq';

/// A line's [_each] runs of words, each with [_q] in it.
final String _runs = List.filled(
  _each,
  'alpha $_q beta gamma delta epsilon theta iota kappa lambda omicron rho '
  'sigma tau upsilon',
).join(' ');

/// A made-up export of [_rows] matches, [_each] to a line of about 900
/// characters, line `i` (from 0) numbered.
final String _text = [
  for (var i = 0; i < _rows ~/ _each; i++)
    'line ${'$i'.padLeft(5, '0')}: $_runs',
].join('\n');

/// Where on its line match [k] (from 0) starts.
int _startOf(int k) => 12 + _q.allMatches(_runs).elementAt(k % _each).start;

Future<Daemon> _open(WidgetTester tester) async {
  final (d, _) = await openEditor(
    tester,
    {'rows.txt': utf8.encode(_text)},
    open: const ['rows.txt'],
    readOnly: const {'rows.txt'},
  );
  expect(find.byType(SourceView), findsOne);
  await tester.tap(find.textContaining('line 00001:', findRichText: true));
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  await look(tester, _q);
  expect(find.text('1 of 10,000+'), findsOne);
  return d;
}

/// ⏎, or ⇧⏎ with [back], with no frame after it.
Future<void> _step(WidgetTester tester, {bool back = false}) async {
  if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

/// The current match is match [k] (from 0), the bar says [count], and
/// it's marked as the current one, in sight.
void _expectAt(WidgetTester tester, int k, String count) {
  final f = barFind(tester);
  expect(f.count, count);
  final line = k ~/ _each;
  expect(f.current, '$line:${_startOf(k)}');
  final now = find.byWidgetPredicate(
    (w) => w is LineHits && w.hits.any((h) => h.now),
  );
  expect(now, findsOne);
  final hit = tester.widget<LineHits>(now).hits.singleWhere((h) => h.now);
  expect(hit.start, _startOf(k));
  final p = hitParagraphIn(tester.renderObject(now))!;
  expect(p.text.toPlainText(), startsWith('line ${'$line'.padLeft(5, '0')}:'));
  final box = hitBoxes(p, hit.start, hit.end).first;
  expect(inSight(tester, box.shift(p.localToGlobal(Offset.zero))), isTrue);
}

void main() {
  testWidgets('⏎ goes on past the 10,000 matches kept, to the next', (
    tester,
  ) async {
    final d = await _open(tester);
    // From the first, 9,999 steps to the 10,000th, the last kept.
    for (var i = 1; i < findCeiling; i++) {
      await _step(tester);
    }
    await tester.pumpAndSettle();
    _expectAt(tester, 9999, '10000 of 10,000+');
    await _step(tester);
    await tester.pumpAndSettle();
    _expectAt(tester, 10000, '10001 of 20,000+');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("⇧⏎ from the first match goes to the file's last; ⏎ from "
      'there, round to the first', (tester) async {
    final d = await _open(tester);
    await _step(tester, back: true);
    await tester.pumpAndSettle();
    _expectAt(tester, _rows - 1, '$_rows of $_rows');
    await _step(tester);
    await tester.pumpAndSettle();
    _expectAt(tester, 0, '1 of 10,000+');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('steps pressed while it looks on are each taken once, in '
      'order, from where it lands', (tester) async {
    final d = await _open(tester);
    final f = barFind(tester) as LaterFind;
    await _step(tester, back: true);
    await tester.pumpAndSettle();
    // Back from the end it keeps the last 10,000: the 15,001st on. Back to
    // the first of them, then past it: it looks back, a slice at a time.
    for (var i = 1; i < findCeiling; i++) {
      await _step(tester, back: true);
    }
    await tester.pumpAndSettle();
    _expectAt(tester, 15000, '15001 of $_rows');
    await _step(tester, back: true);
    expect(f.looking, isTrue, reason: 'still looking back');
    await _step(tester, back: true);
    await _step(tester, back: true);
    await _step(tester);
    await tester.pumpAndSettle();
    // Landed on the 15,000th, then one more back: the three taken once.
    _expectAt(tester, 14998, '14999 of 15,000+');
    await endEditor(tester, d);
  }, variant: onMac);
}
