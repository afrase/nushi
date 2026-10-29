import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/completions.dart';

void main() {
  test('names whose last part starts with what is typed first, then the '
      'shortest, then as listed; 8 at most', () {
    expect(
      rankChoices([
        'lib/chat_view.dart',
        'lib/chat.dart',
        'test/view_chat_test.dart',
        'docs/chat:notes.md',
        'lib/flat.dart',
        'lib/a/chat.go',
        'lib/b/chat.go',
      ], 'chat'),
      [
        'lib/chat.dart',
        'lib/a/chat.go',
        'lib/b/chat.go',
        'lib/chat_view.dart',
        'docs/chat:notes.md', // its last part is notes.md
        'test/view_chat_test.dart',
      ],
    );
    // Case aside; as long as each other: as listed.
    expect(rankChoices(['b/readme.md', 'A/README.md', 'c/x.md'], 'READ'), [
      'b/readme.md',
      'A/README.md',
    ]);
    expect(
      rankChoices([for (var i = 0; i < 20; i++) 'f$i'], 'f'),
      hasLength(8),
    );
  });

  // A bare "@" ranks every file the folder lists, at every key.
  test('20,000 paths are ranked well within a frame or two', () {
    final paths = [
      for (var i = 0; i < 20000; i++)
        'packages/module_${i % 97}/lib/src/part_$i/file_$i.dart',
    ];
    rankChoices(paths, 'file'); // warm
    // The best of three, so a pause on a busy runner (a collection, the
    // runner's other work) doesn't count; a slow ranking is slow in all.
    var best = 1 << 30;
    for (var run = 0; run < 3; run++) {
      final watch = Stopwatch()..start();
      final got = rankChoices(paths, 'file');
      watch.stop();
      expect(got.first, 'packages/module_0/lib/src/part_0/file_0.dart');
      best = min(best, watch.elapsedMilliseconds);
    }
    expect(best, lessThan(100)); // 11–15 ms here
  });
}
