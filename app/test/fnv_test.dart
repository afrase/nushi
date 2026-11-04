import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/fnv.dart';

void main() {
  test("FNV-1a's values are the published ones: they are kept, so frozen", () {
    expect(fnv1a(''.codeUnits), 0x811c9dc5);
    expect(fnv1a('a'.codeUnits), 0xe40c292c);
    expect(fnv1a(utf8.encode('foobar')), 0xbf9cf968);
  });
}
