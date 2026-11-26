import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';

import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a read-only source (issue 63): every line is looked in, not only
// those laid out; a step goes to the match's line, sideways too.

/// A log: "needle" twice on line 3, once far down on line 160, once far
/// right on line 170.
final String _log = [
  for (var i = 1; i <= 200; i++)
    switch (i) {
      3 => 'line 3: a needle, then a NEEDLE',
      160 => 'line 160: the far needle',
      170 => 'line 170: ${'x' * 300} wide needle',
      _ => 'line $i: hay',
    },
].join('\n');

Future<Daemon> _open(
  WidgetTester tester, {
  double width = 1700,
  Brightness brightness = Brightness.light,
}) async {
  final (d, _) = await openEditor(
    tester,
    {'build.log': utf8.encode(_log)},
    open: const ['build.log'],
    width: width,
    brightness: brightness,
    readOnly: const {'build.log'},
  );
  expect(find.byType(SourceView), findsOne);
  return d;
}

Finder _line(String text) =>
    find.textContaining(text, findRichText: true).first;

Future<void> _openFind(WidgetTester tester) async {
  await tester.tap(_line('line 10: hay'));
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the source finds in the file; in the prompt box, the '
      'chat', (tester) async {
    final d = await _open(tester);
    expect(find.textContaining('Read-only:'), findsOne);
    await expectRouting(tester, d, _line('line 10: hay'));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("counts every line's matches, case aside; ⏎ and ⇧⏎ step, "
      'round, to lines not laid out; none said plainly', (tester) async {
    final d = await _open(tester);
    await _openFind(tester);
    await look(tester, 'needle');
    expect(find.text('1 of 4'), findsOne);
    expect(barFind(tester).hits, ['2:10', '2:25', '159:18', '169:316']);
    await stepFind(tester);
    await stepFind(tester);
    expect(find.text('3 of 4'), findsOne);
    expect(inSight(tester, tester.getRect(_line('the far needle'))), isTrue);
    await stepFind(tester, back: true);
    await stepFind(tester, back: true);
    expect(find.text('1 of 4'), findsOne);
    expect(inSight(tester, tester.getRect(_line('line 3:'))), isTrue);
    await stepFind(tester, back: true);
    expect(find.text('4 of 4'), findsOne);
    await look(tester, 'thimble');
    expect(find.text('None'), findsOne);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('unwrapped, a match far right scrolls the line sideways', (
    tester,
  ) async {
    wrapLines.value = false;
    final d = await _open(tester);
    await _openFind(tester);
    await look(tester, 'wide needle');
    expect(find.text('1 of 1'), findsOne);
    final across = tester
        .widgetList<SingleChildScrollView>(
          find.descendant(
            of: find.byType(SourceView),
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .firstWhere((v) => v.scrollDirection == Axis.horizontal)
        .controller!;
    expect(across.offset, greaterThan(0));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('closed while a step brings its match into view, nothing '
      'throws', (tester) async {
    final d = await _open(tester);
    await _openFind(tester);
    await look(tester, 'needle');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // its reveal waits
    await closeView(tester, d); // for the frame that closes it
    expect(tester.takeException(), isNull);
  }, variant: onMac);

  testWidgets('the right-click menu has Find…', (tester) async {
    final d = await _open(tester);
    await tester.tap(_line('line 10: hay'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Menu), matching: find.text('Find…')),
    );
    await tester.pumpAndSettle();
    expect(paneBar, findsOne);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('the bar with matches', (tester) async {
    Future<Daemon> open(double w, Brightness b) async {
      final d = await _open(tester, width: w, brightness: b);
      await _openFind(tester);
      await look(tester, 'needle');
      await stepFind(tester);
      return d;
    }

    await renderFind(tester, 'find-source', open);
    for (final b in Brightness.values) {
      final d = await open(1700, b);
      await expectLater(
        find.byType(SourceView),
        matchesGoldenFile('goldens/find_source_${b.name}.png'),
      );
      await endEditor(tester, d);
    }
  }, variant: onMac);

  testWidgets('unwrapped, a line dense with matches paints those in sight, '
      'not the rest', (tester) async {
    wrapLines.value = false;
    final (d, _) = await openEditor(
      tester,
      {'dense.txt': utf8.encode('line 1: ${'zq ' * 1500}\nline 2: end')},
      open: const ['dense.txt'],
      readOnly: const {'dense.txt'},
    );
    await tester.tap(_line('line 2: end'));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await look(tester, 'zq');
    expect(find.text('1 of 1500'), findsOne);
    final dense = find.byWidgetPredicate(
      (w) => w is LineHits && w.hits.length == 1500,
    );
    final view = tester.getRect(find.byType(SourceView));
    final across = tester
        .widgetList<SingleChildScrollView>(
          find.descendant(
            of: find.byType(SourceView),
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .firstWhere((v) => v.scrollDirection == Axis.horizontal)
        .controller!;
    // Scrolled along it: the line is painted again, its matches in sight.
    for (final part in [1 / 3, 2 / 3]) {
      LineHits.painted = 0;
      across.jumpTo(across.position.maxScrollExtent * part);
      await tester.pump();
      final p = hitParagraphIn(tester.renderObject(dense))!;
      final at = p.localToGlobal(Offset.zero);
      final shown = tester
          .widget<LineHits>(dense)
          .hits
          .where(
            (h) => hitBoxes(
              p,
              h.start,
              h.end,
            ).any((b) => view.overlaps(b.shift(at))),
          );
      expect(shown.length, greaterThan(10));
      expect(
        LineHits.painted,
        inInclusiveRange(shown.length, shown.length + 4),
      );
    }
    await endEditor(tester, d);
  }, variant: onMac);
}
