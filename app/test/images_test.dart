import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';

void main() {
  test('a markdown image reads only a regular file of a few MB', () {
    final dir = Directory.systemTemp.createTempSync('images');
    addTearDown(() => dir.deleteSync(recursive: true));
    final small = File('${dir.path}/a.png')..writeAsBytesSync([1, 2, 3]);
    final big = File('${dir.path}/b.png')
      ..writeAsBytesSync(List.filled(maxImageFile + 1, 0));
    Process.runSync('mkfifo', ['${dir.path}/fifo']);
    bool refused(String path) => markdownImage(Uri.file(path), 'x') is Text;
    expect(refused(small.path), isFalse);
    expect(refused(big.path), isTrue);
    expect(refused('/dev/zero'), isTrue);
    expect(refused('${dir.path}/fifo'), isTrue);
    expect(refused('${dir.path}/missing.png'), isTrue);
    // A host or a query: not a local file, and no throw.
    for (final u in [
      'file://evil.com/a.png',
      '//host/a.png',
      '/assets/logo.png?raw=true',
    ]) {
      expect(markdownImage(Uri.parse(u), 'x'), isA<Text>(), reason: u);
    }
  });

  test(
    'an image still being prepared joins the images there are then',
    () async {
      final slow = Completer<ImageData>();
      final images = Attachments(prepare: (_) => slow.future)
        ..value = [ImageData(mimeType: 'image/png')];
      final adding = images.add(Uint8List(1));
      var ready = false;
      images.ready().then((_) => ready = true);
      images.clear(); // sent meanwhile
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse);
      slow.complete(ImageData(mimeType: 'image/jpeg'));
      await adding;
      await Future<void>.delayed(Duration.zero);
      expect([for (final i in images.value) i.mimeType], ['image/jpeg']);
      expect(ready, isTrue);
    },
  );
}
