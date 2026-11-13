import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'golden_tolerance.dart';

// What CI lets a golden differ by (golden_tolerance.dart).

void main() {
  test('a small golden passes a few pixels of text drawn apart', () {
    // The restart banner, 5,500 pixels: 57 differed on CI (1.03%).
    expect(goldenWithin(57, 5500), isTrue);
    expect(goldenWithin(goldenFewPixels, 5500), isTrue);
    expect(goldenWithin(goldenFewPixels + 1, 5500), isFalse);
  });

  test('a mid-sized one, up to 1%', () {
    expect(goldenWithin(1000, 120000), isTrue);
    expect(goldenWithin(1300, 120000), isFalse);
  });

  test('a whole window, no more than the cap however large', () {
    const window = 1700 * 900; // 1% is 15,300
    expect(goldenWithin(goldenMostPixels, window), isTrue);
    expect(goldenWithin(goldenMostPixels + 1, window), isFalse);
  });

  test('a PNG’s pixels from its header', () {
    final png = File('test/goldens/github_wide_dark.png').readAsBytesSync();
    expect(pngPixels(png), 1700 * 360);
  });
}
