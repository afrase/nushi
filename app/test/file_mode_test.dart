import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_mode.dart';

int _mode(String path) => FileStat.statSync(path).mode & 0x1ff;

/// A temp folder of the test's own.
Directory _tmp() {
  final tmp = Directory.systemTemp.createTempSync('nushi-kept-');
  addTearDown(() => tmp.deleteSync(recursive: true));
  return tmp;
}

/// What's beside the file `x.json` in [dir] once it was set aside.
List<File> _aside(Directory dir) => [
  for (final f in dir.listSync().whereType<File>())
    if (f.uri.pathSegments.last.startsWith('x.json.unreadable-')) f,
];

void main() {
  test("a file written whole is only the user's (0600, or as asked), "
      'in a folder made only theirs (0700)', () {
    final tmp = Directory.systemTemp.createTempSync('nushi-mode-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dir = Directory('${tmp.path}/a/b');
    privateDir(dir);
    expect(_mode(dir.path), 0x1c0);
    privateDir(dir); // there already: left as it is

    final f = File('${dir.path}/x.json');
    writeWhole(f, [1, 2, 3]);
    expect(f.readAsBytesSync(), [1, 2, 3]);
    expect(_mode(f.path), 0x180);
    expect(File('${f.path}.tmp').existsSync(), isFalse);

    // Over a file anyone could read: whole, and only the user's now.
    f.writeAsStringSync('old');
    setMode(f.path, 0x1a4);
    expect(_mode(f.path), 0x1a4);
    writeWhole(f, [4]);
    expect(f.readAsBytesSync(), [4]);
    expect(_mode(f.path), 0x180);

    writeWhole(f, [5], mode: 0x1a4);
    expect(_mode(f.path), 0x1a4);
  });

  group('a kept file read by readKept', () {
    test('none is the empty state, and nothing is set aside', () {
      final dir = _tmp();
      final kept = readKept(File('${dir.path}/x.json'));
      expect(kept.json, isEmpty);
      expect(kept.setAside, isFalse);
      expect(dir.listSync(), isEmpty);
    });

    test('one that reads gives its object, left as it is', () {
      final dir = _tmp();
      final f = File('${dir.path}/x.json')..writeAsStringSync('{"a":[1]}');
      final kept = readKept(f);
      expect(kept.json, {
        'a': [1],
      });
      expect(kept.setAside, isFalse);
      expect(f.readAsStringSync(), '{"a":[1]}');
      expect(_aside(dir), isEmpty);
    });

    for (final (what, bytes) in [
      ('not JSON', utf8.encode('{"a": 1')),
      ('JSON but no object', utf8.encode('[1, 2]')),
      ('not UTF-8', [0x7b, 0xff, 0xfe, 0x7d]),
    ]) {
      test('one $what is set aside whole and reads as empty', () {
        final dir = _tmp();
        final f = File('${dir.path}/x.json')..writeAsBytesSync(bytes);
        final kept = readKept(f);
        expect(kept.json, isEmpty);
        expect(kept.setAside, isTrue);
        expect(f.existsSync(), isFalse); // the next save replaces nothing
        final aside = _aside(dir).single;
        expect(aside.readAsBytesSync(), bytes);
        expect(
          aside.uri.pathSegments.last,
          matches(RegExp(r'^x\.json\.unreadable-\d{4}-\d\d-\d\dT[-\d.]+$')),
        );
      });
    }

    test('one that can’t be read is an error, and stays as it was', () {
      final dir = _tmp();
      final f = File('${dir.path}/x.json')..writeAsStringSync('{"a":1}');
      setMode(f.path, 0);
      addTearDown(() => setMode(f.path, 0x180));
      expect(() => readKept(f), throwsA(isA<FileSystemException>()));
      setMode(f.path, 0x180);
      expect(f.readAsStringSync(), '{"a":1}');
      expect(_aside(dir), isEmpty);
    });

    test('a folder in its place is an error, not the empty state', () {
      final dir = _tmp();
      Directory('${dir.path}/x.json').createSync();
      expect(
        () => readKept(File('${dir.path}/x.json')),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('copyAside keeps a private copy beside the file, which stays', () {
      final dir = _tmp();
      final f = File('${dir.path}/x.json')..writeAsStringSync('{"a":1}');
      copyAside(f);
      copyAside(f); // a second at once takes a name of its own
      expect(f.readAsStringSync(), '{"a":1}');
      final copies = _aside(dir);
      expect(copies, hasLength(2));
      for (final c in copies) {
        expect(c.readAsStringSync(), '{"a":1}');
        expect(_mode(c.path), 0x180);
      }
    });
  });
}
