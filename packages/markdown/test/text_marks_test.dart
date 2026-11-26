import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

const _hit = Color(0xFFFFFF00);
const _now = Color(0xFF00FFFF);
const _edge = Color(0xFF0000FF);

/// [child] as one entry under [marks], selectable.
Widget _entry(TextMarks marks, Widget child) => MaterialApp(
  home: Scaffold(
    body: SelectionArea(
      child: TextMarksScope(
        marks: marks,
        child: Marks(entry: 'e', child: child),
      ),
    ),
  ),
);

Future<void> _look(WidgetTester tester, TextMarks m, String query) async {
  m.look(query, const ['e'], hit: _hit, now: _now, edge: _edge);
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('finds the text as laid out, case aside, in reading order', (
    tester,
  ) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(
      _entry(
        m,
        const Column(
          children: [
            Text.rich(
              TextSpan(
                text: 'one Re',
                children: [
                  TextSpan(
                    text: 'lay',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' and a RELAY'),
                ],
              ),
            ),
            Text('nothing here'),
            Text('relay'),
          ],
        ),
      ),
    );
    await _look(tester, m, 'relay');
    expect(m.marks, hasLength(3));
    expect([for (final x in m.marks) x.key], ['e 0', 'e 1', 'e 2']);
  });

  testWidgets('a character that changes length when lowered keeps the offsets '
      'right', (tester) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(_entry(m, const Text('İİ the relay')));
    await _look(tester, m, 'relay');
    final (box, rect) = m.marks.single.place;
    final p = box as RenderParagraph;
    const text = 'İİ the relay';
    final want = p
        .getBoxesForSelection(
          TextSelection(
            baseOffset: text.indexOf('relay'),
            extentOffset: text.length,
          ),
        )
        .single
        .toRect();
    expect(rect, want);
  });

  testWidgets('a path in widget spans is found across them', (tester) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(
      _entry(
        m,
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'See '),
              WidgetSpan(child: Text('auth/')),
              WidgetSpan(child: Text('session.go')),
              TextSpan(text: ' for it.'),
            ],
          ),
        ),
      ),
    );
    await _look(tester, m, 'auth/session');
    expect(m.marks, hasLength(1));
    await _look(tester, m, 'see auth');
    expect(m.marks, hasLength(1));
    await _look(tester, m, 'nowhere');
    expect(m.marks, isEmpty);
  });

  testWidgets("what can't be selected isn't the text", (tester) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(
      _entry(
        m,
        const Column(
          children: [
            SelectionContainer.disabled(child: Text('relay')),
            Unmarked(child: Text('relay')),
            Text('relay'),
          ],
        ),
      ),
    );
    await _look(tester, m, 'relay');
    expect(m.marks, hasLength(1));
  });

  testWidgets("what's folded away counts, on its row, until it isn't", (
    tester,
  ) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    var folded = 'a relay and a relay';
    late StateSetter set;
    var count = -1;
    await tester.pumpWidget(
      _entry(
        m,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return FoldedMarks(
              text: folded,
              builder: (context, found) => ValueListenableBuilder(
                valueListenable: found,
                builder: (context, n, _) {
                  count = n;
                  return const Text('The relay row');
                },
              ),
            );
          },
        ),
      ),
    );
    await _look(tester, m, 'relay');
    expect(m.marks.map((x) => x.folded), [false, true, true]);
    expect(count, 2);
    set(() => folded = '');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(m.marks.map((x) => x.folded), [false]);
    expect(count, 0);
  });

  testWidgets('marks paint under the text, not over it', (tester) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(_entry(m, const Text('the relay')));
    await _look(tester, m, 'relay');
    final box = tester.renderObject(find.byType(Marks));
    expect(
      box,
      paints
        ..rrect(color: _hit)
        ..paragraph(),
    );
    m.pick(m.marks.single);
    await tester.pump();
    expect(
      box,
      paints
        ..rrect(color: _now)
        ..rrect(color: _edge)
        ..paragraph(),
    );
  });

  testWidgets("marks change no span, so a paragraph isn't laid out again", (
    tester,
  ) async {
    final m = TextMarks();
    addTearDown(m.dispose);
    await tester.pumpWidget(_entry(m, const Text('the relay')));
    final p = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final span = p.text;
    await _look(tester, m, 'relay');
    expect(identical(p.text, span), isTrue);
    await _look(tester, m, '');
    expect(m.marks, isEmpty);
    expect(tester.renderObject(find.byType(Marks)), isNot(paints..rrect()));
  });

  testWidgets("on a background, a match's text is drawn again in its ink, "
      'its spans untouched', (tester) async {
    const dim = Color(0xFF303030);
    const bg = Color(0xFF000000);
    final asked = <(Color, Color, Color)>[];
    final m = TextMarks(
      ink: (color, fill, background) {
        asked.add((color, fill, background));
        return color == dim ? const Color(0xFFFFFFFF) : color;
      },
    );
    addTearDown(m.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: TextMarksScope(
              marks: m,
              child: const Marks(
                entry: 'e',
                background: bg,
                child: Text.rich(
                  TextSpan(
                    text: 'a ',
                    children: [
                      TextSpan(
                        text: 'dim',
                        style: TextStyle(color: dim),
                      ),
                      TextSpan(text: ' relay'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final p = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final span = p.text;
    final box = tester.renderObject(find.byType(Marks));
    await _look(tester, m, 'dim');
    expect(identical(p.text, span), isTrue);
    expect(asked, contains((dim, _hit, bg)));
    expect(
      box,
      paints
        ..rrect(color: _hit)
        ..paragraph()
        ..paragraph(),
    );
    // What reads as it is isn't drawn again.
    await _look(tester, m, 'relay');
    expect(
      box,
      paints
        ..rrect(color: _hit)
        ..paragraph(),
    );
    expect(
      box,
      isNot(
        paints
          ..paragraph()
          ..paragraph(),
      ),
    );
  });

  testWidgets("a code block's inked text isn't laid out again while other "
      'text in its entry changes', (tester) async {
    const dim = Color(0xFF303030);
    const bg = Color(0xFF000000);
    var asked = 0;
    final m = TextMarks(
      ink: (color, fill, background) {
        asked++;
        return color == dim ? const Color(0xFFFFFFFF) : color;
      },
    );
    addTearDown(m.dispose);
    final streamed = ValueNotifier('a reply');
    addTearDown(streamed.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: TextMarksScope(
              marks: m,
              child: Marks(
                entry: 'e',
                child: Column(
                  children: [
                    const Marks(
                      background: bg,
                      child: Text('dim words', style: TextStyle(color: dim)),
                    ),
                    ValueListenableBuilder(
                      valueListenable: streamed,
                      builder: (_, text, _) => Text(text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _look(tester, m, 'dim');
    expect(asked, greaterThan(0));
    final first = asked;
    for (var i = 0; i < 5; i++) {
      streamed.value += ' more';
      await tester.pump();
      await tester.pump();
    }
    expect(m.marks, hasLength(1));
    expect(asked, first, reason: 'the unchanged block was inked again');
    // A new pair of fills is a new ink.
    m.look('dim', const ['e'], hit: _now, now: _hit, edge: _edge);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(asked, greaterThan(first));
  });
}
