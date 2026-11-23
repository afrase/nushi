import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:markdown_view/src/blocks.dart';

/// A reply of about 3,000 words as agents write them: headings, paragraphs
/// with inline code and bold, lists, code blocks and a table.
String reply() {
  final out = StringBuffer();
  final words =
      'the shard runner splits every second test file so both halves '
              'finish in about the same time and the goldens stay with their '
              'tests while the cache keeps the build warm between runs'
          .split(' ');
  final r = Random(7);
  String sentence() {
    final n = 10 + r.nextInt(14);
    final s = [for (var i = 0; i < n; i++) words[r.nextInt(words.length)]];
    if (r.nextBool()) s[r.nextInt(n)] = '`${s[r.nextInt(n)]}`';
    if (r.nextInt(3) == 0) s[r.nextInt(n)] = '**${s[r.nextInt(n)]}**';
    return '${s.join(' ')}.';
  }

  var section = 0;
  while (out.toString().split(RegExp(r'\s+')).length < 3000) {
    section++;
    out.write('## Part $section\n\n');
    for (var p = 0; p < 2; p++) {
      out.write('${[for (var i = 0; i < 4; i++) sentence()].join(' ')}\n\n');
    }
    out.write('- ${sentence()}\n- ${sentence()}\n- ${sentence()}\n\n');
    if (section.isEven) {
      out.write(
        '```dart\nvoid main() {\n  for (var i = 0; i < $section; i++) {\n'
        "    print('shard \$i');\n  }\n}\n```\n\n",
      );
    }
    if (section % 3 == 0) {
      out
        ..write('| Job | Before | After |\n|---|---|---|\n')
        ..write('| test-app | 12:57 | 3:13 |\n| release | 19:30 | 5:21 |\n\n');
    }
  }
  return out.toString();
}

/// Its chunks as they stream: mostly 5 to 40 characters, some of 90 to 180.
List<int> chunkEnds(int length) {
  final r = Random(3);
  final ends = <int>[];
  var at = 0;
  while (at < length) {
    at = min(
      length,
      at + (r.nextInt(7) == 0 ? 90 + r.nextInt(90) : 5 + r.nextInt(36)),
    );
    ends.add(at);
  }
  return ends;
}

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
    // Not inside an HTML block that blank lines don't end: a comment,
    // <pre> and the like, closed or still open.
    const comment = 'Go:\n\n<!--\n- a\n\n- b\n-->\n\nDone\n';
    expect(lastBoundary(comment), comment.indexOf('Done'));
    const pre = 'Go:\n\n<PRE>\na\n\n*b*\n</pre>\n\nDone\n';
    expect(lastBoundary(pre), pre.indexOf('Done'));
    expect(lastBoundary('Go:\n\n<!--\na\n\nb\n'), 'Go:\n\n'.length);
    expect(lastBoundary('Go:\n\n<?x\na\n\nb\n'), 'Go:\n\n'.length);
    // One that ends on its line, or that blank lines end (<div>), doesn't
    // hold a cut back.
    expect(
      lastBoundary('<!-- a -->\n\nB.\n\nC\n'),
      '<!-- a -->\n\nB.\n\n'.length,
    );
    expect(lastBoundary('<div>\na\n\nB.\n'), '<div>\na\n\n'.length);
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
