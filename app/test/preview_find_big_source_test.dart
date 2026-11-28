import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/line_search.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/source_view.dart';

import 'big_sql.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a large read-only source: a keystroke doesn't wait for the whole
// file to be looked through; the search goes on between frames, a later
// query drops an earlier one's, and past 10,000 matches the bar says so.

/// Two megabytes of a made-up dump.
final String _dump = bigSql(2 << 20);

/// [query]'s matches in [text] as the view counts them: in each line's
/// first 5000 characters, case aside.
int _matches(String text, String query) => [
  for (final line in text.split('\n'))
    query
        .allMatches(
          (line.length > 5000 ? line.substring(0, 5000) : line).toLowerCase(),
        )
        .length,
].fold(0, (a, b) => a + b);

Future<Daemon> _open(WidgetTester tester) async {
  final (d, _) = await openEditor(
    tester,
    {'dump.sql': utf8.encode(_dump)},
    open: const ['dump.sql'],
    readOnly: const {'dump.sql'},
  );
  expect(find.byType(SourceView), findsOne);
  await tester.tap(
    find.textContaining('CREATE TABLE', findRichText: true).first,
  );
  await tester.pumpAndSettle();
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  return d;
}

/// Types [q] in the bar as a key does: the field's text changes, and no
/// frame follows yet.
void _key(WidgetTester tester, String q) => tester.testTextInput.enterText(q);

void main() {
  testWidgets("a keystroke doesn't look through the whole file; the count "
      'comes once the search ends, and is right', (tester) async {
    final d = await _open(tester);
    LineSearch.looked = 0;
    _key(tester, 'selxq');
    // A slice, and at most a line past it, not the file.
    expect(LineSearch.looked, lessThanOrEqualTo(sliceChars + 5001));
    expect(barFind(tester).count, '', reason: 'nothing counted yet');
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOne);
    await look(tester, 'sel');
    final n = _matches(_dump, 'sel');
    expect(n, inInclusiveRange(1, 10000));
    expect(find.text('1 of $n'), findsOne);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("a later query drops an earlier one's search: its count "
      'never reaches the bar', (tester) async {
    final d = await _open(tester);
    final counts = <String>[];
    final f = barFind(tester);
    void heard() => counts.add(f.count);
    f.addListener(heard);
    addTearDown(() => f.removeListener(heard));
    _key(tester, 'sel');
    _key(tester, 'selxq');
    await tester.pumpAndSettle();
    final sel = _matches(_dump, 'sel');
    expect(sel, greaterThan(0));
    expect(counts.where((c) => c.endsWith(' of $sel')), isEmpty);
    expect(f.count, 'None');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('past 10,000 matches the bar says so; a line in sight past '
      'them shows its own', (tester) async {
    final d = await _open(tester);
    await look(tester, 's');
    expect(_matches(_dump, 's'), greaterThan(10000));
    expect(find.text('1 of 10,000+'), findsOne);
    expect(barFind(tester).hits, hasLength(10000));
    // The file's end, far past the 10,000th match.
    final down = tester
        .widget<Scrollable>(
          find
              .descendant(
                of: find.byType(SourceView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .controller!;
    down.jumpTo(down.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final shown = tester
        .widgetList<LineHits>(find.byType(LineHits))
        .where((l) => l.hits.isNotEmpty);
    expect(shown, isNotEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('⏎ pressed before the search ends goes on from its first '
      'match once it ends', (tester) async {
    final d = await _open(tester);
    _key(tester, 'sel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of ${_matches(_dump, 'sel')}'), findsOne);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a search still going when the view closes touches nothing '
      'after', (tester) async {
    final d = await _open(tester);
    LineSearch.looked = 0;
    _key(tester, 'sel');
    expect(LineSearch.looked, lessThan(_dump.length), reason: 'still going');
    // Gone before its next slice runs.
    await closeView(tester, d);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: onMac);

  testWidgets("while a new query's search runs, the bar doesn't say the "
      "last one's matches went past 10,000", (tester) async {
    final d = await _open(tester);
    await look(tester, 's');
    expect(find.text('1 of 10,000+'), findsOne);
    _key(tester, 'selxq');
    final f = barFind(tester) as LaterFind;
    expect(f.looking, isTrue);
    expect(f.count, isNot(contains('+')));
    await tester.pumpAndSettle();
    expect(f.count, 'None');
    await endEditor(tester, d);
  }, variant: onMac);
}
