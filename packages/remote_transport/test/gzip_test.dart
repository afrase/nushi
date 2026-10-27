@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:remote_transport/src/gzip.dart';
import 'package:test/test.dart';

/// Text shaped like a transcript: words, numbers, code, repeated a lot.
Uint8List _text(Random r, int n) {
  const words = ['read', 'edit', 'func', '{', '}', 'return', 'err', '\n', 'x'];
  final b = StringBuffer();
  while (b.length < n) {
    b
      ..write(words[r.nextInt(words.length)])
      ..write(r.nextInt(3) == 0 ? r.nextInt(100000) : ' ');
  }
  return Uint8List.fromList(b.toString().codeUnits);
}

void main() {
  final r = Random(1);
  final inputs = <String, Uint8List>{
    'empty': Uint8List(0),
    'one byte': Uint8List.fromList([42]),
    'text': _text(r, 200000),
    'random': Uint8List.fromList(List.generate(70000, (_) => r.nextInt(256))),
    'runs': Uint8List.fromList(List.generate(100000, (i) => i ~/ 1000 % 3)),
  };

  for (final MapEntry(key: name, value: data) in inputs.entries) {
    test('inflates what zlib wrote: $name, every level', () {
      for (final level in [0, 1, 6, 9]) {
        final z = Uint8List.fromList(GZipCodec(level: level).encode(data));
        expect(gunzip(z), data, reason: 'level $level');
      }
    });

    test('stores what zlib reads: $name', () {
      expect(gzip.decode(gzipStored(data)), data);
      expect(gunzip(gzipStored(data)), data);
    });
  }

  test('a changed byte, a cut, or too much is refused', () {
    final data = _text(r, 50000);
    final z = Uint8List.fromList(gzip.encode(data));
    for (var i = 10; i < z.length; i += 97) {
      final bad = Uint8List.fromList(z)..[i] ^= 0x55;
      expect(() => gunzip(bad), throwsFormatException, reason: 'byte $i');
    }
    expect(
      () => gunzip(Uint8List.sublistView(z, 0, z.length - 9)),
      throwsFormatException,
    );
    expect(() => gunzip(z, max: 1 << 14), throwsFormatException);
    expect(
      () => gunzip(Uint8List.fromList('plain'.codeUnits)),
      throwsFormatException,
    );
  });

  test('the codec as Connect uses it', () {
    const g = Gzip();
    final data = _text(r, 5000);
    expect(g.name, 'gzip');
    expect(g.decode(g.encode(data)), data);
    expect(g.decode(Uint8List.fromList(gzip.encode(data))), data);
  });
}
