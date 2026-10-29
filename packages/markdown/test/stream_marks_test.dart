import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 14, color: Color(0xFF202020)),
  code: TextStyle(fontSize: 13),
  codeBackground: Colors.black12,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _plain,
);

TextSpan? _plain(String language, String code, TextStyle style) => null;

/// The spans of every paragraph drawn, flattened: text and opacity.
List<List<(String, double?)>> _paragraphs(WidgetTester tester) => [
  for (final r in tester.widgetList<RichText>(find.byType(RichText)))
    [
      for (final s in _leaves(r.text))
        if (s case TextSpan(:final text?, :final style))
          (text, style?.color?.a)
        else if (s is WidgetSpan)
          ('caret', null),
    ],
];

List<InlineSpan> _leaves(InlineSpan span) {
  final out = <InlineSpan>[];
  span.visitChildren((s) {
    if (s is WidgetSpan || (s is TextSpan && s.text != null)) out.add(s);
    return true;
  });
  return out;
}

void main() {
  Future<void> show(
    WidgetTester tester,
    String text, {
    List<FreshRun> fresh = const [],
    Widget? caret,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: StreamingMarkdown(
            text,
            style: _style,
            fresh: fresh,
            caret: caret,
          ),
        ),
      ),
    ),
  );

  testWidgets('a faded run stays in its paragraph, which wraps as without '
      'it', (tester) async {
    const text =
        'The shard runner splits every second test file so both halves '
        'finish in about the same time and goldens stay with their tests';
    await show(tester, text);
    final plain = tester.getSize(find.byType(RichText)).height;
    final start = text.indexOf('goldens');
    await show(
      tester,
      text,
      fresh: [(start: start, end: text.length, opacity: 0.4)],
    );
    final ps = _paragraphs(tester);
    expect(ps, hasLength(1), reason: 'one paragraph');
    expect(ps.single.map((s) => s.$1).join(), text);
    expect(ps.single.last.$1, 'goldens stay with their tests');
    expect(ps.single.last.$2, closeTo(0.4, 0.01));
    expect(tester.getSize(find.byType(RichText)).height, plain);
  });

  testWidgets('the caret ends the last line, in it; not in an open fence '
      'or after a line break', (tester) async {
    const caret = SizedBox.shrink(key: ValueKey('caret'));
    await show(tester, 'One.\n\nTwo **bold', caret: caret);
    final ps = _paragraphs(tester);
    expect(ps.last.map((s) => s.$1).join(), 'Two boldcaret');
    expect(find.byKey(const ValueKey('caret')), findsOneWidget);

    await show(tester, 'Code:\n\n```dart\nvoid main', caret: caret);
    expect(find.byKey(const ValueKey('caret')), findsNothing);
    await show(tester, 'Line\n', caret: caret);
    expect(find.byKey(const ValueKey('caret')), findsNothing);
  });

  testWidgets('runs with syntax, at a line start or in code show unfaded, '
      'as written', (tester) async {
    const text = 'Run `make test` then **check** it\n\n- item two';
    await show(
      tester,
      text,
      fresh: [
        (start: text.indexOf('make'), end: text.indexOf(' then'), opacity: 0.3),
        (start: text.indexOf('**'), end: text.indexOf(' it'), opacity: 0.3),
        (start: text.indexOf('- item'), end: text.length, opacity: 0.3),
      ],
    );
    final all = _paragraphs(tester).expand((p) => p).toList();
    expect(all.map((s) => s.$1).join(), 'Run make test then check it•item two');
    expect(all.where((s) => (s.$2 ?? 1) < 0.9), isEmpty);
  });
}
