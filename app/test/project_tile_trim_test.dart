import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/project_tile_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_framer.dart';
import 'package:nushi/tile_frames.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';
import 'package:nushi/tile_trim.dart';
import 'package:nushi/tile_trimmer.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';

// Trimming an animated tile image in Change tile… (ADR 0112): the strip's
// handles, its playhead, Play, and what's kept.

/// A button that opens Change tile… for garden, pressed, and the image
/// it has decoded: the dialog is open, its framing and trimmer there.
Future<Daemon> _changeTile(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final d = await FakeDaemon([]).connect(tester);
  await tester.pumpWidget(
    themed(
      tokens: tokens,
      Builder(
        builder: (context) => Center(
          child: Button(
            label: 'Open',
            onPressed: () => changeTile(context, d, garden, color: 3),
          ),
        ),
      ),
    ),
  );
  await _open(tester);
  return d;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await _decoded(tester);
}

/// Waits on the real clock for the framing's picture, the tile's and the
/// strip (if it has one), then for the Zoom slider to come on.
Future<void> _decoded(WidgetTester tester) async {
  await untilReal(
    tester,
    () =>
        tester.state<TileFramerState>(find.byType(TileFramer)).decoded &&
        _frames(tester).loaded &&
        tester
            .stateList<TilePictureViewState>(find.byType(TilePictureView))
            .every((s) => s.decoded),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

TileFrames _frames(WidgetTester tester) =>
    tester.widget<TileFramer>(find.byType(TileFramer)).frames;

ProjectTile _preview(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('tile preview')));

/// Where [seconds] is across the strip.
Offset _at(WidgetTester tester, double seconds) {
  final strip = tester.getRect(find.byKey(const Key('tile trim strip')));
  final frames = _frames(tester);
  final inner = strip.width - 2 * TileTrimmer.handle;
  final part = seconds * 1000 / frames.length.inMilliseconds;
  return Offset(
    strip.left + TileTrimmer.handle + inner * part,
    strip.center.dy,
  );
}

/// A drag on the strip from [from] to [to], seconds or a handle.
Future<TestGesture> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
  await gesture.moveTo(to);
  await tester.pump();
  return gesture;
}

Offset _startHandle(WidgetTester tester) {
  final f = _frames(tester);
  return _at(tester, f.startOf(f.start).inMilliseconds / 1000) -
      const Offset(TileTrimmer.handle / 2, 0);
}

Offset _endHandle(WidgetTester tester) {
  final f = _frames(tester);
  return _at(tester, f.startOf(f.end).inMilliseconds / 1000) +
      const Offset(TileTrimmer.handle / 2, 0);
}

String _stored(int frames) =>
    keepTileImage((bytes: animatedGif(frames: frames, side: 32), kind: 'gif'));

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });
  setUp(() {
    if (tileImagesDir.existsSync()) tileImagesDir.deleteSync(recursive: true);
  });

  testWidgets('the handles trim the image, the times show while they '
      'move, and they can’t meet; the playhead scrubs within the trim', (
    tester,
  ) async {
    // Twelve frames of a tenth of a second.
    final image = _stored(12);
    projectTiles.value = {garden: TileLook(image: image)};
    final d = await _changeTile(tester);
    final f = _frames(tester);
    expect(f.count, 12);
    expect(f.length, const Duration(milliseconds: 1200));
    expect(_preview(tester).look.trim, isNull);
    expect(find.byType(TileTrimmer), findsOneWidget);

    // The start handle to 0.3 s.
    var drag = await _drag(tester, _startHandle(tester), _at(tester, 0.3));
    expect(find.text('0:00.3 – 0:01.2'), findsOneWidget);
    expect(f.playhead, 3);
    await drag.up();
    await tester.pump();
    expect(find.text('0:00.3 – 0:01.2'), findsNothing);
    expect(_preview(tester).look.trim, const TileTrim(3, 12));
    // The square shows the start again, as the tile will at rest.
    expect(f.playhead, 3);

    // The end handle to 0.8 s: the last frame kept shows while it moves.
    drag = await _drag(tester, _endHandle(tester), _at(tester, 0.8));
    expect(find.text('0:00.3 – 0:00.8'), findsOneWidget);
    expect(f.playhead, 7);
    await drag.up();
    await tester.pump();
    expect(_preview(tester).look.trim, const TileTrim(3, 8));

    // Past the end handle, the start stops two frames before it.
    drag = await _drag(tester, _startHandle(tester), _at(tester, 1.1));
    await drag.up();
    await tester.pump();
    expect(_preview(tester).look.trim, const TileTrim(6, 8));
    // And back: the handles at the ends keep every frame.
    drag = await _drag(tester, _startHandle(tester), _at(tester, -1));
    await drag.up();
    drag = await _drag(tester, _endHandle(tester), _at(tester, 5));
    await drag.up();
    await tester.pump();
    expect(_preview(tester).look.trim, isNull);

    // The playhead, within the trim.
    drag = await _drag(tester, _startHandle(tester), _at(tester, 0.2));
    await drag.up();
    drag = await _drag(tester, _endHandle(tester), _at(tester, 0.9));
    await drag.up();
    await tester.pump();
    drag = await _drag(tester, _at(tester, 0.45), _at(tester, 0.55));
    expect(f.playhead, 5);
    expect(find.text('0:00.5'), findsOneWidget);
    await drag.moveTo(_at(tester, 1.15));
    await tester.pump();
    expect(f.playhead, 8); // the last kept
    await drag.up();
    await tester.pump();
    expect(find.text('0:00.8'), findsNothing);
    // The framing square shows the frame at the playhead.
    await untilReal(tester, () => !f.frame.value!.debugDisposed);
    d.dispose();
  });

  testWidgets('Play plays only the trim, looping, and Pause stops it where '
      'it is; Save keeps the trim beside the image, Cancel doesn’t', (
    tester,
  ) async {
    final image = _stored(12);
    projectTiles.value = {
      garden: TileLook(image: image, trim: const TileTrim(4, 7)),
    };
    final d = await _changeTile(tester);
    final f = _frames(tester);
    expect((f.start, f.end, f.playhead), (4, 7, 4));
    expect(_preview(tester).look.trim, const TileTrim(4, 7));

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(f.playing, isTrue);
    expect(find.byTooltip('Pause'), findsOneWidget);
    final seen = [f.playhead];
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen.add(f.playhead);
    }
    expect(seen, [4, 5, 6, 4, 5, 6]);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(f.playing, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(f.playhead, 6);
    expect(find.byTooltip('Play'), findsOneWidget);
    // A handle moved stops it too.
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    final drag = await _drag(tester, _endHandle(tester), _at(tester, 1.0));
    await drag.up();
    await tester.pump();
    expect(f.playing, isFalse);
    expect(_preview(tester).look.trim, const TileTrim(4, 10));

    // Reset framing leaves the trim.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.5);
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, 'Reset framing'));
    await tester.pump();
    expect(_preview(tester).look.trim, const TileTrim(4, 10));

    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]!.trim, const TileTrim(4, 10));
    expect(readSaved()['projectTiles'], {
      garden: {
        'image': image,
        'trim': {'start': 4, 'end': 10},
      },
    });

    // Open again: as kept. Cancel keeps it as it was.
    await _open(tester);
    expect((_frames(tester).start, _frames(tester).end), (4, 10));
    final again = await _drag(tester, _startHandle(tester), _at(tester, 0));
    await again.up();
    await tester.pump();
    expect(_preview(tester).look.trim, const TileTrim(0, 10));
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]!.trim, const TileTrim(4, 10));
    d.dispose();
  });

  testWidgets('another image starts untrimmed; a still has no strip; '
      'Remove image takes the trim with it', (tester) async {
    final before = pickTileImage;
    addTearDown(() => pickTileImage = before);
    final image = _stored(12);
    projectTiles.value = {
      garden: TileLook(image: image, trim: const TileTrim(4, 7)),
    };
    final gif = File('$dataDir/other.gif')
      ..writeAsBytesSync(animatedGif(frames: 5, side: 16));
    final png = File('$dataDir/still.png')
      ..writeAsBytesSync(await photoPng(tester));
    addTearDown(() {
      gif.deleteSync();
      png.deleteSync();
    });
    final d = await _changeTile(tester);

    pickTileImage = () async => XFile(gif.path);
    await tester.tap(find.widgetWithText(Button, 'Choose image…'));
    await untilReal(tester, () => _preview(tester).picture != null);
    await _decoded(tester);
    expect(_frames(tester).count, 5);
    expect(_preview(tester).look.trim, isNull);

    pickTileImage = () async => XFile(png.path);
    await tester.tap(find.widgetWithText(Button, 'Choose image…'));
    await untilReal(tester, () => _frames(tester).count == 1);
    await _decoded(tester);
    expect(find.byType(TileTrimmer), findsNothing);
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();

    await _open(tester);
    await tester.tap(find.widgetWithText(Button, 'Remove image'));
    await tester.pump();
    expect(find.byType(TileTrimmer), findsNothing);
    expect(_preview(tester).look.trim, isNull);
    await tester.enterText(find.byType(TextField), 'G');
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(readSaved()['projectTiles'], {
      garden: {'mark': 'G'},
    });
    d.dispose();
    setProjectTile(garden, const TileLook());
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: Change tile… with a trimmed GIF, $name', (
      tester,
    ) async {
      viewport(tester, const Size(640, 560));
      final image = keepTileImage((bytes: ballGif(), kind: 'gif'));
      projectTiles.value = {
        garden: TileLook(
          color: 'teal',
          image: image,
          crop: const TileCrop(zoom: 1.5, x: 0.4, y: 0.4),
          trim: const TileTrim(5, 17),
        ),
      };
      final d = await _changeTile(tester, tokens: tokens);
      await expectLater(
        find.byType(ChangeTileDialog),
        matchesGoldenFile('goldens/project_tile_dialog_trim_$name.png'),
      );
      d.dispose();
      setProjectTile(garden, const TileLook());
    });
  }
}
