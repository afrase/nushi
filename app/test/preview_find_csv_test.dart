import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_text.dart';

import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a CSV's table (issue 63): every row shown is looked in, the
// header's too, though only those in sight are laid out.

/// Teas: "oolong" in the header, in row 2, in row 100, and past a long
/// cell's ellipsis in row 110.
final String _csv = [
  'name,origin,oolong notes',
  for (var i = 1; i <= 120; i++)
    switch (i) {
      2 => 'Tie Guan Yin,Fujian,a rolled oolong',
      100 => 'Da Hong Pao,Wuyi,a roasted Oolong',
      110 => 'Long one,Taiwan,${'very ' * 12}and at its end oolong',
      _ => 'Tea $i,Somewhere,plain',
    },
].join('\n');

Future<Daemon> _open(
  WidgetTester tester, {
  double width = 1700,
  Brightness brightness = Brightness.light,
}) async {
  final (d, _) = await openEditor(
    tester,
    {'teas.csv': utf8.encode(_csv)},
    open: const ['teas.csv'],
    width: width,
    brightness: brightness,
  );
  expect(find.byType(CsvTable), findsOne);
  return d;
}

Finder get _cell => find.text('Tea 10');

Future<void> _openFind(WidgetTester tester) async {
  await tester.tap(_cell);
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the table finds in the file; in the prompt box, the '
      'chat', (tester) async {
    final d = await _open(tester);
    await expectRouting(tester, d, _cell);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('closed while a step brings its match into view, nothing '
      'throws', (tester) async {
    final d = await _open(tester);
    await _openFind(tester);
    await look(tester, 'oolong');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // its reveal waits
    await closeView(tester, d); // for the frame that closes it
    expect(tester.takeException(), isNull);
  }, variant: onMac);

  testWidgets("counts every row's matches and the header's, case aside; "
      '⏎ and ⇧⏎ step, round, to rows not laid out; none said plainly', (
    tester,
  ) async {
    final d = await _open(tester);
    await _openFind(tester);
    await look(tester, 'oolong');
    expect(find.text('1 of 4'), findsOne);
    expect(barFind(tester).hits, ['0:2:0', '2:2:9', '100:2:10', '110:2:75']);
    expect(find.text('Da Hong Pao'), findsNothing);
    await stepFind(tester);
    await stepFind(tester);
    expect(find.text('3 of 4'), findsOne);
    expect(inSight(tester, tester.getRect(find.text('Da Hong Pao'))), isTrue);
    await stepFind(tester);
    expect(find.text('4 of 4'), findsOne);
    expect(inSight(tester, tester.getRect(find.text('Long one'))), isTrue);
    // Past its cell's ellipsis: the cell is tinted.
    await render(tester, find.byType(NushiApp), 'find-csv-cut-1700-light');
    await stepFind(tester);
    expect(find.text('1 of 4'), findsOne);
    await look(tester, 'matcha');
    expect(find.text('None'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(findBar, findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('the bar with matches', (tester) async {
    Future<Daemon> open(double w, Brightness b) async {
      final d = await _open(tester, width: w, brightness: b);
      await _openFind(tester);
      await look(tester, 'oolong');
      await stepFind(tester);
      return d;
    }

    await renderFind(tester, 'find-csv', open);
    for (final b in Brightness.values) {
      final d = await open(1700, b);
      await expectLater(
        find.byType(CsvTable),
        matchesGoldenFile('goldens/find_csv_${b.name}.png'),
      );
      await endEditor(tester, d);
    }
  }, variant: onMac);
}
