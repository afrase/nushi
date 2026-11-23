// A finding's path on the phone, in a real browser: the Mac's folder is
// matched as written, never looked up on the phone, where dart:io has no
// file system and throws.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/findings.dart';

void main() {
  test('an absolute finding opens inside the folder, nothing read', () {
    const folder = '/Users/me/src/calc';
    expect(findingPath(folder, '$folder/calc/calc.go'), 'calc/calc.go');
    expect(findingPath(folder, '/etc/passwd'), isNull);
    expect(findingPath(folder, 'calc/calc.go'), 'calc/calc.go');
  });
}
