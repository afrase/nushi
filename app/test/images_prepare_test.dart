import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/images.dart';

// What an attached image is sent as (prepareImage): the agent gets it as
// it was when it's small enough and of a kind it reads, else scaled down
// and turned into PNG, under the API's limit.

/// [w]×[h] pixels, each from [pixel] (RGBA), encoded as PNG.
Future<Uint8List> _png(int w, int h, int Function(int i) pixel) async {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < rgba.length; i++) {
    rgba[i] = pixel(i);
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// An image's size as decoded.
Future<(int, int)> _size(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final d = await ui.ImageDescriptor.encoded(buffer);
  final size = (d.width, d.height);
  d.dispose();
  return size;
}

/// A 2×2 BMP, 24 bits a pixel: a kind the agent isn't sent as it is.
Uint8List _bmp() {
  final b = ByteData(54 + 16)
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setUint32(2, 54 + 16, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, 2, Endian.little)
    ..setInt32(22, 2, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, 16, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  test('a small PNG goes as it is, byte for byte', () async {
    final png = await _png(40, 30, (i) => 200);
    final out = await prepareImage(png);
    expect(out.mimeType, 'image/png');
    expect(out.data, png);
  });

  test('one wider than the longest side is scaled down to it, its shape '
      'kept', () async {
    final png = await _png(maxImageSide * 2, 500, (i) => 90);
    final out = await prepareImage(png);
    expect(out.mimeType, 'image/png');
    expect(await _size(Uint8List.fromList(out.data)), (maxImageSide, 250));
  });

  test('a kind the agent doesn’t read is turned into PNG, its size '
      'kept', () async {
    final out = await prepareImage(_bmp());
    expect(out.mimeType, 'image/png');
    expect(out.data.take(4), [0x89, 0x50, 0x4E, 0x47]);
    expect(await _size(Uint8List.fromList(out.data)), (2, 2));
  });

  test('one too heavy within the longest side is scaled down until it '
      'weighs under the limit', () async {
    // Noise doesn't compress: 1,568² pixels are about 9.8 MB as PNG.
    final random = Random(7);
    final png = await _png(
      maxImageSide,
      maxImageSide,
      (i) => i % 4 == 3 ? 255 : random.nextInt(256),
    );
    expect(png.length, greaterThan(maxImageBytes));
    final out = await prepareImage(png);
    expect(out.mimeType, 'image/png');
    expect(out.data.length, lessThanOrEqualTo(maxImageBytes));
    final (w, h) = await _size(Uint8List.fromList(out.data));
    expect(w, h);
    expect(w, lessThan(maxImageSide));
    // Scaled by three quarters at a time, no further than it needs.
    expect(w, greaterThanOrEqualTo((maxImageSide * 0.75 * 0.75).round()));
  });

  test('what isn’t an image is refused', () async {
    await expectLater(
      prepareImage(Uint8List.fromList(List.filled(64, 7))),
      throwsA(anything),
    );
  });
}
