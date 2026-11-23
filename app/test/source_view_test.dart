import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/source_view.dart';

import 'harness.dart';

/// The spans the source shows: more once it is highlighted.
int _spans(WidgetTester tester) {
  var n = 0;
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((_) {
      n++;
      return true;
    });
  }
  return n;
}

Widget _host(String text) => themed(SourceView(text, path: 'a.dart'));

Future<void> _selectAllCopy(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

void main() {
  const code = 'void main() {\n  final x = 1;\n  print("hi \$x");\n}\n';

  testWidgets('a rebuild with the same text while it highlights keeps the '
      'highlighting', (tester) async {
    await tester.pumpWidget(_host(code));
    final plain = _spans(tester);
    // PreviewBody decodes the file again on each build: an equal string,
    // not the same one.
    await tester.pumpWidget(_host(String.fromCharCodes(code.codeUnits)));
    await untilReal(
      tester,
      () => _spans(tester) > plain,
      limit: const Duration(seconds: 5),
    );
  });

  testWidgets('wrap off, a long line has room for all of it', (tester) async {
    viewport(tester, const Size(600, 400));
    final long = 'x' * 1000;
    await tester.pumpWidget(
      themed(SourceView('$long\nshort\n', path: 'a.txt', wrap: false)),
    );
    final line = tester.renderObject<RenderParagraph>(
      find.textContaining('xxxx', findRichText: true).first,
    );
    // Nothing of its end is clipped where the view scrolls to.
    expect(
      line.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(line.size.width),
    );
  });

  for (final wrap in [true, false]) {
    testWidgets('⌘A ⌘C copies the whole file, not the lines in sight, '
        'wrap $wrap', (tester) async {
      viewport(tester, const Size(800, 600));
      final text =
          '${[for (var i = 1; i <= 2000; i++) 'line $i'].join('\n')}\n';
      await tester.pumpWidget(
        themed(SourceView(text, path: 'a.txt', wrap: wrap)),
      );
      await tester.pump();
      final copied = clipboardCopies(tester);
      await tester.tap(find.textContaining('line 3', findRichText: true).first);
      await tester.pump();
      await _selectAllCopy(tester);
      expect(copied.last, text);
      // A selection made after it copies only what it holds.
      await tester.tap(find.textContaining('line 3', findRichText: true).first);
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
      expect(copied.last, isNot(text));
    }, variant: onMac);
  }

  testWidgets('a line cut short copies its own text, not the note', (
    tester,
  ) async {
    viewport(tester, const Size(800, 600));
    final long = '${'a' * 5100}END';
    await tester.pumpWidget(
      themed(SourceView('$long\nb\n', path: 'min.js', wrap: false)),
    );
    await tester.pump();
    expect(find.textContaining('(103 more)', findRichText: true), findsOne);
    final copied = clipboardCopies(tester);
    // From the long line's start to the next one's: all of it selected.
    final from = find.textContaining('aaaa', findRichText: true).first;
    final to = find.text('b', findRichText: true).first;
    final drag = await tester.startGesture(
      tester.getTopLeft(from) + const Offset(1, 4),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveTo(tester.getTopLeft(to) + const Offset(0, 4));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
    expect(copied.last, '$long\n');
  }, variant: onMac);

  // Issue 100: a line's text laid out anew (the highlighting landing, the
  // file read again) dropped its selection under containers that still
  // pointed at it, and the next full repaint threw in Flutter's
  // selection code.
  for (final wrap in [true, false]) {
    for (final (from, to, change) in [
      ('void', 'void', 'highlight'),
      ('void', 'print', 'highlight'),
      ('print', 'void', 'highlight'),
      ('void', 'print', 'read'),
    ]) {
      testWidgets('a selection from "$from" to "$to" when the $change '
          'lands, then a full repaint, wrap $wrap', (tester) async {
        viewport(tester, const Size(800, 600));
        await tester.pumpWidget(
          themed(SourceView(code, path: 'a.dart', wrap: wrap)),
        );
        // A line's selectable joins its list's a frame later.
        await tester.pump();
        final plain = _spans(tester);
        Offset at(String word, double dx) =>
            tester.getTopLeft(
              find.textContaining(word, findRichText: true).first,
            ) +
            Offset(dx, 6);
        final drag = await tester.startGesture(
          at(from, 2),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await drag.moveTo(at(to, 60));
        await tester.pump();
        await drag.up();
        await tester.pump();
        final copied = clipboardCopies(tester);
        await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
        expect(copied.last, isNotEmpty, reason: 'something was selected');
        if (change == 'read') {
          await tester.pumpWidget(
            themed(SourceView('$code// more\n', path: 'a.dart', wrap: wrap)),
          );
        } else {
          expect(_spans(tester), plain, reason: 'not highlighted yet');
          await untilReal(
            tester,
            () => _spans(tester) > plain,
            limit: const Duration(seconds: 5),
          );
          await tester.pump();
        }
        void again(RenderObject o) {
          o
            ..markNeedsPaint()
            ..visitChildren(again);
        }

        tester.binding.renderViews.forEach(again);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // What it held is gone from sight, and from a copy.
        await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
        expect(copied.length, 1);
      }, variant: onMac);
    }
  }
}
