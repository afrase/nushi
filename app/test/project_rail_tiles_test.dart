import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_rail_fixture.dart';

// The project rail's tiles (ADR 0112), each form of them in one picture.
// The rail in the sidebar is in `project_rail_test.dart`.

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  // Every form of a tile and of the rail's own, in a strip wide enough
  // that a golden isn't a few letters alone.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('tiles, $name', (tester) async {
      viewport(tester, const Size(560, 240));
      final icon = MemoryImage(await iconPng(tester));
      Widget rail(Widget child, {bool picked = false, int needs = 0}) =>
          RailTile(
            tooltip: '',
            picked: picked,
            onTap: () {},
            badge: TileBadge(needs),
            child: child,
          );
      ProjectTile tile(
        String name,
        int color, {
        TileLook look = const TileLook(),
        ImageProvider? icon,
        double size = ProjectTile.large,
      }) => ProjectTile(
        name: name,
        color: color,
        look: look,
        icon: icon,
        size: size,
      );
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          RepaintBoundary(
            key: const Key('shot'),
            child: ColoredBox(
              color: tokens.window,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    Row(
                      spacing: 14,
                      children: [
                        rail(tile('lumen', 0)),
                        rail(tile('lumen-docs', 2), picked: true),
                        rail(tile('nushi', 5), needs: 1),
                        rail(tile('dotfiles', 3), needs: 12),
                        rail(tile('garden', 1, icon: icon)),
                        rail(tile('garden', 1, icon: icon), picked: true),
                        rail(
                          tile(
                            'notes',
                            6,
                            look: const TileLook(mark: 'N7', color: 'green'),
                          ),
                        ),
                        rail(
                          tile('notes', 6, look: const TileLook(mark: '#!')),
                        ),
                        rail(
                          tile('notes', 6, look: const TileLook(color: 'rust')),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 14,
                      children: [
                        for (final (i, n) in [
                          'lumen',
                          'lumen-docs',
                          'nushi',
                          'dotfiles',
                          'attic',
                          'zeta',
                          'cappy',
                          'web',
                        ].indexed)
                          tile(n, i, size: ProjectTile.small),
                        tile('garden', 1, icon: icon, size: ProjectTile.small),
                        tile(
                          'notes',
                          6,
                          look: const TileLook(mark: '#!'),
                          size: ProjectTile.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await decodeImages(tester);
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/project_tiles_$name.png'),
      );
    });
  }
}
