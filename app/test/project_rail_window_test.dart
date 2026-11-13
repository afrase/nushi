import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_framer.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';
import 'sidebar_fixture.dart';

// The sidebar's project tiles in the whole window, and the project rail
// turned on, to look at:
// `make renders TEST=test/project_rail_window_test.dart`.

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  for (final width in [1700.0, 720.0]) {
    for (final brightness in Brightness.values) {
      final name = '${width.toInt()}_${brightness.name}';
      testWidgets('the window with the projects’ tiles, $name', (tester) async {
        viewport(tester, Size(width, 900), brightness: brightness);
        paneWidths.value = {};
        sidebarProjects.value = {'/Users/me/zeta'};
        // A mark and a color, an image of the user's own, an animated
        // one (at rest: its first frame), and a repository's icon.
        if (tileImagesDir.existsSync()) {
          tileImagesDir.deleteSync(recursive: true);
        }
        final photo = keepTileImage((
          bytes: await photoPng(tester, width: 1200, height: 800),
          kind: 'png',
        ));
        final gif = keepTileImage((bytes: animatedGif(), kind: 'gif'));
        addTearDown(() {
          dropTileImage(photo);
          dropTileImage(gif);
        });
        projectTiles.value = {
          cappy: const TileLook(mark: 'CR', color: 'teal'),
          notes: TileLook(
            image: photo,
            crop: const TileCrop(zoom: 3, x: 0.42, y: 0.38),
          ),
          attic: TileLook(image: gif),
        };
        final fake = FakeDaemon(arrangeChats())
          ..projectIcons[garden] = await iconPng(tester);
        final d = await fake.connect(tester);
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pump(const Duration(seconds: 1));
        await decodeImages(tester);
        await untilReal(
          tester,
          () => tester
              .stateList<TilePictureViewState>(find.byType(TilePictureView))
              .every((s) => s.decoded),
        );
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'tiles_$name');
        // No rail: New chat has the sidebar's width, and each project's
        // header its tile.
        expect(find.byType(ProjectRail), findsNothing);
        final sidebar = tester.getRect(find.byType(Sidebar));
        expect(
          tester.getRect(find.byType(WideButton)).left,
          sidebar.left + Sidebar.start,
        );
        expect(find.byType(FolderTile), findsNWidgets(6));

        // Change tile…, from a header's menu.
        await tester.tap(
          find.descendant(
            of: find.byType(Sidebar),
            matching: find.text('garden'),
          ),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await render(tester, find.byType(NushiApp), 'tiles_menu_$name');
        await tester.tap(find.text('Change tile…'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.enterText(find.byType(TextField), 'G7');
        await tester.tap(find.byTooltip('Amber'));
        await tester.pump();
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'tiles_dialog_$name');
        // With an image picked.
        final pick = pickTileImage;
        addTearDown(() => pickTileImage = pick);
        pickTileImage = () async => XFile(tileImageFile(photo)!.path);
        await tester.tap(find.widgetWithText(Button, 'Choose image…'));
        await tester.pump();
        await untilReal(
          tester,
          () =>
              find.widgetWithText(Button, 'Remove image').evaluate().isNotEmpty,
        );
        await untilReal(
          tester,
          () => tester
              .stateList<TilePictureViewState>(find.byType(TilePictureView))
              .every((s) => s.decoded),
        );
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'tiles_dialog_image_$name');
        // Framed: zoomed in and dragged, the tile showing it at once.
        await untilReal(
          tester,
          () => tester.state<TileFramerState>(find.byType(TileFramer)).decoded,
        );
        tester.widget<Slider>(find.byType(Slider)).onChanged!(0.55);
        await tester.pump();
        final framing = find.byKey(const Key('tile framing'));
        final drag = await tester.startGesture(tester.getCenter(framing));
        await drag.moveBy(const Offset(20, 10));
        await drag.moveBy(const Offset(20, 10));
        await drag.up();
        await tester.pump(const Duration(milliseconds: 300));
        await untilReal(
          tester,
          () => tester
              .stateList<TilePictureViewState>(find.byType(TilePictureView))
              .every((s) => s.decoded),
        );
        expectTextInside(tester, width);
        final dialog = tester.getRect(find.byType(Dialog));
        expect(tester.getRect(framing).right, lessThan(dialog.right));
        await render(
          tester,
          find.byType(NushiApp),
          'tiles_dialog_framed_$name',
        );
        await tester.tap(find.widgetWithText(Button, 'Save'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(projectTiles.value[garden]!.crop, isNotNull);
        await untilReal(
          tester,
          () => tester
              .stateList<TilePictureViewState>(find.byType(TilePictureView))
              .every((s) => s.decoded),
        );
        await render(tester, find.byType(NushiApp), 'tiles_framed_$name');
        await closeView(tester, d);
      }, variant: macOS);

      testWidgets('the window with the project rail, $name', (tester) async {
        viewport(tester, Size(width, 900), brightness: brightness);
        paneWidths.value = {};
        projectRail.value = true;
        sidebarProjects.value = {'/Users/me/zeta'};
        if (tileImagesDir.existsSync()) {
          tileImagesDir.deleteSync(recursive: true);
        }
        final photo = keepTileImage((
          bytes: await photoPng(tester, width: 1200, height: 800),
          kind: 'png',
        ));
        addTearDown(() => dropTileImage(photo));
        projectTiles.value = {
          cappy: const TileLook(mark: 'CR', color: 'teal'),
          // Framed on the disc's edge.
          notes: TileLook(
            image: photo,
            crop: const TileCrop(zoom: 3, x: 0.42, y: 0.38),
          ),
        };
        final fake = FakeDaemon(arrangeChats())
          ..projectIcons[garden] = await iconPng(tester);
        final d = await fake.connect(tester);
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pump(const Duration(seconds: 1));
        await decodeImages(tester);
        await untilReal(
          tester,
          () => tester
              .stateList<TilePictureViewState>(find.byType(TilePictureView))
              .every((s) => s.decoded),
        );
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'rail_$name');

        final sidebar = tester.getRect(find.byType(Sidebar));
        final rail = find.byType(ProjectRail);
        if (sidebar.width < ProjectRail.minSidebar) {
          // Too narrow for it: the chats keep the sidebar's width.
          expect(rail, findsNothing);
          await closeView(tester, d);
          return;
        }
        // The first tile is level with New chat, and as high.
        final all = tester.getRect(find.byTooltip('All projects'));
        final newChat = tester.getRect(find.byType(WideButton));
        expect(all.top, newChat.top);
        expect(all.height, newChat.height);
        expect(all.size, const Size.square(ProjectTile.large));
        // The tiles are as far from the window's edge as from the chats.
        expect(all.left - sidebar.left, newChat.left - all.right);
        // Nothing of the rail runs under the status card.
        final add = tester.getRect(find.byTooltip('Add project…'));
        expect(add.left, all.left);

        // Narrowed to a project.
        await tester.tap(find.byTooltip('ledger-poc\n$ledger'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'rail_one_$name');

        // Change tile…, from the tile's menu.
        await tester.tap(
          find.byTooltip('garden\n$garden'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'rail_menu_$name');
        await tester.tap(find.text('Change tile…'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.enterText(find.byType(TextField), 'G7');
        await tester.tap(find.byTooltip('Amber'));
        await tester.pump();
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'rail_tile_dialog_$name');
        await tester.tap(find.widgetWithText(Button, 'Save'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await closeView(tester, d);
      }, variant: macOS);
    }
  }
}
