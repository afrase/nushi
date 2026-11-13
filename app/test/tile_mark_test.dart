import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_mark.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A tile's mark is where its ink is in the middle of the tile (the owner
// saw an emoji low and left in one): what the tile painted is looked at,
// pixel by pixel, at both of a tile's sizes. Letters in the bundled font
// everywhere; an emoji only where the Mac's own emoji font is, which the
// tests' fonts don't have.

const _emojiFont = '/System/Library/Fonts/Apple Color Emoji.ttc';

/// The tile of [mark], [size] square, drawn alone at two pixels a point
/// with its ink measured: how far the middle of what it painted over its
/// fill is from the tile's own, in points.
Future<Offset> _offCentre(WidgetTester tester, String mark, double size) async {
  viewport(tester, const Size(200, 120), ratio: 2);
  final fill = Tokens.dark.avatars[2];
  await tester.pumpWidget(
    themed(
      // Its own color around it, so its round corners count for nothing.
      ColoredBox(
        color: fill,
        child: Center(
          child: RepaintBoundary(
            key: const Key('tile'),
            child: ProjectTile(
              name: 'x',
              color: 2,
              size: size,
              look: TileLook(mark: mark),
            ),
          ),
        ),
      ),
    ),
  );
  // The measuring is the engine's, on the real clock.
  await untilReal(tester, () => !measuringMarks);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('tile')),
  );
  final ink = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = (await image.toByteData())!;
    final (width, height) = (image.width, image.height);
    image.dispose();
    var (left, top, right, bottom) = (width, height, -1, -1);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final at = (y * width + x) * 4;
        final far =
            (data.getUint8(at) - (fill.r * 255).round()).abs() +
            (data.getUint8(at + 1) - (fill.g * 255).round()).abs() +
            (data.getUint8(at + 2) - (fill.b * 255).round()).abs();
        // More than an edge's faintest pixels.
        if (far < 96) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    return Rect.fromLTRB(left / 2, top / 2, (right + 1) / 2, (bottom + 1) / 2);
  }))!;
  expect(ink.width, greaterThan(2), reason: '$mark painted nothing');
  return ink.center - Offset(size / 2, size / 2);
}

void main() {
  setUpAll(loadFonts);
  setUp(() => centreMarksByInk = true);

  for (final size in [ProjectTile.large, ProjectTile.small]) {
    testWidgets('letters and signs are in the middle of a tile of '
        '${size.toInt()}', (tester) async {
      for (final mark in ['AB', 'LU', 'x', 'Jy', '#!', '7']) {
        final off = await _offCentre(tester, mark, size);
        expect(off.dx.abs(), lessThanOrEqualTo(0.5), reason: '$mark, across');
        expect(off.dy.abs(), lessThanOrEqualTo(0.5), reason: '$mark, down');
      }
    });

    testWidgets(
      'an emoji is in the middle of a tile of ${size.toInt()}',
      (tester) async {
        final font = FontLoader('Apple Color Emoji')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(_emojiFont).readAsBytesSync()),
            ),
          );
        await tester.runAsync(font.load);
        for (final mark in ['😄', '🦊', '🌱', '😄x']) {
          final off = await _offCentre(tester, mark, size);
          expect(off.dx.abs(), lessThanOrEqualTo(0.5), reason: '$mark, across');
          expect(off.dy.abs(), lessThanOrEqualTo(0.5), reason: '$mark, down');
        }
      },
      // Only where the Mac's emoji font is to be read: not Linux, nor a
      // Mac that keeps it elsewhere.
      skip: !File(_emojiFont).existsSync(),
    );
  }

  testWidgets('without the measuring, as a golden has it, a mark is '
      'centred by its line', (tester) async {
    centreMarksByInk = false;
    await tester.pumpWidget(
      themed(
        const Center(
          child: ProjectTile(
            name: 'x',
            color: 2,
            look: TileLook(mark: 'AB'),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('AB')),
      tester.getCenter(find.byType(ProjectTile)),
    );
  });
}
