import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';

import 'details_rail_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

/// The color at ([x], [y]) in logical points of [image], drawn at [ratio].
Color _at(ui.Image image, ByteData bytes, double x, double y, double ratio) {
  final i = ((y * ratio).floor() * image.width + (x * ratio).floor()) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  setUpAll(loadFonts);

  for (final (name, brightness, tokens) in [
    ('dark', Brightness.dark, Tokens.dark),
    ('light', Brightness.light, Tokens.light),
  ]) {
    testWidgets('a hairline sets the panel off from the chat, $name', (
      tester,
    ) async {
      final (d, _) = await railApp(tester, brightness: brightness);
      final left = tester.getRect(railPanel).left;
      final ratio = tester.view.devicePixelRatio;
      final element = find.byType(NushiApp).evaluate().single;
      await tester.runAsync(() async {
        final image = await captureImage(element);
        final bytes = (await image.toByteData())!;
        // Down the panel's whole height: the rule, then its own fill.
        for (final y in [100.0, 400.0, 900.0]) {
          expect(_at(image, bytes, left, y, ratio), tokens.borderSubtle);
          expect(_at(image, bytes, left + 4, y, ratio), tokens.base);
        }
        image.dispose();
      });
      await closeView(tester, d);
    }, variant: macOnly);
  }
}
