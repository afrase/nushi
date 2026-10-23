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

  test(
    'a review is one message: file, lines, quote, comment, then the note',
    () {
      final msg = reviewMessage([
        comment('main.go', 10, 10, '\tfmt.Println(msg, 42)'),
        comment('a/b.md', 2, 3, 'one\n```\ntwo', old: true),
      ], '  Thanks. ');
      expect(msg, '''
Review comments:

1. `main.go`, line 10:
```go
\tfmt.Println(msg, 42)
```
Fix main.go.

2. `a/b.md`, lines 2–3 (the old version, before the change):
````md
one
```
two
````
Fix a/b.md.

Thanks.
''');
    },
  );

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
    expect(
      c.anchor('func b() {\nx := 1\ny := 2\n}\n$file'),
      isTrue,
    );
    expect((c.start, c.end), (8, 9));
    // Gone: outdated, until they come back.
    expect(c.anchor('package a\nfunc a() {\n}\n'), isTrue);
    expect(c.outdated, isTrue);
    expect(c.anchor(file), isTrue);
    expect((c.start, c.end, c.outdated), (4, 5, false));
    expect(c.anchor(file), isFalse);
  });
}
