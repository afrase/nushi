import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_mode.dart';

int _mode(String path) => FileStat.statSync(path).mode & 0x1ff;

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
}
