import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/terminal_find.dart';
import 'package:xterm2/xterm.dart';

void main() {
  test('the word under a click, and what it opens', () {
    final dir = Directory.systemTemp.createTempSync('links')..createSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final folder = dir.resolveSymbolicLinksSync();
    File('$folder/lib.dart').writeAsStringSync('x');

    final terminal = Terminal()
      ..resize(80, 5)
      ..write('see (lib.dart:12:5), https://example.com/a?b=1. and gone.txt');
    final word = wordAt(terminal, const CellOffset(8, 0));
    expect(word, 'lib.dart:12:5');
    final file = linkOf(word, folder);
    expect((file.path, file.line), ('$folder/lib.dart', 12));

    final url = linkOf(wordAt(terminal, const CellOffset(30, 0)), folder);
    expect(url.url, Uri.parse('https://example.com/a?b=1'));

    // A file that isn't there opens nothing.
    final gone = linkOf(wordAt(terminal, const CellOffset(55, 0)), folder);
    expect((gone.url, gone.path), (null, null));
  });
}
