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

  test('formats highlight.js has no grammar for', () {
    expect(languageOf('deploy/app.jsonnet'), 'jsonnet');
    expect(languageOf('lib/k.libsonnet'), 'libsonnet');
    expect(languageOf('main.tf'), 'tf');
    expect(languageOf('build.zig'), 'zig');
    expect(languageOf('.zshrc.zsh'), 'zsh');
    expect(languageOf('Gemfile'), 'gemfile');
    expect(languageName('jsonnet'), 'Jsonnet');
    expect(languageName('tf'), 'HCL');
    expect(languageName('zsh'), 'zsh'); // borrows bash's, isn't called it
  });

  test('a jsonnet file comes out by what its parts are', () async {
    const text =
        '// a comment\nlocal app(name) = {\n  name: name,\n  ports:: [8080],\n'
        "  text: |||\n    block\n  |||,\n  on: std.length('x') > 0,\n}\n";
    expect(await runs('jsonnet', text), [
      '// a comment: comment',
      'local: keyword',
      'app: declaration',
      'name: field',
      'ports: field',
      '8080: number',
      'text: field',
      '|||: string',
      '    block: string',
      '  |||: string',
      'on: field',
      'std: keyword',
      "'x': string",
      '0: number',
    ]);
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
# @param beds [Array<Bed>] every bed on the plot
class Sprinkler < Base
  def driest_bed(beds)
    @next = beds.min_by(&:moisture) || self.nearest(:shed) || @@spare
    puts "#{beds.size} beds", 12, nil, NOZZLES
  end
end'''),
      [
        '# : comment',
        '@param: docTag',
        ' beds [Array<Bed>] every bed on the plot: comment',
        'class: keyword',
        'Sprinkler: declaration',
        'Base: type',
        'def: keyword',
        'driest_bed: declaration',
        'beds: parameter',
        '@next: field',
        ':moisture: symbol',
        'self: keyword',
        ':shed: symbol',
        '@@spare: field',
        '": string',
        ' beds": string',
        '12: number',
        'nil: keyword',
        'NOZZLES: constant',
        'end: keyword',
        'end: keyword',
      ],
    );
  });

  test('Go', () async {
    expect(
      await runs('go', '''
// Soak waters one bed.
func (s *Sprinkler) Soak(bed int) error {
	x := 12 + len("b")
	return nil
}'''),
      [
        '// Soak waters one bed.: comment',
        'func: keyword',
        '(s *Sprinkler): parameter',
        'int: type',
        'error: type',
        '12: number',
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
/// Soaks [bed].
class Sprinkler extends Base {
  @override
  int soak(int bed) => this.x + 12;
  final s = 'bed $bed';
}'''),
      [
        '/// Soaks [bed].: comment',
        'class: keyword',
        'Sprinkler: declaration',
        'extends: keyword',
        'Base: declaration',
        '@override: meta',
        'int: keyword',
        'int: keyword',
        'this: keyword',
        '12: number',
        'final: keyword',
        "'bed : string",
        "': string",
      ],
    );
  });

  test('TypeScript', () async {
    expect(
      await runs('typescript', r'''
/** @param bed which one to soak */
export class Sprinkler extends Base {
  minutes = 12;
  soak(bed: number): string {
    return `${bed} is soaked` + /x+/g;
  }
}'''),
      [
        '/** : comment',
        '@param: docTag',
        ' bed which one to soak */: comment',
        'export: keyword',
        'class: keyword',
        'Sprinkler: declaration',
        'extends: keyword',
        'Base: type',
        '12: number',
        'soak: declaration',
        'bed: field',
        'number: keyword',
        'string: keyword',
        'return: keyword',
        '`: string',
        ' is soaked`: string',
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
