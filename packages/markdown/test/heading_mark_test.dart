import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 13.5, height: 1.5),
  code: TextStyle(fontSize: 12.5),
  codeBackground: Colors.black12,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _plain,
);

TextSpan? _plain(String language, String code, TextStyle style) => null;

const _doc = '''
# The *Still* Kettle

Some words.

## Plans

```
# not a heading
```

> ### Quoted `code`

Setext
------
''';

/// One heading's mark: its level and text.
class _Mark extends StatelessWidget {
  const new(this.level, this.text);

  final int level;
  final String text;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _pump(
  WidgetTester tester,
  String text, {
  bool streaming = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SelectionArea(
        child: StreamingMarkdown(
          text,
          style: _style,
          streaming: streaming,
          headingMark: _Mark.new,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('each heading has its mark, at its first line’s top, in order', (
    tester,
  ) async {
    await _pump(tester, _doc);
    final marks = tester.widgetList<_Mark>(find.byType(_Mark)).toList();
    expect(
      [for (final m in marks) (m.level, m.text)],
      [
        (1, 'The Still Kettle'),
        (2, 'Plans'),
        (3, 'Quoted code'),
        (2, 'Setext'),
      ],
    );
    // The headings read as they did, the mark taking no room (a
    // placeholder in the text, which copying leaves out, below).
    final title = tester.getRect(
      find.textContaining('The Still Kettle', findRichText: true),
    );
    final mark = tester.getRect(find.byType(_Mark).first);
    expect(mark.size, Size.zero);
    expect(mark.left, title.left);
    expect(mark.top, inInclusiveRange(title.top, title.top + 6));
  });

  testWidgets('a copied heading has no mark in it', (tester) async {
    await _pump(tester, '# Kettle\n\nTea.\n');
    final title = tester.getCenter(
      find.textContaining('Kettle', findRichText: true),
    );
    final gesture = await tester.startGesture(
      Offset(0, title.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(title + const Offset(60, 0));
    await gesture.up();
    await tester.pump();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(copied, 'Kettle');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('no marks while it streams', (tester) async {
    await _pump(tester, _doc, streaming: true);
    expect(find.byType(_Mark), findsNothing);
  });
}
