import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'preview_fixture.dart';

// A README's HTML <img> logo and SVG images in the Files pane's Markdown
// preview (issue 69), looked at full size; made-up files.

const _readme = '''
<p align="center">
  <img src="docs/logo.svg" alt="Acme" width="96">
</p>

# <img src="docs/mark.png" alt="" width="24"> Acme

A tiny tea shop's site. ![Build: passing](docs/build.svg)

<img src="docs/hostile.svg" alt="A diagram">

Run `make serve` and open the page.
''';

/// A rounded square, the accent's violet, with a white leaf.
const _logo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7c5cff"/><stop offset="1" stop-color="#4b8bff"/>
    </linearGradient>
  </defs>
  <rect width="96" height="96" rx="22" fill="url(#g)"/>
  <path d="M30 64 C30 40 50 28 70 28 C70 52 56 66 34 66 Z" fill="#fff"/>
</svg>''';

/// A build badge: two halves and their words.
const _badge = '''
<svg xmlns="http://www.w3.org/2000/svg" width="110" height="20">
  <rect width="110" height="20" rx="4" fill="#555"/>
  <rect x="44" width="66" height="20" rx="4" fill="#3c1"/>
  <rect x="44" width="8" height="20" fill="#3c1"/>
  <text x="22" y="14" fill="#fff" font-family="IBM Plex Sans" font-size="11" text-anchor="middle">build</text>
  <text x="77" y="14" fill="#fff" font-family="IBM Plex Sans" font-size="11" text-anchor="middle">passing</text>
</svg>''';

/// One that would load from elsewhere: refused, shown as its alt text.
const _hostile = '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="40" height="40">
  <image xlink:href="https://example.com/track.png" width="40" height="40"/>
</svg>''';

/// The folder FakeDaemon says a file it serves is in (`fileNow`), which
/// the README's images are relative to; never shown.
const _served = '/Users/me/nushi';

/// [w]×[h] pixels of one color, as PNG.
Future<Uint8List> _png(int w, int h, int rgba) async {
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < px.length; i += 4) {
    px
      ..[i] = rgba >> 24 & 0xff
      ..[i + 1] = rgba >> 16 & 0xff
      ..[i + 2] = rgba >> 8 & 0xff
      ..[i + 3] = rgba & 0xff;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  setUpAll(loadFonts);

  for (final brightness in renderThemes) {
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      testWidgets('renders: a README with HTML and SVG images, $w, '
          '${brightness.name}', (tester) async {
        final mark = (await tester.runAsync(() => _png(48, 48, 0xF2A33AFF)))!;
        final fake = FakeDaemon([
          chat('c', 'claude', 'Tidy the README', folder: '/Users/me/acme'),
        ]);
        fake.files.addAll({
          'README.md': utf8.encode(_readme),
          '$_served/docs/logo.svg': utf8.encode(_logo),
          '$_served/docs/build.svg': utf8.encode(_badge),
          '$_served/docs/hostile.svg': utf8.encode(_hostile),
          '$_served/docs/mark.png': mark,
        });
        final d = await previewApp(
          tester,
          fake,
          size: Size(width, 900),
          brightness: brightness,
          file: 'README.md',
        );
        // The PNG decodes off the test's clock.
        await untilReal(
          tester,
          () => tester
              .widgetList<RawImage>(find.byType(RawImage))
              .every((r) => r.image != null),
          limit: const Duration(seconds: 5),
        );
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'md_images_${w}_${brightness.name}',
        );
        await closeView(tester, d);
        // A file watch ended as its stream closed waits 2 s to watch again.
        await tester.pump(const Duration(seconds: 2));
      }, variant: onMac);
    }
  }
}
