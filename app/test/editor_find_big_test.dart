import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';
import 'package:re_editor/re_editor.dart';

import 'big_sql.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// ⌘F in the editor on a file of long lines (a dump's extended inserts):
// re_editor paints each match it's given, every frame, at a cost that
// grows with its line's length, so it's given only those in sight (and a
// screen's worth around them), not the tens of thousands found.

/// A dump of a quarter of a megabyte: a few lines of tens of kilobytes.
final String _dump = bigSql(256 << 10, rows: 3000);

/// The same, in more lines (of about ten kilobytes): a screen holds one
/// or two of them, wrapped.
final String _longer = bigSql(256 << 10, rows: 300);

/// [q]'s matches in [_dump], case aside.
int _count(String q) => q.allMatches(_dump.toLowerCase()).length;

/// What re_editor was last given to paint.
List<CodeLineSelection> _painted(WidgetTester tester) =>
    tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find.painted;

Future<EditorFind> _look(WidgetTester tester, String q) async {
  final f = tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find;
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    q,
  );
  await untilReal(tester, () => !f.looking);
  await tester.pumpAndSettle();
  return f;
}

void main() {
  testWidgets('re_editor paints the matches in sight, not every one found; '
      'the count is every one', (tester) async {
    final (d, _) = await openEditor(
      tester,
      {'dump.sql': utf8.encode(_dump)},
      open: const ['dump.sql'],
    );
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    editOf(d, 'dump.sql').controller.selection =
        const CodeLineSelection.collapsed(index: 0, offset: 0);
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    final f = await _look(tester, 's');
    final n = _count('s');
    expect(n, greaterThan(10000));
    expect(f.count, '1 of $n');
    final painted = _painted(tester);
    expect(painted, isNotEmpty);
    expect(painted.length, lessThan(3000));
    // Every match on the lines in sight, as far as they show, is there:
    // the first line's are all in sight, but for the current one, which
    // shows as the selection.
    final first = [
      for (final m in painted)
        if (m.startIndex == 0) m,
    ];
    final line = _dump.split('\n').first.toLowerCase();
    expect(first, hasLength('s'.allMatches(line).length - 1));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('scrolled to the end, the matches there are painted', (
    tester,
  ) async {
    final (d, _) = await openEditor(
      tester,
      {'dump.sql': utf8.encode(_longer)},
      open: const ['dump.sql'],
    );
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await _look(tester, 'settled');
    final down = tester
        .widget<Scrollable>(
          find
              .descendant(
                of: find.byType(CodeEditor),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .controller!;
    // re_editor's extent grows as it lays the long lines out: to the end
    // once it stops growing.
    for (var was = -1.0; down.position.maxScrollExtent != was;) {
      was = down.position.maxScrollExtent;
      down.jumpTo(was);
      await tester.pumpAndSettle();
    }
    // The last line with a match, a long one, at the end of the view.
    final last = _longer
        .split('\n')
        .lastIndexWhere((l) => l.toLowerCase().contains('settled'));
    final painted = _painted(tester);
    expect(painted.where((m) => m.startIndex == last), isNotEmpty);
    expect(painted.length, lessThan(3000));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("a long wrapped line's matches are painted half a screen "
      'past what shows, above and below, every one in sight', (tester) async {
    wrapLines.value = true;
    const unit = "('settled', 'see the earlier entry', 'select', 42), ";
    final line = 'INSERT INTO t VALUES ${unit * ((256 << 10) ~/ unit.length)}';
    final (d, _) = await openEditor(
      tester,
      {'one.sql': utf8.encode('$line\nend\n')},
      open: const ['one.sql'],
    );
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    final f = await _look(tester, 's');
    // Into the line, a screen or two from its top.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(CodeEditor), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    final shows = f.sight.inSight.cut[0]!;
    final inSight = [
      for (final m in 's'.allMatches(line.toLowerCase()))
        if (m.start >= shows.start && m.end <= shows.end) m.start,
    ];
    expect(inSight.length, greaterThan(20));
    final painted = {
      for (final m in _painted(tester))
        if (m.startIndex == 0) m.startOffset,
    };
    // All in sight but the current one, which shows as the selection.
    expect(inSight.where((at) => !painted.contains(at)).length, lessThan(2));
    // A screen of them, and half a screen's more above and below.
    expect(painted.length, lessThan(inSight.length * 2.5));
    await endEditor(tester, d);
  }, variant: onMac);
}
