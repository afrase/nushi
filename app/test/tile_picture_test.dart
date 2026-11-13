import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';

// A tile's own image (ADR 0112): which files are taken, where the copy is
// kept and when it goes, the size it's decoded at, and an animated one
// playing only under the pointer.

/// A file of the tests' own, outside `tiles`: what a user would pick.
File _picked(String name, List<int> bytes) {
  final dir = Directory('$dataDir/picked')..createSync(recursive: true);
  return File('${dir.path}/$name')..writeAsBytesSync(bytes);
}

/// What `tiles` holds now.
List<String> _stored() => tileImagesDir.existsSync()
    ? [for (final f in tileImagesDir.listSync()) f.uri.pathSegments.last]
    : [];

/// [look]'s tile alone, [size] square, once its image is decoded.
Future<TilePictureViewState> _show(
  WidgetTester tester,
  TileLook look, {
  double size = ProjectTile.large,
}) async {
  await tester.pumpWidget(
    themed(
      Center(
        child: ProjectTile(name: 'lumen', color: 0, look: look, size: size),
      ),
    ),
  );
  await untilReal(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
  return tester.state(find.byType(TilePictureView));
}

ui.Image _drawn(WidgetTester tester) =>
    tester.widget<RawImage>(find.byType(RawImage)).image!;

/// Whether the pixel of what's drawn at [x], [y] is the photo's dark disc
/// (`photoPng`).
Future<bool> _dark(WidgetTester tester, int x, int y) async {
  final image = _drawn(tester);
  final data = await tester.runAsync(image.toByteData);
  final at = (y * image.width + x) * 4;
  return data!.getUint8(at) < 0x40 && data.getUint8(at + 2) < 0x40;
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    for (final dir in [tileImagesDir, Directory('$dataDir/picked')]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  test('an image’s kind is what its first bytes say', () {
    expect(
      tileImageKind([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
      'png',
    );
    expect(tileImageKind([0xFF, 0xD8, 0xFF, 0xE0]), 'jpg');
    expect(tileImageKind('GIF89a...'.codeUnits), 'gif');
    expect(tileImageKind('GIF87a...'.codeUnits), 'gif');
    expect(tileImageKind('RIFF\x10\x00\x00\x00WEBPVP8 '.codeUnits), 'webp');
    expect(tileImageKind('RIFF\x10\x00\x00\x00WAVEfmt '.codeUnits), isNull);
    expect(tileImageKind('<svg xmlns='.codeUnits), isNull);
    expect(tileImageKind('BM'.codeUnits), isNull);
    expect(tileImageKind(const []), isNull);
    expect(animatedGif().sublist(0, 6), 'GIF89a'.codeUnits);
  });

  test('a look keeps only an image name Nushi gave', () {
    const name = '00112233445566778899aabbccddeeff.gif';
    expect(TileLook.read({'image': name})?.toJson(), {'image': name});
    for (final other in ['../app.json', '/etc/hosts', 'a.png', '$name/x', 7]) {
      expect(TileLook.read({'image': other}), isNull, reason: '$other');
      expect(TileLook.read({'mark': 'A', 'image': other})?.image, '');
    }
    expect(tileImageFile('../app.json'), isNull);
    expect(tileImageFile(name)?.path, '${tileImagesDir.path}/$name');
  });

  testWidgets('a file picked is taken if it’s one of the four kinds, small '
      'enough and decodes; else it says why', (tester) async {
    final png = await photoPng(tester);
    Future<Object> read(FileSystemEntity file) async =>
        (await tester.runAsync(() async {
          try {
            return await readTileImage(file.path);
          } on TileImageRefused catch (e) {
            return e.why;
          }
        }))!;

    // By its bytes, whatever it's called.
    final good = await read(_picked('photo.txt', png)) as PickedImage;
    expect(good.kind, 'png');
    expect(good.bytes, png);
    expect(
      ((await read(_picked('a.gif', animatedGif()))) as PickedImage).kind,
      'gif',
    );
    // An animated one bigger than 4K: its frames come whole, so it's
    // refused by its header, before one is decoded. A still that big is
    // taken: it's decoded at a tile's size.
    expect(
      await read(_picked('big.gif', animatedGif(frames: 2, screen: 4000))),
      'That animated image has more pixels than 4K (3840 × 2160).',
    );
    expect(
      await read(_picked('big.gif', animatedGif(frames: 1, screen: 4000))),
      isA<PickedImage>(),
    );

    expect(
      await read(_picked('notes.png', 'not an image'.codeUnits)),
      'Not a PNG, JPEG, GIF or WebP image.',
    );
    expect(
      await read(_picked('logo.svg', '<svg xmlns="x"/>'.codeUnits)),
      'Not a PNG, JPEG, GIF or WebP image.',
    );
    // A PNG's first bytes, and nothing after that's one.
    expect(
      await read(_picked('cut.png', [...png.sublist(0, 24), 1, 2, 3])),
      'That image can’t be shown.',
    );
    // A PNG's start and then nothing, a byte past the most: never read.
    final large = _picked('large.png', const []);
    large.openSync(mode: FileMode.write)
      ..writeFromSync(png)
      ..truncateSync(maxTileImageBytes + 1)
      ..closeSync();
    expect(await read(large), 'That image is larger than 16 MB.');
    expect(
      await read(Directory('$dataDir/picked')),
      'That file can’t be read.',
    );
    expect(
      await read(File('$dataDir/picked/none.png')),
      'That file can’t be read.',
    );
    expect(_stored(), isEmpty);
  });

  testWidgets('a kept image is a copy in Nushi’s data, only the user’s; '
      'replaced, reset or its project removed, it’s deleted', (tester) async {
    final png = await photoPng(tester);
    final one = keepTileImage((bytes: png, kind: 'png'));
    expect(storedTileImage.hasMatch(one), isTrue);
    final file = tileImageFile(one)!;
    expect(file.readAsBytesSync(), png);
    expect(file.statSync().mode & 0x1FF, 0x180); // 0600
    expect(tileImagesDir.statSync().mode & 0x1FF, 0x1C0); // 0700

    setProjectTile(garden, TileLook(mark: 'G', image: one));
    // The same image again, with another color: kept.
    setProjectTile(garden, TileLook(mark: 'G', color: 'teal', image: one));
    expect(_stored(), [one]);
    // Another in its place.
    final two = keepTileImage((bytes: animatedGif(), kind: 'gif'));
    expect(two, isNot(one));
    setProjectTile(garden, TileLook(image: two));
    expect(_stored(), [two]);
    // None.
    setProjectTile(garden, const TileLook(mark: 'G'));
    expect(_stored(), isEmpty);

    final three = keepTileImage((bytes: png, kind: 'png'));
    setProjectTile(garden, TileLook(image: three));
    setProjectTile(garden, const TileLook()); // Reset
    expect(_stored(), isEmpty);
    expect(projectTiles.value, isEmpty);

    final four = keepTileImage((bytes: png, kind: 'png'));
    sidebarProjects.value = {garden};
    setProjectTile(garden, TileLook(image: four));
    forgetProject(garden); // Remove from sidebar
    expect(_stored(), isEmpty);

    // Nothing but a name of Nushi's is ever deleted.
    final other = File('$dataDir/keep.txt')..writeAsStringSync('mine');
    dropTileImage('../keep.txt');
    expect(other.existsSync(), isTrue);
    other.deleteSync();
  });

  testWidgets('an image is decoded at the tile’s size in the screen’s '
      'pixels, cropped from its middle, and comes before the mark', (
    tester,
  ) async {
    viewport(tester, const Size(300, 200), ratio: 2);
    final name = keepTileImage((bytes: await photoPng(tester), kind: 'png'));
    await _show(tester, TileLook(mark: 'LU', color: 'teal', image: name));
    // 400 × 200, in a tile 38 at two pixels a point: its shorter side 76.
    expect((_drawn(tester).width, _drawn(tester).height), (152, 76));
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.fit, BoxFit.cover);
    expect(tester.getSize(find.byType(RawImage)), const Size.square(38));
    expect(find.text('LU'), findsNothing);
    // A still image has nothing to play, and no pointer to watch.
    final state = tester.state<TilePictureViewState>(
      find.byType(TilePictureView),
    );
    expect(state.animated, isFalse);
    expect(
      find.descendant(
        of: find.byType(TilePictureView),
        matching: find.byType(MouseRegion),
      ),
      findsNothing,
    );
    // In a header's tile, at its size.
    await _show(tester, TileLook(image: name), size: ProjectTile.small);
    await untilReal(tester, () => _drawn(tester).height == 40);
    expect(_drawn(tester).width, 80);
  });

  testWidgets('a crop keeps only its square, at the tile’s size at most, '
      'and a new one shows the last until it’s decoded', (tester) async {
    viewport(tester, const Size(300, 200), ratio: 2);
    final name = keepTileImage((bytes: await photoPng(tester), kind: 'png'));
    // Zoomed four times on the disc in the middle: 50 of the picture's
    // pixels, fewer than the tile's 76, kept as they are.
    await _show(tester, TileLook(image: name, crop: const TileCrop(zoom: 4)));
    expect((_drawn(tester).width, _drawn(tester).height), (50, 50));
    expect(await _dark(tester, 0, 0), isTrue);
    expect(await _dark(tester, 49, 49), isTrue);
    expect(tester.getSize(find.byType(RawImage)), const Size.square(38));

    // Moved to the left edge: no disc. Until it's decoded, the last.
    final before = _drawn(tester);
    await tester.pumpWidget(
      themed(
        Center(
          child: ProjectTile(
            name: 'lumen',
            color: 0,
            look: TileLook(
              mark: 'LU',
              image: name,
              crop: const TileCrop(zoom: 4, x: 0),
            ),
          ),
        ),
      ),
    );
    expect(find.text('LU'), findsNothing);
    expect(_drawn(tester), same(before));
    await untilReal(tester, () => !identical(_drawn(tester), before));
    expect(await _dark(tester, 25, 25), isFalse);

    // A large one is decoded so the square is the tile's, then cut out.
    final large = keepTileImage((
      bytes: await photoPng(tester, width: 1600, height: 800),
      kind: 'png',
    ));
    await _show(tester, TileLook(image: large, crop: const TileCrop(zoom: 2)));
    await untilReal(tester, () => _drawn(tester).width == 76);
    expect(_drawn(tester).height, 76);
    expect(await _dark(tester, 38, 38), isTrue);
  });

  testWidgets('an image that’s gone, or can’t be decoded, leaves the mark', (
    tester,
  ) async {
    final name = keepTileImage((bytes: await photoPng(tester), kind: 'png'));
    tileImageFile(name)!.deleteSync();
    await tester.pumpWidget(
      themed(
        Center(
          child: ProjectTile(
            name: 'lumen',
            color: 0,
            look: TileLook(mark: 'LU', image: name),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('LU'), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
  });

  group('an animated image', () {
    late String name;
    setUp(() => name = keepTileImage((bytes: animatedGif(), kind: 'gif')));

    Future<TestGesture> mouse(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      return mouse;
    }

    testWidgets('shows its first frame at rest, with nothing running; '
        'plays while the pointer is on it; leaving, the first frame again', (
      tester,
    ) async {
      final state = await _show(tester, TileLook(image: name));
      final first = _drawn(tester);
      expect(state.animated, isTrue);
      expect(state.played, 0);
      expect(state.busy, isFalse);
      // At rest it asks for no frame, however long it's left.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_drawn(tester), same(first));
      // It's a layer of its own.
      expect(
        find.descendant(
          of: find.byType(TilePictureView),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );

      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);
      expect(state.busy, isTrue);
      // Each frame waits its tenth of a second, and it loops past the
      // third.
      for (var n = 2; n <= 5; n++) {
        await tester.pump(const Duration(milliseconds: 100));
        await untilReal(tester, () => state.played >= n);
      }
      expect(_drawn(tester), isNot(same(first)));

      await pointer.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(state.played, 0);
      expect(state.busy, isFalse);
      expect(_drawn(tester), same(first));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Again, from its start.
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);
      await pointer.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(state.busy, isFalse);
    });

    testWidgets('a large one is kept and played at the tile’s size, as a '
        'still is', (tester) async {
      viewport(tester, const Size(300, 200), ratio: 2);
      // The engine decodes an animated image's frames whole (400 square).
      final big = keepTileImage((
        bytes: animatedGif(frames: 2, screen: 400),
        kind: 'gif',
      ));
      final state = await _show(tester, TileLook(image: big));
      // A tile 38 square at two pixels a point.
      expect((_drawn(tester).width, _drawn(tester).height), (76, 76));
      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);
      for (var n = 2; n <= 3; n++) {
        await tester.pump(const Duration(milliseconds: 100));
        await untilReal(tester, () => state.played >= n);
        expect((_drawn(tester).width, _drawn(tester).height), (76, 76));
      }
      await pointer.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(state.busy, isFalse);
    });

    testWidgets('a cropped one plays its square, at the tile’s size', (
      tester,
    ) async {
      viewport(tester, const Size(300, 200), ratio: 2);
      final big = keepTileImage((
        bytes: animatedGif(frames: 2, screen: 400),
        kind: 'gif',
      ));
      const crop = TileCrop(zoom: 2, x: 0.25, y: 0.25);
      final state = await _show(tester, TileLook(image: big, crop: crop));
      expect((_drawn(tester).width, _drawn(tester).height), (76, 76));
      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);
      await tester.pump(const Duration(milliseconds: 100));
      await untilReal(tester, () => state.played >= 2);
      expect((_drawn(tester).width, _drawn(tester).height), (76, 76));
      await pointer.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(state.busy, isFalse);
    });

    testWidgets('never plays under Reduce Motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await _show(tester, TileLook(image: name));
      final first = _drawn(tester);
      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.played, 0);
      expect(state.busy, isFalse);
      expect(_drawn(tester), same(first));
    });

    testWidgets('stops while Nushi isn’t in front, and goes on when it’s '
        'back with the pointer still there', (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final state = await _show(tester, TileLook(image: name));
      final first = _drawn(tester);
      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(TilePictureView)));
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(state.played, 0);
      expect(_drawn(tester), same(first));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await untilReal(tester, () => state.played >= 1);

      // Taken away while it plays: nothing of it is left running.
      await tester.pumpWidget(const SizedBox());
      expect(state.busy, isFalse);
    });
  });
}
