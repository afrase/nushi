import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/merge_lines.dart';

void main() {
  test('a file comes back byte for byte: BOM, CRLF, no final newline', () {
    for (final bytes in [
      utf8.encode('a\nb\n'),
      utf8.encode('a\r\nb'),
      [0xEF, 0xBB, 0xBF, ...utf8.encode('é\r\n')],
      utf8.encode(''),
      utf8.encode('no newline'),
    ]) {
      final (file, why) = decodeFile(bytes);
      expect(why, isNull, reason: '$bytes');
      expect(file!.text.contains('\r'), isFalse);
      expect(file.codec.encode(file.text), bytes);
    }
    final (crlf, _) = decodeFile(utf8.encode('a\r\nb\r\n'));
    expect(crlf!.text, 'a\nb\n');
    expect(crlf.codec.encode('a\nc\nd'), utf8.encode('a\r\nc\r\nd'));
  });

  test('what can’t be edited says why', () {
    for (final (bytes, why) in [
      ([0xFF, 0xFE, 0x41], 'UTF-8'),
      (utf8.encode('a\u0000b'), 'isn’t text'),
      (utf8.encode('a\rb'), 'carriage return'),
      (utf8.encode('a\r\nb\nc'), 'both'),
      ([0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF], 'saved as it is'),
    ]) {
      final (file, reason) = decodeFile(bytes);
      expect(file, isNull);
      expect(reason, contains(why));
    }
  });

  group('mergeLines', () {
    const base = 'one\ntwo\nthree\nfour\nfive\n';
    test('changes apart merge', () {
      expect(
        mergeLines(
          base,
          'ONE\ntwo\nthree\nfour\nfive\n',
          base.replaceAll('five', 'FIVE'),
        ),
        'ONE\ntwo\nthree\nfour\nFIVE\n',
      );
      // One side only, or both the same.
      expect(mergeLines(base, base, 'x\n'), 'x\n');
      expect(mergeLines(base, 'x\n', base), 'x\n');
      expect(mergeLines(base, 'x\n', 'x\n'), 'x\n');
      // An insertion and a deletion apart.
      expect(
        mergeLines(base, 'zero\n$base', 'one\ntwo\nthree\nfour\n'),
        'zero\none\ntwo\nthree\nfour\n',
      );
    });

    test('changes that overlap or touch conflict', () {
      expect(
        mergeLines(
          base,
          base.replaceAll('two', 'TWO'),
          base.replaceAll('two', '2'),
        ),
        isNull,
      );
      // Neighbouring lines.
      expect(
        mergeLines(
          base,
          base.replaceAll('two', 'TWO'),
          base.replaceAll('three', '3'),
        ),
        isNull,
      );
      // Two insertions at one place.
      expect(mergeLines(base, 'a\n$base', 'b\n$base'), isNull);
    });
  });
}
