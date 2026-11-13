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
    expect(lineCounts(FileChange(oldText: old, newText: next)), (9000, 9000));
    // Counted, not diffed: a line moved isn't one added and one removed,
    // as a diff (a short change's) has it.
    List<String> moved(List<String> l) => [...l.skip(1), l.first];
    final long = [for (var i = 0; i < 9000; i++) 'line $i'];
    expect(
      lineCounts(
        FileChange(oldText: long.join('\n'), newText: moved(long).join('\n')),
      ),
      (0, 0),
    );
    final short = ['a', 'b', 'c'];
    expect(
      lineCounts(
        FileChange(oldText: short.join('\n'), newText: moved(short).join('\n')),
      ),
      (1, 1),
    );
  });
}
