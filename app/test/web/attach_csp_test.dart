// A file or photo picked on the phone is read under the relay's own
// Content-Security-Policy: the browser gives the picker's file as a blob:
// URL, which cross_file reads with an XHR, so connect-src must allow it.
// The relay runs in the VM (relay_side.dart).
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test("a picked file's blob: URL reads under the relay's CSP", () async {
    final relay = spawnHybridUri(
      'relay_side.dart',
      message: web.window.location.origin,
    );
    final from = StreamQueue(relay.stream);
    final got = (await from.next as Map).cast<String, Object?>();
    if (got['error'] case final e?) fail('the relay side: $e');
    final csp = got['csp']! as String;
    expect(csp, contains('connect-src'));

    // The relay's policy on this page, as its header would put it (a
    // meta element leaves out only frame-ancestors, unused here).
    final meta = web.document.createElement('meta')
      ..setAttribute('http-equiv', 'Content-Security-Policy')
      ..setAttribute('content', csp);
    web.document.head!.append(meta);

    final bytes = [for (var i = 0; i < 256; i++) i];
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    try {
      // What attachFiles does with a picked file: XFile.readAsBytes.
      expect(await XFile(url, name: 'notes.pdf').readAsBytes(), bytes);
    } finally {
      web.URL.revokeObjectURL(url);
      relay.sink.add('done');
      await from.next;
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
