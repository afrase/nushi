import 'package:flutter/material.dart';
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

void main() {
  testWidgets('a path too long for its line wraps between its folders', (
    tester,
  ) async {
    const path =
        '/Users/me/Developer/a-long-project/work/out/report-1-raw.json';
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: StreamingMarkdown(
                '- `$path`: what it shows\n',
                style: _style,
                streaming: false,
                files: const {path: path},
                onTapFile: tapped.add,
              ),
            ),
          ),
        ),
      ),
    );
    final pieces = find.byType(FileLink);
    expect(tester.widgetList<FileLink>(pieces).map((p) => p.text).join(), path);
    final rects = [
      for (final e in pieces.evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    // Each piece is one line, the path takes more than one, and the
    // paragraph has room for all of them: no line runs into the next.
    final line = rects.first.height;
    expect(rects.every((r) => r.height == line), isTrue);
    final tops = rects.map((r) => r.top).toSet().toList()..sort();
    expect(tops.length, greaterThan(1));
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] - tops[i - 1], greaterThanOrEqualTo(line));
    }
    final paragraph = tester.getRect(
      find.ancestor(of: pieces.first, matching: find.byType(RichText)).last,
    );
    expect(paragraph.bottom, greaterThanOrEqualTo(rects.last.bottom));

    await tester.tap(find.widgetWithText(FileLink, 'report-1-raw.json'));
    expect(tapped, [path]);
  });
}
