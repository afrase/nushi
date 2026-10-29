import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/review.dart';

void main() {
  ReviewComment comment(
    String path,
    int start,
    int end,
    String quote, {
    bool old = false,
  }) => ReviewComment(
    id: path,
    where: 'uncommitted',
    path: path,
    old: old,
    start: start,
    end: end,
    quote: quote,
    text: 'Fix $path.',
  );

  test('each comment is a reply card: its file, lines and quote, then '
      'the comment', () {
    expect(reviewReply(comment('main.go', 10, 10, '\tfmt.Println(msg, 42)')), (
      quote: '`main.go`, line 10:\n```go\n\tfmt.Println(msg, 42)\n```',
      text: 'Fix main.go.',
      from: myReviewComments,
    ));
    expect(reviewReply(comment('a/b.md', 2, 3, 'one\n```\ntwo', old: true)), (
      quote:
          '`a/b.md`, lines 2–3 (the old version, before the change):\n'
          '````md\none\n```\ntwo\n````',
      text: 'Fix a/b.md.',
      from: myReviewComments,
    ));
  });

  test('a comment follows its lines, or is outdated', () {
    final c = ReviewComment(
      id: '1',
      where: 'uncommitted',
      path: 'a.go',
      old: false,
      start: 4,
      end: 5,
      quote: 'x := 1\ny := 2',
      before: 'func a() {\n\t// set',
      after: '}',
      text: 'why?',
    );
    const file = 'package a\nfunc a() {\n\t// set\nx := 1\ny := 2\n}\n';
    // Two lines added above: it moves down with them.
    expect(c.anchor('// one\n// two\n$file'), isTrue);
    expect((c.start, c.end, c.outdated), (6, 7, false));
    // The same lines in another function too: the one with its context.
    expect(c.anchor('func b() {\nx := 1\ny := 2\n}\n$file'), isTrue);
    expect((c.start, c.end), (8, 9));
    // Gone: outdated, until they come back.
    expect(c.anchor('package a\nfunc a() {\n}\n'), isTrue);
    expect(c.outdated, isTrue);
    expect(c.anchor(file), isTrue);
    expect((c.start, c.end, c.outdated), (4, 5, false));
    expect(c.anchor(file), isFalse);
    // Windows line endings: the same lines.
    expect(c.anchor(file.replaceAll('\n', '\r\n')), isFalse);
    expect(c.outdated, isFalse);
  });

  test('a comment on a look-alike line follows its code, not its number', () {
    final c = ReviewComment(
      id: '1',
      where: 'uncommitted',
      path: 'a.go',
      old: false,
      start: 4,
      end: 4,
      quote: '}',
      before: 'b()\n\tc()',
      text: 'here',
    );
    // Lines inserted above: another "}" is on line 4 now, its own on 7.
    expect(c.anchor('x()\n}\na()\n}\nb()\n\tc()\n}'), isTrue);
    expect((c.start, c.outdated), (7, false));
  });
}
