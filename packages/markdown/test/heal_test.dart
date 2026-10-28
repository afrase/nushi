import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

void main() {
  test('leaves complete markdown alone', () {
    const text = 'Some **bold** and `code`.\n\n```dart\nx\n```\n';
    expect(heal(text), text);
  });

  test('closes an open fence and drops a fence being typed', () {
    expect(heal('```go\nfmt.Println()'), '```go\nfmt.Println()\n```');
    expect(heal('```go\nx\n`'), '```go\nx\n```');
    expect(heal('text\n``'), 'text\n');
    expect(heal('````\n```\n'), '````\n```\n````');
  });

  test('marks the open fence when asked', () {
    expect(
      heal('a\n```mermaid\ngraph TD', markOpen: true),
      'a\n```mermaid $openMark\ngraph TD\n```',
    );
    expect(heal('```\nx\n`', markOpen: true), '``` $openMark\nx\n```');
    // A closed block isn't marked.
    const done = '```mermaid\ngraph TD\n```\n';
    expect(heal(done, markOpen: true), done);
  });

  test('closes emphasis and code spans on the last line', () {
    expect(heal('a **bold'), 'a **bold**');
    expect(heal('a ***both'), 'a ***both***');
    expect(heal('a `co'), 'a `co`');
    expect(heal('a `x` and _it'), 'a `x` and _it_');
    expect(heal('2 * 3'), '2 * 3');
    expect(heal('snake_case'), 'snake_case');
    expect(heal('**done**\nnext'), '**done**\nnext');
  });

  test('shows a link being typed as its text', () {
    expect(heal('see [the do'), 'see the do');
    expect(heal('see [docs](https://exa'), 'see docs');
    expect(heal('see [docs](https://x.y) now'), 'see [docs](https://x.y) now');
    expect(heal('- [ ] task'), '- [ ] task');
  });

  test('completes a table delimiter row being typed', () {
    expect(heal('| a | b |\n|--'), '| a | b |\n| --- | --- |');
    expect(heal('x\n| a | b |\n|--'), 'x\n| a | b |\n|--');
  });
}
