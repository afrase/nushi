import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 13.5, height: 1.5),
  code: TextStyle(fontSize: 12.5),
  codeBackground: Colors.black12,
  codeRadius: 6,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _plain,
);

TextSpan? _plain(String language, String code, TextStyle style) => null;

/// A column of names beside three of sentences, as the owner saw it
/// (2026-11-12): the names broke every two letters.
const _table = '''
| Name | Meaning / connection | Sound / katakana | Collision |
| --- | --- | --- | --- |
| Bowler | The hat of London City clerks and bankers | BOH-ler, a long word about how it sounds when it is said aloud | None found |
| Eyeshade | The green eyeshade was the bookkeeper's headwear, and "green eyeshade" means an accountant. Closest meaning in this group | EYE-shade, said as two words by most people who say it at all | None found (Visor is taken, see above). Apache Derby is a database, and elsewhere it suggests a horse race |
''';

void main() {
  for (final width in [420.0, 700.0, 1200.0]) {
    testWidgets('a short column keeps its words whole, $width wide', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const StreamingMarkdown(
                  _table,
                  style: _style,
                  streaming: false,
                ),
              ),
            ),
          ),
        ),
      );
      // One line each: a line is 13.5 × 1.5 high.
      for (final name in ['Name', 'Bowler', 'Eyeshade']) {
        expect(
          tester.getSize(find.text(name)).height,
          lessThan(25),
          reason: '$name on one line',
        );
      }
      // The table still fits its room.
      expect(
        tester.getSize(find.byType(Table)).width,
        lessThanOrEqualTo(width),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a word longer than a column may keep breaks where it must', (
    tester,
  ) async {
    final word = 'averyverylongunbrokenpathsegment' * 3;
    final long =
        '| Path | Note |\n| --- | --- |\n'
        '| $word | A sentence of several ordinary words here |\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: StreamingMarkdown(long, style: _style, streaming: false),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Table)).width, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
