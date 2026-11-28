/// Reading code's colour off the fills it is drawn on, in a picture of a
/// widget: what `diff_contrast_test` and `code_on_fill_test` share.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/contrast.dart';

/// Where [fill] is painted in [pixels] (an image [width] wide, RGBA):
/// each patch of it, a changed word's box or a changed line's band, as its
/// size and its bounding box. Specks under 400 pixels are left out.
List<(int, ({int x0, int y0, int x1, int y1}))> fillPatches(
  ByteData pixels,
  int width,
  Color fill,
) {
  final height = pixels.lengthInBytes ~/ (width * 4);
  final want = fill.toARGB32();
  final seen = Uint8List(width * height);
  final found = <(int, ({int x0, int y0, int x1, int y1}))>[];
  for (var start = 0; start < seen.length; start++) {
    if (seen[start] != 0 || !_near(pixelAt(pixels, start), want)) continue;
    var (x0, y0, x1, y1, size) = (width, height, -1, -1, 0);
    final stack = [start];
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final (x, y) = (i % width, i ~/ width);
      size++;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      for (final j in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (y > 0) i - width,
        if (y < height - 1) i + width,
      ]) {
        if (seen[j] == 0 && _near(pixelAt(pixels, j), want)) {
          seen[j] = 1;
          stack.add(j);
        }
      }
    }
    if (size >= 400) found.add((size, (x0: x0, y0: y0, x1: x1, y1: y1)));
  }
  return found;
}

/// The pixel at [i] of [pixels] (RGBA), as ARGB.
int pixelAt(ByteData pixels, int i) =>
    pixels.getUint8(i * 4 + 3) << 24 |
    pixels.getUint8(i * 4) << 16 |
    pixels.getUint8(i * 4 + 1) << 8 |
    pixels.getUint8(i * 4 + 2);

/// Each patch of [fill] in [pixels] (an image [width] wide, RGBA) and its
/// most contrasting pixel, largest patch first, with its box's left edge
/// (a changed line's band left of the code is the gutter's). A patch's
/// bounding box is read with the boxes of the [inside] fills' patches left
/// out (a changed line's band holds its changed words' boxes, whose text
/// is theirs), so what is left is the fill and the text drawn on it: the
/// most contrasting pixel is that text's colour, a glyph's core, which
/// antialiasing can only soften.
List<({double contrast, Color ink, Set<int> colors, int left})> textOn(
  ByteData pixels,
  int width,
  Color fill, {
  List<Color> inside = const [],
  int inset = 0,
}) {
  final masks = [
    for (final f in inside)
      for (final (_, box) in fillPatches(pixels, width, f)) box,
  ];
  bool masked(int x, int y) =>
      masks.any((m) => x >= m.x0 && x <= m.x1 && y >= m.y0 && y <= m.y1);
  final found =
      <(int, ({double contrast, Color ink, Set<int> colors, int left}))>[];
  for (final (size, box) in fillPatches(pixels, width, fill)) {
    var (most, ink) = (1.0, fill);
    final colors = <int>{};
    for (var y = box.y0 + inset; y <= box.y1 - inset; y++) {
      for (var x = box.x0 + inset; x <= box.x1 - inset; x++) {
        if (masked(x, y)) continue;
        final c = Color(pixelAt(pixels, y * width + x));
        colors.add(c.toARGB32());
        final r = contrast(c, fill);
        if (r > most) (most, ink) = (r, c);
      }
    }
    found.add((size, (contrast: most, ink: ink, colors: colors, left: box.x0)));
  }
  found.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, patch) in found) patch];
}

/// What the [RepaintBoundary] keyed `box` shows, at four times its size.
Future<(ByteData, int)> boxPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('box')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    try {
      final bytes = await image.toByteData();
      return (bytes!, image.width);
    } finally {
      image.dispose();
    }
  }))!;
}

/// Whether two ARGB colours are a step apart at most in each channel: a
/// fill blended by the GPU can round a channel the other way from
/// `Color.alphaBlend`.
bool _near(int a, int b) {
  for (var shift = 0; shift < 32; shift += 8) {
    if (((a >> shift & 0xFF) - (b >> shift & 0xFF)).abs() > 1) return false;
  }
  return true;
}
