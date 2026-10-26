import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

void main() {
  testWidgets('typed text keeps its line breaks and shows HTML as text', (
    tester,
  ) async {
    const style = MarkdownStyle(
      body: TextStyle(),
      code: TextStyle(),
      codeBackground: Colors.white,
      border: Colors.grey,
      muted: Colors.grey,
      link: Colors.blue,
      highlight: _plain,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingMarkdown(
          'one\ntwo **bold** <b>x</b>',
          style: style,
          streaming: false,
          lineBreaks: true,
        ),
      ),
    );
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText())
        .join();
    expect(text, 'one\ntwo bold <b>x</b>');
  });

  testWidgets("a task list's boxes show", (tester) async {
    const style = MarkdownStyle(
      body: TextStyle(),
      code: TextStyle(),
      codeBackground: Colors.white,
      border: Colors.grey,
      muted: Colors.grey,
      link: Colors.blue,
      highlight: _plain,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingMarkdown(
          '- [x] done\n- [ ] not yet',
          style: style,
          streaming: false,
        ),
      ),
    );
    expect(find.text('☑'), findsOneWidget);
    expect(find.text('☐'), findsOneWidget);
  });

  testWidgets('a selection shows through inline code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingMarkdown(
          'run `make check` now',
          style: MarkdownStyle(
            body: TextStyle(),
            code: TextStyle(),
            codeBackground: Colors.white,
            border: Colors.grey,
            muted: Colors.grey,
            link: Colors.blue,
            highlight: _plain,
          ),
          streaming: false,
        ),
      ),
    );
    TextStyle? code;
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      t.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'make check') code = span.style;
        return true;
      });
    }
    // Painted over the selection, an opaque background would hide it.
    expect(code?.backgroundColor?.a, lessThan(0.2));
  });

  testWidgets('bold stands out of semibold text; inline code takes its '
      'own tint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingMarkdown(
          'a **b** `c`',
          style: MarkdownStyle(
            body: TextStyle(fontWeight: FontWeight.w600),
            code: TextStyle(),
            codeBackground: Colors.white,
            inlineCode: Color(0x14112233),
            border: Colors.grey,
            muted: Colors.grey,
            link: Colors.blue,
            highlight: _plain,
          ),
          streaming: false,
        ),
      ),
    );
    final styles = <String, TextStyle?>{};
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      t.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          styles[span.text!] = span.style;
        }
        return true;
      });
    }
    expect(styles['b']?.fontWeight, FontWeight.w800);
    expect(styles['c']?.backgroundColor, const Color(0x14112233));
  });
}

TextSpan? _plain(String language, String code, TextStyle style) => null;
