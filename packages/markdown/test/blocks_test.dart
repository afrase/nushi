import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:markdown_view/src/blocks.dart';

import 'stream_bench_test.dart' show chunkEnds, reply;

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
  test('a cut falls after a finished block, before one of its own', () {
    // Not before the line still being written.
    expect(lastBoundary('One.\n\nTwo.\n\nThree'), 'One.\n\n'.length);
    expect(lastBoundary('One.\n\nTwo'), isNull, reason: 'the last line runs');
    expect(lastBoundary('One.\n\nTwo\n'), 'One.\n\n'.length);
    // Not inside a fence, blank lines and all.
    const fenced = 'Go:\n\n```\na\n\nb\n```\n\nDone\n';
    expect(lastBoundary(fenced), fenced.indexOf('Done'));
    expect(lastBoundary('Go:\n\n```\na\n\nb\n'), 'Go:\n\n'.length);
    // A loose list goes on; an indented paragraph is a list item's.
    expect(lastBoundary('- a\n\n- b\n\n  more\n'), isNull);
    expect(
      lastBoundary('- a\n\n- b\n\nAfter the list.\n'),
      '- a\n\n- b\n\n'.length,
    );
    expect(lastBoundary('Para.\n\n- a\n- b\n'), 'Para.\n\n'.length);
    // A reference definition: never.
    expect(lastBoundary('See [x].\n\nMore.\n\n[x]: https://a.b\n'), isNull);
    // From a cut found before.
    expect(
      lastBoundary('A.\n\nB.\n\nC\n', from: 'A.\n\nB.\n\n'.length),
      isNull,
    );
  });

  testWidgets('streamed in pieces, a reply reads as parsed whole, at every '
      'chunk', (tester) async {
    final text = reply().substring(0, 6000);
    String shown() => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('|');
    double height() => tester.getSize(find.byType(StreamingMarkdown)).height;
    Widget app(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 600, child: child)),
      ),
    );
    final streamed = GlobalKey();
    var cut = false;
    for (final (i, end) in chunkEnds(text.length).indexed) {
      final s = text.substring(0, end);
      await tester.pumpWidget(
        app(StreamingMarkdown(s, key: streamed, style: _style)),
      );
      cut |= find.byType(MarkdownBody).evaluate().length > 1;
      if (i % 5 != 0) continue;
      final (pieces, tall) = (shown(), height());
      // What streaming showed before: the healed text parsed as one.
      await tester.pumpWidget(
        app(
          StreamingMarkdown(
            heal(s, markOpen: true),
            style: _style,
            streaming: false,
          ),
        ),
      );
      expect(shown(), pieces, reason: 'at $end');
      expect(height(), tall, reason: 'at $end');
    }
    expect(cut, isTrue, reason: 'it was cut into pieces');
  });
}
