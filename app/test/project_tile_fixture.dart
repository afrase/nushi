import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The project rail's tests' folders and pictures (`project_rail_test.dart`,
// `project_tile_test.dart`): `sidebar_fixture.dart`'s chats are in these.

const ledger = '/Users/me/ledger-poc';
const cappy = '/Users/me/cappy';
const garden = '/Users/me/garden';
const notes = '/Users/me/notes';
const attic = '/Users/me/attic';

/// A repository's icon as the daemon would send it: a PNG 64 square, a
/// light disc on green, made on the real clock.
Future<Uint8List> iconPng(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final r = ui.PictureRecorder();
      Canvas(r)
        ..drawRect(
          const Rect.fromLTWH(0, 0, 64, 64),
          Paint()..color = const Color(0xFF2E7D4F),
        )
        ..drawCircle(
          const Offset(32, 32),
          18,
          Paint()..color = const Color(0xFFF3E9C6),
        );
      final image = await r.endRecording().toImage(64, 64);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

/// Waits on the real clock for every image in the tree to decode: until
/// one has, its tile shows the project's initials.
Future<void> decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

/// A picture as a user might pick for a tile: a PNG [width] by [height],
/// a diagonal of two colors with a dark disc in its middle, so a crop
/// from the middle keeps the disc.
Future<Uint8List> photoPng(
  WidgetTester tester, {
  int width = 400,
  int height = 200,
}) async => (await tester.runAsync(() async {
  final r = ui.PictureRecorder();
  final size = Size(width.toDouble(), height.toDouble());
  Canvas(r)
    ..drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          size.bottomRight(Offset.zero),
          const [Color(0xFFE8A33D), Color(0xFF3D6FE8)],
        ),
    )
    ..drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 4,
      Paint()..color = const Color(0xFF1B1C20),
    );
  final image = await r.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}))!;

/// An animated GIF made here, byte by byte: [frames] frames [side] square,
/// each one flat color of four (amber, blue, green, rose, in turn), a
/// tenth of a second each, looping for ever. With [screen], the image is
/// that square and its frames [side] square in its corner: a big image in
/// few bytes, as a flat GIF packs.
Uint8List animatedGif({int frames = 3, int side = 8, int? screen}) {
  final whole = screen ?? side;
  final out = BytesBuilder()
    ..add('GIF89a'.codeUnits)
    ..add([whole & 0xFF, whole >> 8, whole & 0xFF, whole >> 8])
    // A global table of four colors.
    ..add([0xF1, 0, 0])
    ..add([0xE8, 0xA3, 0x3D, 0x3D, 0x6F, 0xE8, 0x3D, 0xB8, 0x6A])
    ..add([0xE8, 0x5D, 0x8A])
    // Loop for ever.
    ..add([0x21, 0xFF, 0x0B])
    ..add('NETSCAPE2.0'.codeUnits)
    ..add([0x03, 0x01, 0x00, 0x00, 0x00]);
  for (var f = 0; f < frames; f++) {
    out
      // Its delay: ten hundredths of a second.
      ..add([0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00, 0x00, 0x00])
      ..add([0x2C, 0, 0, 0, 0])
      ..add([side & 0xFF, side >> 8, side & 0xFF, side >> 8, 0x00])
      // LZW from two-bit colors: codes of three bits, the table cleared
      // (4) every two pixels so they never grow; 5 ends it.
      ..add([0x02]);
    final codes = <int>[];
    for (var p = 0; p < side * side; p++) {
      if (p.isEven) codes.add(4);
      codes.add(f % 4);
    }
    codes.add(5);
    final packed = <int>[];
    var (bits, held) = (0, 0);
    for (final code in codes) {
      bits |= code << held;
      held += 3;
      while (held >= 8) {
        packed.add(bits & 0xFF);
        bits >>= 8;
        held -= 8;
      }
    }
    if (held > 0) packed.add(bits & 0xFF);
    for (var at = 0; at < packed.length; at += 255) {
      final block = packed.sublist(at, (at + 255).clamp(0, packed.length));
      out
        ..addByte(block.length)
        ..add(block);
    }
    out.addByte(0);
  }
  out.addByte(0x3B);
  return out.toBytes();
}
