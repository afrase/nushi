import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/markdown_outline.dart';

import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a Markdown file's rendered preview (issue 63): it finds in the
// text as laid out (TextMarks), its bar the transcript's.

/// A note with "teapot" four times (once in code), the last far down.
final String _note = [
  '# Tea notes',
  'The teapot sits on the stove. Warm the TEAPOT first.',
  '```sh\nbrew --teapot\n```',
  for (var i = 1; i <= 40; i++) 'Filler paragraph $i, about leaves and water.',
  'At the very end, the last teapot of the note.',
].join('\n\n');

Future<Daemon> _open(
  WidgetTester tester, {
  double width = 1700,
  Brightness brightness = Brightness.light,
}) async {
  final (d, _) = await openEditor(
    tester,
    {'notes.md': utf8.encode(_note)},
    open: const ['notes.md'],
    width: width,
    brightness: brightness,
  );
  return d;
}

Finder get _text =>
    find.textContaining('Filler paragraph 1,', findRichText: true).first;

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the preview finds in the file; in the prompt box, the '
      'chat', (tester) async {
    final d = await _open(tester);
    await expectRouting(tester, d, _text);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('counts the matches case aside, code too; ⏎ and ⇧⏎ step, '
      'round, the far one brought into view; none said plainly', (
    tester,
  ) async {
    final d = await _open(tester);
    await tester.tap(_text);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await look(tester, 'teapot');
    expect(find.text('1 of 4'), findsOne);
    expect(barFind(tester).hits, hasLength(4));
    final last = find
        .textContaining('the last teapot', findRichText: true)
        .first;
    expect(inSight(tester, tester.getRect(last)), isFalse);
    await stepFind(tester, back: true);
    expect(find.text('4 of 4'), findsOne);
    expect(inSight(tester, tester.getRect(last)), isTrue);
    await stepFind(tester);
    expect(find.text('1 of 4'), findsOne);
    await stepFind(tester);
    await stepFind(tester);
    expect(find.text('3 of 4'), findsOne);
    await look(tester, 'kettle');
    expect(find.text('None'), findsOne);
    expect(barFind(tester).hits, isEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a match at the very top moves out from under the bar', (
    tester,
  ) async {
    // Narrow, the title runs under the bar.
    final d = await _open(tester, width: 720);
    await tester.tap(_text);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await look(tester, 'tea notes');
    expect(find.text('1 of 1'), findsOne);
    final title = find.textContaining('Tea notes', findRichText: true).first;
    expect(inSight(tester, tester.getRect(title)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(findBar, findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('the bar with matches', (tester) async {
    await renderFind(tester, 'find-markdown', (w, b) async {
      final d = await _open(tester, width: w, brightness: b);
      await tester.tap(_text);
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
      await look(tester, 'teapot');
      return d;
    });
    for (final b in Brightness.values) {
      final d = await _open(tester, brightness: b);
      await tester.tap(_text);
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
      await look(tester, 'teapot');
      await stepFind(tester);
      await expectLater(
        find.byType(OutlinedMarkdown),
        matchesGoldenFile('goldens/find_markdown_${b.name}.png'),
      );
      await endEditor(tester, d);
    }
  }, variant: onMac);
}
