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

/// A column of short names beside three of sentences, which once broke
/// the names every two letters.
const _table = '''
| Name | Meaning / origin | Sound / stress | Clash |
| --- | --- | --- | --- |
| Magpie | A bird that gathers small shiny things into its nest | MAG-pie, a short word that is easy to say aloud in one breath | None found |
| Starling | A small bird that flies at dusk in great flocks, and "murmuration" names the way they turn together. Closest meaning in this group | STAR-ling, said as two parts by most people who say it at all | None found (Swift is taken, see above). It is also a common surname, and elsewhere it suggests a song |
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
      for (final name in ['Name', 'Magpie', 'Starling']) {
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
