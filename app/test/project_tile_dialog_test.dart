import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/project_tile_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_framer.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';

// Change tile… (ADR 0112): the dialog that sets a project's tile.

/// A button that opens Change tile… for garden, whose repository has an
/// icon, pressed: the dialog is open.
Future<Daemon> _changeTile(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([])..projectIcons[garden] = await iconPng(tester);
  final d = await fake.connect(tester);
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
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await decodeImages(tester);
  return d;
}

/// Waits on the real clock for the tile's picture and the framing's, then
/// for the Zoom slider to finish coming on (it's off until the picture is
/// there).
Future<void> _framed(WidgetTester tester) async {
  await untilReal(
    tester,
    () =>
        find.byType(RawImage).evaluate().isNotEmpty &&
        tester.state<TileFramerState>(find.byType(TileFramer)).decoded,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('Change tile… keeps an emoji or two letters and a color; '
      'Cancel keeps nothing, Reset forgets them', (tester) async {
    final d = await _changeTile(tester);
    ProjectTile preview() =>
        tester.widget(find.byKey(const Key('tile preview')));
    Button button(String label) =>
        tester.widget(find.widgetWithText(Button, label));
    // As it is by itself: the repository's icon; nothing to reset.
    expect(preview().look.isEmpty, isTrue);
    expect(preview().icon, isNotNull);
    expect(button('Reset').onPressed, isNull);

    // A third character doesn't go in; an emoji is one.
    await tester.enterText(find.byType(TextField), '🌱x');
    await tester.enterText(find.byType(TextField), '🌱xy');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '🌱x',
    );
    // An emoji entered into a full field (a picker's, pasted or typed at
    // the cursor) takes the letters' place instead of being refused.
    final field = tester.widget<TextField>(find.byType(TextField)).controller!;
    await tester.enterText(find.byType(TextField), 'ab');
    field.selection = const TextSelection.collapsed(offset: 2);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ab🦊',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();
    expect(field.text, '🦊');
    // One of several code points (a flag, a family) is one character.
    await tester.enterText(find.byType(TextField), '');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '👩‍👩‍👧🇯🇵',
        selection: TextSelection.collapsed(offset: 12),
      ),
    );
    await tester.pump();
    expect(field.text, '👩‍👩‍👧🇯🇵');
    // Pasted (what a picker that copies leaves to ⌘V), over two letters;
    // the test's platform pastes with Control.
    await tester.enterText(find.byType(TextField), 'ab');
    field.selection = const TextSelection.collapsed(offset: 2);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': '🦊'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(field.text, '🦊');
    await tester.enterText(find.byType(TextField), '🌱x');
    await tester.tap(find.byTooltip('Violet'));
    await tester.pump();
    expect(preview().look.toJson(), {'mark': '🌱x', 'color': 'violet'});
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ab ');
    await tester.tap(find.byTooltip('Teal'));
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeTileDialog), findsNothing);
    expect(projectTiles.value[garden]?.toJson(), {
      'mark': 'ab',
      'color': 'teal',
    });
    expect(readSaved()['projectTiles'], {
      garden: {'mark': 'ab', 'color': 'teal'},
    });

    // Open again, it has them; a color alone is kept too.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ab',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]?.toJson(), {'color': 'teal'});

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Reset'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);
    expect(readSaved()['projectTiles'], isEmpty);
    d.dispose();
  });

  testWidgets('Choose image… takes a picture, shown at once and kept as a '
      'copy on Save; one that can’t be taken is said, and what was there '
      'stays; Cancel keeps nothing', (tester) async {
    final before = pickTileImage;
    addTearDown(() => pickTileImage = before);
    final picks = Directory('$dataDir/picked')..createSync(recursive: true);
    final photo = File('${picks.path}/photo.png')
      ..writeAsBytesSync(await photoPng(tester));
    final gif = File('${picks.path}/spin.gif')..writeAsBytesSync(animatedGif());
    final text = File('${picks.path}/notes.png')..writeAsStringSync('hello');
    File? next = photo;
    pickTileImage = () async => next == null ? null : XFile(next.path);
    List<String> stored() => tileImagesDir.existsSync()
        ? [for (final f in tileImagesDir.listSync()) f.uri.pathSegments.last]
        : [];
    ProjectTile preview() =>
        tester.widget(find.byKey(const Key('tile preview')));
    Future<void> choose() async {
      await tester.tap(find.widgetWithText(Button, 'Choose image…'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    final d = await _changeTile(tester);
    expect(find.widgetWithText(Button, 'Remove image'), findsNothing);
    await choose();
    expect(preview().picture, isNotNull);
    expect(find.byType(RawImage), findsWidgets);
    expect(find.widgetWithText(Button, 'Remove image'), findsOneWidget);
    // Not kept yet: Cancel leaves no copy.
    expect(stored(), isEmpty);
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(stored(), isEmpty);
    expect(projectTiles.value, isEmpty);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await choose();
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    final first = projectTiles.value[garden]!.image;
    expect(stored(), [first]);
    expect(tileImageFile(first)!.readAsBytesSync(), photo.readAsBytesSync());
    expect(readSaved()['projectTiles'], {
      garden: {'image': first},
    });

    // Not an image: a line says so, and the one it had stays.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    next = text;
    await choose();
    expect(find.text('Not a PNG, JPEG, GIF or WebP image.'), findsOneWidget);
    expect(preview().look.image, first);
    expect(preview().picture, isNull);
    // The panel closed with nothing picked: nothing changes.
    next = null;
    await choose();
    expect(preview().look.image, first);
    // Another in its place: the line goes, and Save deletes the first.
    next = gif;
    await choose();
    expect(find.text('Not a PNG, JPEG, GIF or WebP image.'), findsNothing);
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    final second = projectTiles.value[garden]!.image;
    expect(second, endsWith('.gif'));
    expect(stored(), [second]);

    // Remove image, with a mark set: the mark stays, the copy goes.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'G');
    await tester.tap(find.widgetWithText(Button, 'Remove image'));
    await tester.pump();
    expect(find.widgetWithText(Button, 'Remove image'), findsNothing);
    expect(preview().look.image, '');
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]?.toJson(), {'mark': 'G'});
    expect(stored(), isEmpty);

    // Reset deletes an image's copy too.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    next = photo;
    await choose();
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(stored(), hasLength(1));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Reset'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);
    expect(stored(), isEmpty);
    d.dispose();
    picks.deleteSync(recursive: true);
  });

  testWidgets('an image is framed by a drag, a scroll and the Zoom slider, '
      'shown at once in the tile and kept beside the image on Save; Reset '
      'framing, another image or none put it back', (tester) async {
    final before = pickTileImage;
    addTearDown(() => pickTileImage = before);
    if (tileImagesDir.existsSync()) tileImagesDir.deleteSync(recursive: true);
    final image = keepTileImage((bytes: await photoPng(tester), kind: 'png'));
    projectTiles.value = {garden: TileLook(image: image)};
    ProjectTile preview() =>
        tester.widget(find.byKey(const Key('tile preview')));
    TileCrop? crop() => preview().look.crop;
    Button button(String label) =>
        tester.widget(find.widgetWithText(Button, label));
    final framing = find.byKey(const Key('tile framing'));

    final d = await _changeTile(tester);
    await _framed(tester);
    // From before framing: the middle, nothing to reset.
    expect(crop(), isNull);
    expect(button('Reset framing').onPressed, isNull);
    expect(tester.getSize(framing), const Size.square(TileFramer.size));

    // The Zoom slider: halfway is the square root of the most.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.5);
    await tester.pump();
    expect(crop()!.zoom, closeTo(sqrt(TileCrop.maxZoom), 1e-9));
    expect((crop()!.x, crop()!.y), (0.5, 0.5));
    expect(button('Reset framing').onPressed, isNotNull);
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      closeTo(0.5, 1e-9),
    );

    // A drag to the right shows more of the picture's left.
    final gesture = await tester.startGesture(tester.getCenter(framing));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump();
    final dragged = crop()!;
    expect(dragged.x, lessThan(0.5));
    expect(dragged.y, 0.5);
    expect(dragged.zoom, closeTo(sqrt(TileCrop.maxZoom), 1e-9));

    // A wheel's scroll up zooms in about the pointer; down, out.
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(framing);
    await tester.sendEventToBinding(wheel.hover(at));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -100)));
    await tester.pump();
    expect(crop()!.zoom, greaterThan(dragged.zoom));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 2000)));
    await tester.pump();
    expect(crop()!.zoom, 1);
    // A trackpad's two-finger scroll zooms too.
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.panZoomStart(at));
    await tester.sendEventToBinding(
      pad.panZoomUpdate(at, pan: const Offset(0, -60)),
    );
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump();
    expect(crop()!.zoom, greaterThan(1));
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    expect(crop()!.zoom, TileCrop.maxZoom);

    // Reset framing: the middle again, and it's off.
    await tester.tap(find.widgetWithText(Button, 'Reset framing'));
    await tester.pump();
    expect(crop(), isNull);
    expect(button('Reset framing').onPressed, isNull);

    // Saved: beside the image, and there when it's opened again.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.5);
    await tester.pump();
    final kept = crop()!;
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]!.crop, kept);
    expect(readSaved()['projectTiles'], {
      garden: {'image': image, 'crop': kept.toJson()},
    });
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _framed(tester);
    expect(crop(), kept);

    // Cancel keeps it as it was.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]!.crop, kept);

    // Another image starts from its middle.
    final picked = File('$dataDir/picked.png')
      ..writeAsBytesSync(await photoPng(tester, width: 200, height: 300));
    addTearDown(picked.deleteSync);
    pickTileImage = () async => XFile(picked.path);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Choose image…'));
    await untilReal(tester, () => preview().picture != null);
    expect(crop(), isNull);
    await _framed(tester);
    // A tall one moves up and down at zoom 1, not across.
    final tall = await tester.startGesture(tester.getCenter(framing));
    await tall.moveBy(const Offset(30, 30));
    await tall.moveBy(const Offset(30, 30));
    await tall.up();
    await tester.pump();
    expect(crop()!.zoom, 1);
    expect(crop()!.x, 0.5);
    expect(crop()!.y, lessThan(0.5));
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    final second = projectTiles.value[garden]!;
    expect(second.image, isNot(image));
    expect(second.crop, isNotNull);

    // No image, no framing.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(TileFramer), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'G');
    await tester.tap(find.widgetWithText(Button, 'Remove image'));
    await tester.pump();
    expect(find.byType(TileFramer), findsNothing);
    expect(crop(), isNull);
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
    for (final (shot, crop) in [
      ('image', null),
      ('framed', const TileCrop(zoom: 3, x: 0.45, y: 0.4)),
    ]) {
      testWidgets('golden: Change tile… with an image, $shot, $name', (
        tester,
      ) async {
        viewport(tester, const Size(640, 480));
        if (tileImagesDir.existsSync()) {
          tileImagesDir.deleteSync(recursive: true);
        }
        final image = keepTileImage((
          bytes: await photoPng(tester),
          kind: 'png',
        ));
        projectTiles.value = {
          garden: TileLook(color: 'teal', image: image, crop: crop),
        };
        final d = await _changeTile(tester, tokens: tokens);
        await _framed(tester);
        await expectLater(
          find.byType(ChangeTileDialog),
          matchesGoldenFile('goldens/project_tile_dialog_${shot}_$name.png'),
        );
        d.dispose();
        setProjectTile(garden, const TileLook());
      });
    }

    testWidgets('golden: Change tile…, $name', (tester) async {
      viewport(tester, const Size(640, 360));
      projectTiles.value = {garden: const TileLook(mark: 'G7', color: 'rust')};
      final d = await _changeTile(tester, tokens: tokens);
      await tester.tap(find.byTooltip('Violet'));
      await tester.pump();
      await expectLater(
        find.byType(ChangeTileDialog),
        matchesGoldenFile('goldens/project_tile_dialog_$name.png'),
      );
      d.dispose();
    });
  }
}
