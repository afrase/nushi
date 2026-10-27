// The inflater compiled to JavaScript (32-bit bit operations), against the
// browser's own gzip.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:remote_transport/src/gzip.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

Future<Uint8List> _browserGzip(Uint8List data) async {
  final cs = web.CompressionStream('gzip');
  final out = web.Response(
    web.Blob([data.toJS].toJS).stream().pipeThrough(
      web.ReadableWritablePair(readable: cs.readable, writable: cs.writable),
    ),
  );
  return (await out.arrayBuffer().toDart).toDart.asUint8List();
}

void main() {
  test('inflates what the browser wrote', () async {
    final r = Random(2);
    for (final data in [
      Uint8List(0),
      Uint8List.fromList(List.generate(70000, (_) => r.nextInt(256))),
      Uint8List.fromList(
        List.generate(300000, (i) => 'abcdefgh {}\n'.codeUnitAt(r.nextInt(12))),
      ),
    ]) {
      expect(gunzip(await _browserGzip(data)), data);
      expect(gunzip(gzipStored(data)), data);
    }
  });
}
