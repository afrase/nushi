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

/// What the app puts on the clipboard, in order.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  return copied;
}

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
      final copied = _clipboard(tester);
      await tester.tap(find.textContaining('line 3', findRichText: true).first);
      await tester.pump();
      await _selectAllCopy(tester);
      expect(copied.last, text);
      // A selection made after it copies only what it holds.
      await tester.tap(find.textContaining('line 3', findRichText: true).first);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(copied.last, isNot(text));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
