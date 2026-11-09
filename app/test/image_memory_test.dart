// What the Mac holds of a chat of 200 screenshots: the bytes in its items,
// the encoded bytes its rows show from, the decoded pixels, and what
// ChatImages keeps; opened, scrolled through top to bottom, and left for
// another chat. A measure, printed, with bounds. Before the Mac took
// images as references (ADR 0099) the items held 51.5 MB and every row
// its own copy (51.5 MB more), all 200 decoded and held (281 MB), and a
// chat left for another kept its items and their copies.
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _shots = 200;
const _shotBytes = 270000;

/// [_shots] screenshots of 1600×1000, each [_shotBytes] long (a PNG, then
/// what a decoder never reads, each its own).
Future<List<Uint8List>> _screenshots(WidgetTester tester) async {
  final png = (await tester.runAsync(() async {
    final r = ui.PictureRecorder();
    Canvas(r).drawRect(
      const Rect.fromLTWH(0, 0, 1600, 1000),
      Paint()..color = const Color(0xFF3366AA),
    );
    final image = await r.endRecording().toImage(1600, 1000);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  return [
    for (var i = 0; i < _shots; i++)
      Uint8List(_shotBytes)
        ..setAll(0, png)
        ..[_shotBytes - 1] = i % 256
        ..[_shotBytes - 2] = i ~/ 256,
  ];
}

/// [bytes] as the daemon sends them: inline, or with [ref] by their hash.
ImageData _image(Uint8List bytes, {required bool ref}) => ref
    ? ImageData(
        mimeType: 'image/png',
        sha256: sha256.convert(bytes).toString(),
        size: Int64(bytes.length),
        width: 1600,
        height: 1000,
      )
    : ImageData(mimeType: 'image/png', data: bytes);

/// Waits on the real clock for every image in the tree to decode.
Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

/// What the app holds of a chat's images: bytes in its items, the encoded
/// bytes its rows show from and those rows, the decoded pixels held and
/// cached, and what ChatImages keeps.
typedef _Held = ({
  int items,
  int shown,
  int rows,
  int live,
  int cached,
  int kept,
});

/// What [d] holds of chat [id]'s images now.
_Held _held(Daemon d, String id) {
  final shown = <Uint8List>{};
  for (final e in find.byType(ClickableImage).evaluate()) {
    final image = (e.widget as ClickableImage).image;
    if (image is MemoryImage) shown.add(image.bytes);
  }
  final cache = PaintingBinding.instance.imageCache;
  final each = cache.currentSize == 0
      ? 0
      : cache.currentSizeBytes ~/ cache.currentSize;
  return (
    items: d.chats[id]!.items.fold(
      0,
      (n, it) => n + it.images.fold(0, (n, i) => n + i.data.length),
    ),
    shown: shown.fold(0, (n, b) => n + b.length),
    rows: find.byType(ClickableImage).evaluate().length,
    live: cache.liveImageCount * each,
    cached: cache.currentSizeBytes,
    kept: d.images.bytes,
  );
}

String _mb(int n) => '${(n / (1 << 20)).toStringAsFixed(1)} MB';

String _said(String name, _Held h) =>
    '$name: items ${_mb(h.items)}, rows ${_mb(h.shown)} (${h.rows} '
    'images), decoded ${_mb(h.live)} held and ${_mb(h.cached)} cached, '
    'ChatImages ${_mb(h.kept)}';

void main() {
  setUpAll(loadFonts);

  testWidgets('a chat of 200 screenshots holds a few screens of them', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    final cache = PaintingBinding.instance.imageCache;
    final budget = cache.maximumSizeBytes;
    cache
      ..clear()
      ..clearLiveImages();
    addTearDown(() => cache.maximumSizeBytes = budget);
    limitImageCache(); // as the app starts
    expect(cache.maximumSizeBytes, lessThan(budget)); // Flutter's 100 MB
    viewport(tester, const Size(1700, 1000), ratio: 2);
    final shots = await _screenshots(tester);
    final c = chat('c', 'claude', 'Screenshots');
    final other = chat('o', 'claude', 'Other');
    final fake = FakeDaemon([c, other])
      ..answer = ((input) => switch (input) {
        GetChatRequest(chatId: 'c', :final imageRefs) => GetChatResponse(
          chat: c,
          items: [
            for (final (i, s) in shots.indexed)
              Item(
                id: 'a$i',
                kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                text: 'Screenshot $i',
                images: [_image(s, ref: imageRefs)],
              ),
          ],
        ),
        GetChatRequest() => GetChatResponse(chat: other),
        _ => null,
      });
    for (final s in shots) {
      fake.chatImages[sha256.convert(s).toString()] = _image(s, ref: false);
    }
    final d = await fake.connect(tester)
      ..select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _decode(tester);
    final opened = _held(d, 'c');

    // Every screen from the top down.
    final list = [
      for (final s in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      ))
        s.position,
    ].reduce((a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b);
    expect(list.maxScrollExtent, greaterThan(50000));
    for (var at = 0.0; at <= list.maxScrollExtent; at += 1000) {
      list.jumpTo(at);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _decode(tester);
    }
    final scrolled = _held(d, 'c');

    d.select('o');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final left = _held(d, 'c');

    final said = [
      _said('opened', opened),
      _said('scrolled through', scrolled),
      _said('left', left),
    ].join('\n');
    // The measure, for whoever runs it.
    // ignore: avoid_print
    print(said);
    for (final h in [opened, scrolled, left]) {
      expect(h.items, 0, reason: said);
      expect(h.rows, lessThan(30), reason: said);
      expect(h.cached, lessThanOrEqualTo(imageCacheBytes), reason: said);
      expect(h.kept, lessThanOrEqualTo(32 << 20), reason: said);
    }
    expect(left.rows, 0, reason: said);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
