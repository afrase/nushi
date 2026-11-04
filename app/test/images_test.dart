import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';

void main() {
  test('a markdown image reads only a regular file of a few MB', () async {
    final dir = Directory.systemTemp.createTempSync('images');
    addTearDown(() => dir.deleteSync(recursive: true));
    final small = File('${dir.path}/a.png')..writeAsBytesSync([1, 2, 3]);
    final big = File('${dir.path}/b.png')
      ..writeAsBytesSync(List.filled(maxImageFile + 1, 0));
    Process.runSync('mkfifo', ['${dir.path}/fifo']);
    Future<bool> refused(String path) async => !await readableImage(path);
    expect(await refused(small.path), isFalse);
    expect(await refused(big.path), isTrue);
    expect(await refused('/dev/zero'), isTrue);
    expect(await refused('${dir.path}/fifo'), isTrue);
    expect(await refused('${dir.path}/missing.png'), isTrue);
    // A host or a query: not a local file, and no throw.
    for (final u in [
      'file://evil.com/a.png',
      '//host/a.png',
      '/assets/logo.png?raw=true',
    ]) {
      expect(markdownImage(Uri.parse(u), 'x'), isA<Text>(), reason: u);
    }
  });

  // Chat review 2026-11-04: a path in an agent's Markdown was checked on
  // the UI thread, so one on a network volume that doesn't answer froze
  // the window. The build never waits on the file.
  testWidgets("a local image's file is checked off the UI thread", (
    tester,
  ) async {
    final asked = <String>[];
    final answer = Completer<bool>();
    final readable = readableImage;
    readableImage = (path) {
      asked.add(path);
      return answer.future;
    };
    addTearDown(() => readableImage = readable);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: markdownImage(Uri.file('/Volumes/share/a.png'), 'x'),
        ),
      ),
    );
    expect(asked, ['/Volumes/share/a.png']);
    expect(find.byType(Image), findsNothing);
    answer.complete(false);
    await tester.pump();
    expect(find.text('[image: x (not an image file Nushi reads)]'), findsOne);
  });

  test(
    'an image still being prepared joins the images there are then',
    () async {
      final slow = Completer<ImageData>();
      final images = Attachments(prepare: (_) => slow.future)
        ..value = [ImageData(mimeType: 'image/png')];
      final adding = images.add(Uint8List(1));
      var ready = false;
      unawaited(images.ready().then((_) => ready = true));
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
