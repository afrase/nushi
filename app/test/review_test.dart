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
}
