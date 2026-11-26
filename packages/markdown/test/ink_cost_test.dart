import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

// What a code block's ink costs in a large block (ADR 0086's amendment):
// counted, not timed.

const _hit = Color(0xFFFFFF00);
const _now = Color(0xFF00FFFF);
const _edge = Color(0xFF0000FF);
const _dim = Color(0xFF303030);
const _bg = Color(0xFF000000);

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 12, color: Color(0xFFC0C0C0)),
  code: TextStyle(fontSize: 12),
  codeBackground: _bg,
  codeRadius: 6,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _highlight,
);

/// Every third word dim, the rest as the block's text: many spans.
TextSpan? _highlight(String language, String code, TextStyle style) {
  final out = <InlineSpan>[];
  var n = 0;
  for (final m in RegExp(r'\S+|\s+').allMatches(code)) {
    final w = m[0]!;
    final dim = w.trim().isNotEmpty && n++ % 3 == 0;
    out.add(
      TextSpan(
        text: w,
        style: dim ? const TextStyle(color: _dim) : null,
      ),
    );
  }
  return TextSpan(style: style, children: out);
}

/// Made-up words; two of the eight hold "zel".
const _words = [
  'brask', 'tolmzel', 'vinder', 'quell', 'marp', 'zelkon', 'orrin', 'fen', //
];

/// About [bytes] of made-up code in short lines.
String _code(int bytes) {
  final r = Random(7);
  final lines = <String>[];
  var size = 0;
  while (size < bytes) {
    final b = StringBuffer('  ');
    while (b.length < 40 + lines.length % 30) {
      b
        ..write(_words[r.nextInt(_words.length)])
        ..write(' ');
    }
    final l = b.toString().trimRight();
    lines.add(l);
    size += l.length + 1;
  }
  return lines.join('\n');
}

final String _big = _code(500 << 10);

/// Every colour but white drawn white: every hit needs its ink.
Color _ink(Color color, Color fill, Color background) =>
    color == const Color(0xFFFFFFFF) ? color : const Color(0xFFFFFFFF);

/// The block of [code] in a scroll view, its matches marked by [marks].
Widget _view(TextMarks marks, String code, ScrollController scroll) =>
    MaterialApp(
      home: Scaffold(
        body: TextMarksScope(
          marks: marks,
          child: SelectionArea(
            child: SingleChildScrollView(
              controller: scroll,
              child: Marks(
                entry: 'e',
                child: CodeBlockView(language: 'x', code: code, style: _style),
              ),
            ),
          ),
        ),
      ),
    );

Future<(TextMarks, ScrollController)> _open(
  WidgetTester tester, {
  String query = 'zel',
  String? code,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final m = TextMarks(ink: _ink);
  addTearDown(m.dispose);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(_view(m, code ?? _big, scroll));
  await _look(tester, m, query);
  m.pick(m.marks.first);
  await tester.pump();
  return (m, scroll);
}

Future<void> _look(WidgetTester tester, TextMarks m, String query) async {
  m.look(query, const ['e'], hit: _hit, now: _now, edge: _edge);
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
}

/// The code block's own marks.
RenderObject _block(WidgetTester tester) =>
    tester.renderObject(find.byType(Marks).last);

void main() {
  testWidgets('a paint with nothing changed groups nothing', (tester) async {
    final (m, _) = await _open(tester, code: _code(20 << 10));
    expect(m.marks.length, greaterThan(500));
    InkCost.afresh();
    _block(tester).markNeedsPaint();
    await tester.pump();
    expect(InkCost.groupings, 0);
    expect(InkCost.lines, 0);
  });

  testWidgets('a recolouring reads each range once', (tester) async {
    // Small enough for a walk that reads every range for each piece.
    final (m, _) = await _open(tester, query: 'quell', code: _code(20 << 10));
    InkCost.afresh();
    await _look(tester, m, 'zel');
    expect(m.marks.length, greaterThan(500));
    expect(InkCost.ranges, greaterThan(0));
    expect(InkCost.ranges, lessThanOrEqualTo(m.marks.length));
  });
}
