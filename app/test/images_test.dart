import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
