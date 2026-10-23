import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

void main() {
  final files = [
    for (final p in [
      'app/lib/theme/a.dart',
      'app/lib/theme/b.dart',
      'app/lib/x.dart',
      'docs/deep/only/c.md',
      'main.go',
    ])
      FileChange(path: p, added: 2, removed: 1),
  ];

  String show(List<ChangeRow> rows) =>
      rows.map((r) => '${'  ' * r.depth}${r.name} +${r.added}').join('\n');

  test('a tree with single-folder chains joined, folders first', () {
    expect(show(changeRows(files, flat: false)), '''
app/lib +6
  theme +4
    a.dart +2
    b.dart +2
  x.dart +2
docs/deep/only +2
  c.md +2
main.go +2''');
  });

  test('collapsed folders hide what is inside; flat lists paths', () {
    expect(
      show(changeRows(files, flat: false, collapsed: {'app/lib/theme'})),
      startsWith('app/lib +6\n  theme +4\n  x.dart +2\n'),
    );
    expect(changeRows(files, flat: true).map((r) => r.name), [
      for (final f in files) f.path,
    ]);
  });
}
