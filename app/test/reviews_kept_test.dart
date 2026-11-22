import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/review.dart';

// reviews.json that doesn't read whole is never written over: a comment
// that doesn't read is dropped and the file copied aside first, one that
// doesn't parse is set aside, one that can't be read isn't touched.

File get _file => File('$dataDir/reviews.json');

List<File> _aside() => [
  for (final f in Directory(dataDir).listSync().whereType<File>())
    if (f.uri.pathSegments.last.startsWith('reviews.json.unreadable-')) f,
];

Map<String, Object?> _comment(String id) => {
  'id': id,
  'where': 'branch',
  'path': 'a.go',
  'old': false,
  'start': 1,
  'end': 2,
  'quote': 'x := 1',
  'text': 'Why?',
};

void main() {
  tearDown(() {
    for (final f in [_file, ..._aside()]) {
      if (f.existsSync()) f.deleteSync();
    }
  });

  test('a comment that doesn’t read is dropped, the others kept, and the '
      'file copied aside before a save', () {
    final was = jsonEncode({
      'c': [
        _comment('1'),
        {..._comment('2'), 'quote': 3},
      ],
      'd': [_comment('3')],
    });
    _file.writeAsStringSync(was);
    rereadReviews();
    expect([for (final c in commentsOf('c')) c.id], ['1']);
    expect([for (final c in commentsOf('d')) c.id], ['3']);
    expect(_aside().single.readAsStringSync(), was);

    setComments('d', const []);
    final saved = jsonDecode(_file.readAsStringSync()) as Map<String, Object?>;
    expect(saved.keys, ['c']);
    expect(_aside().single.readAsStringSync(), was);
  });

  test('a comment that doesn’t read is copied aside once: the rest is '
      'written back, so the next launch copies nothing', () {
    _file.writeAsStringSync(
      jsonEncode({
        'c': [
          _comment('1'),
          {..._comment('2'), 'quote': 3},
        ],
      }),
    );
    rereadReviews();
    final saved = jsonDecode(_file.readAsStringSync()) as Map<String, Object?>;
    expect([for (final c in saved['c']! as List) (c as Map)['id']], ['1']);
    rereadReviews();
    rereadReviews();
    expect(_aside(), hasLength(1));
    expect([for (final c in commentsOf('c')) c.id], ['1']);
  });

  test('a file that doesn’t parse is set aside, and a save writes anew', () {
    _file.writeAsStringSync('{"c": [');
    rereadReviews();
    expect(reviews.value, isEmpty);
    expect(_file.existsSync(), isFalse);
    expect(_aside().single.readAsStringSync(), '{"c": [');
  });

  test('a file that can’t be read is never written over', () {
    final was = jsonEncode({
      'c': [_comment('1')],
    });
    _file.writeAsStringSync(was);
    Process.runSync('chmod', ['000', _file.path]);
    addTearDown(() => Process.runSync('chmod', ['600', _file.path]));
    rereadReviews();
    setComments('d', [ReviewComment.fromJson(_comment('2'))]);
    expect(commentsOf('d'), hasLength(1)); // kept in memory
    Process.runSync('chmod', ['600', _file.path]);
    expect(_file.readAsStringSync(), was);
    expect(_aside(), isEmpty);
  });
}
