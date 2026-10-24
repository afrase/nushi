import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/tool_calls.dart';

void main() {
  test('a run of tool calls reads as what they did', () {
    Item call(String kind) => Item(toolKind: kind);
    expect(
      groupLabel([call('read'), call('execute'), call('read'), call('edit')]),
      'Read 2 files, ran 1 command, edited 1 file',
    );
    expect(groupLabel([call('other'), call('think')]), 'Used 2 tools');
  });

  test('an edit counts the lines it adds and removes', () {
    final d = FileChange(oldText: 'a\nb\nc', newText: 'a\nB\nc\nd');
    expect(lineCounts(d), (2, 1));
    expect(lineCounts(FileChange(newText: 'x\ny')), (2, 0));
  });

  test('a long rewrite is counted at once, not diffed on the UI thread', () {
    final old = [for (var i = 0; i < 9000; i++) 'old $i'].join('\n');
    final next = [for (var i = 0; i < 9000; i++) 'new $i'].join('\n');
    final clock = Stopwatch()..start();
    expect(lineCounts(FileChange(oldText: old, newText: next)), (9000, 9000));
    expect(clock.elapsedMilliseconds, lessThan(300));
  });
}
