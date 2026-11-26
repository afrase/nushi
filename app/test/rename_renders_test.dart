import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'rename_fixture.dart';

/// Every name edited in place, drawn as it's edited, in both themes: the
/// part of the window round each, and the sidebar's row twice as large.
void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final b in Brightness.values) {
    for (final (i, place) in renamePlaces.indexed) {
      final file = const ['row', 'header', 'tab', 'section', 'issue'][i];
      renderTest('${place.name}, renamed (${b.name})', (tester) async {
        final d = await renameApp(tester, brightness: b);
        await place.prepare?.call(tester);
        await place.start(tester, d);
        final field = tester.getRect(editing);
        final holder = tester.getRect(place.holder().first);
        await _crop(
          tester,
          Rect.fromLTRB(
            field.left - 240,
            holder.top - 8,
            field.left + 460,
            holder.bottom + 8,
          ),
          '${_stage}_${file}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }

    renderTest('the sidebar row renamed, twice as large (${b.name})', (
      tester,
    ) async {
      final place = renamePlaces.first;
      final d = await renameApp(tester, brightness: b, ratio: 2);
      await place.start(tester, d);
      await _crop(
        tester,
        tester.getRect(place.holder().first).inflate(12),
        'rename_${_stage}_${b.name}',
        scale: 2,
      );
      await closeView(tester, d);
    }, variant: onMac);
  }
}

/// `before` or `after` the change, as RENAME_STAGE says.
final String _stage = Platform.environment['RENAME_STAGE'] ?? 'after';

/// The window's picture in [rect] (clamped to the window), [scale] times
/// its points, as `<name>.png` in [rendersDir].
Future<void> _crop(
  WidgetTester tester,
  Rect rect,
  String name, {
  double scale = 1,
}) async {
  final dir = rendersDir;
  if (dir == null) return;
  final window = Offset.zero & tester.view.physicalSize;
  final ratio = tester.view.devicePixelRatio;
  final from = Rect.fromLTRB(
    rect.left * ratio,
    rect.top * ratio,
    rect.right * ratio,
    rect.bottom * ratio,
  ).intersect(window);
  await withRealShadows(tester, () async {
    final capture = captureImage(find.byType(NushiApp).evaluate().single);
    await tester.runAsync(() async {
      final image = await capture;
      final out = from.size * (scale / ratio);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        from,
        Offset.zero & out,
        Paint()..filterQuality = FilterQuality.none,
      );
      final cropped = await recorder.endRecording().toImage(
        out.width.round(),
        out.height.round(),
      );
      try {
        final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
        Directory(dir).createSync(recursive: true);
        File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      } finally {
        image.dispose();
        cropped.dispose();
      }
    });
  });
}
