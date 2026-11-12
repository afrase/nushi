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
