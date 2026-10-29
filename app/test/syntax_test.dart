import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/tokens.dart';

/// Each highlighted run of [code] in [language] as `text: capture`, line
/// by line, as the diff view gets them.
Future<List<String>> runs(String language, String code) async {
  final [_, lines] = await highlightSides(language, '', code);
  final text = code.split('\n');
  return [
    for (final (i, spans) in lines!.indexed)
      if (spans != null)
        for (var k = 0; k < spans.length; k += 3)
          [
            text[i].substring(spans[k], spans[k] + spans[k + 1]),
            syntaxCaptures[spans[k + 2]],
          ].join(': '),
  ];
}

void main() {
  test('languages by extension or name', () {
    expect(languageOf('app/lib/main.dart'), 'dart');
    expect(languageOf('x/colors.js'), 'js');
    expect(languageOf('Makefile'), 'makefile');
    expect(languageOf('notes.unknownext'), isNull);
  });

  test('a whole side is highlighted, then split by line', () async {
    const text = 'int a = 1;\n/* one\n   two */\nvar s = "x";\n';
    final [old, neu] = await highlightSides('dart', '', text);
    expect(old, [null]); // an empty side: one empty line
    // The comment's second line is a comment, though it has no /* itself.
    expect(neu![2]!.toList(), [0, 9, Capture.comment.index]);
  });

  test('Ruby', () async {
    expect(
      await runs('ruby', '''
# @return [Integer] the result
class Ledger < Base
  def rolling_reserves_total_cents(a, b = 2)
    @total = rolling_reserve_amount_cents + self.fee(:usd) + @@count
    puts "#{a} cents", 42, nil, LIMIT
  end
end'''),
      [
        '# : comment',
        '@return: docTag',
        ' [Integer] the result: comment',
        'class: keyword',
        'Ledger: declaration',
        'Base: type',
        'def: keyword',
        'rolling_reserves_total_cents: declaration',
        'a, b = : parameter',
        '2: number',
        '@total: field',
        'self: keyword',
        ':usd: symbol',
        '@@count: field',
        '": string',
        ' cents": string',
        '42: number',
        'nil: keyword',
        'LIMIT: constant',
        'end: keyword',
        'end: keyword',
      ],
    );
  });

  test('Go', () async {
    expect(
      await runs('go', '''
// Sum adds.
func (l *Ledger) Sum(a int) error {
	x := 42 + len("b")
	return nil
}'''),
      [
        '// Sum adds.: comment',
        'func: keyword',
        '(l *Ledger): parameter',
        'int: type',
        'error: type',
        '42: number',
        'len: keyword',
        '"b": string',
        'return: keyword',
        'nil: keyword',
      ],
    );
  });

  test('Dart', () async {
    expect(
      await runs('dart', r'''
/// Sums [a].
class Ledger extends Base {
  @override
  int sum(int a) => this.x + 42;
  final s = 'hi $a';
}'''),
      [
        '/// Sums [a].: comment',
        'class: keyword',
        'Ledger: declaration',
        'extends: keyword',
        'Base: declaration',
        '@override: meta',
        'int: keyword',
        'int: keyword',
        'this: keyword',
        '42: number',
        'final: keyword',
        "'hi : string",
        "': string",
      ],
    );
  });

  test('TypeScript', () async {
    expect(
      await runs('typescript', r'''
/** @param a the amount */
export class Ledger extends Base {
  total = 42;
  sum(a: number): string {
    return `${a} cents` + /x+/g;
  }
}'''),
      [
        '/** : comment',
        '@param: docTag',
        ' a the amount */: comment',
        'export: keyword',
        'class: keyword',
        'Ledger: declaration',
        'extends: keyword',
        'Base: type',
        '42: number',
        'sum: declaration',
        'a: field',
        'number: keyword',
        'string: keyword',
        'return: keyword',
        '`: string',
        ' cents`: string',
        '/x+/g: regexp',
      ],
    );
  });

  test("code blocks take the diff's colors", () {
    const base = TextStyle(fontSize: 12);
    final highlight = codeHighlighter(Tokens.dark);
    expect(codeHighlighter(Tokens.dark), same(highlight)); // blocks are kept
    expect(highlight('nosuchlanguage', 'x', base), isNull);
    final span = highlight('ruby', 'def go # hi', base)!;
    expect(span.style, base);
    expect(span.toPlainText(), 'def go # hi');
    final kids = span.children!.cast<TextSpan>();
    final dark = Tokens.dark.syntax;
    expect(
      [for (final k in kids) (k.text, k.style?.color)],
      [
        ('def', dark[Capture.keyword]!.color),
        (' ', null),
        ('go', dark[Capture.declaration]!.color),
        (' ', null),
        ('# hi', dark[Capture.comment]!.color),
      ],
    );
  });

  test('a long code block shows plain: no highlighting on the UI thread', () {
    const base = TextStyle(fontSize: 12);
    final highlight = codeHighlighter(Tokens.dark);
    final line = List.filled(5000, 'final x = "a"; // a line').join('\n');
    expect(line.length, greaterThan(maxBlock));
    expect(highlight('dart', line, base), isNull);
    final console = List.filled(5000, r'$ make test').join('\n');
    expect(highlight('console', console, base), isNull);
    expect(highlight('dart', line.substring(0, maxBlock), base), isNotNull);
  });
}
