import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_rail_fixture.dart';

// A project's tile (ADR 0112): what it shows, in which order, and its
// colors; the icons asked of the daemon once.

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  test('initials are the first letters of two words, or a word’s first '
      'two', () {
    expect(tileInitials('lumen'), 'LU');
    expect(tileInitials('lumen-docs'), 'LD');
    expect(tileInitials('nushi_poc.old'), 'NP');
    expect(tileInitials('nushiPoc'), 'NP');
    expect(tileInitials('x'), 'X');
    expect(tileInitials('7zip'), '7Z');
    expect(tileInitials('.config'), 'CO');
    expect(tileInitials('épée verte'), 'ÉV');
    expect(tileInitials('--'), '?');
    expect(tileInitials(''), '?');
  });

  test('a mark is two characters at most, an emoji one of them', () {
    expect(tileMark('  ab  '), 'ab');
    expect(tileMark('abc'), 'ab');
    expect(tileMark('👩‍🚀x'), '👩‍🚀x');
    expect(tileMark('🇫🇷🇩🇪🇮🇹'), '🇫🇷🇩🇪');
    expect(tileMark(''), '');
  });

  test('a saved look reads what it can, and nothing from anything else', () {
    expect(TileLook.read({'mark': 'abc', 'color': 'teal'})?.mark, 'ab');
    expect(TileLook.read({'mark': 'Z', 'color': 3})?.color, '');
    expect(TileLook.read({'color': 'teal'})?.toJson(), {'color': 'teal'});
    expect(TileLook.read({'mark': 7}), isNull);
    expect(TileLook.read('LU'), isNull);
    expect(TileLook.read(null), isNull);
  });

  test('up to eight projects each get a color of their own, kept as '
      'others join; a chosen one is counted', () {
    final folders = [for (var i = 0; i < 8; i++) '/Users/me/p$i'];
    final colors = tileColors(folders);
    expect(colors.values.toSet(), hasLength(8));
    // Those that joined first keep theirs as the rest come.
    for (var n = 1; n < 8; n++) {
      final some = tileColors(folders.sublist(0, n));
      expect(some, {for (final f in folders.sublist(0, n)) f: colors[f]});
    }
    // A ninth shares one; the user's choice is kept, and nobody else
    // takes it while another is free.
    expect(tileColors([...folders, '/Users/me/p8']).values.toSet().length, 8);
    final chosen = tileColors(folders.sublist(0, 4), chosen: {folders[3]: 5});
    expect(chosen[folders[3]], 5);
    expect(chosen.values.toSet(), hasLength(4));
  });

  testWidgets('a tile shows what the user set, else the repository’s icon, '
      'else initials', (tester) async {
    final icon = MemoryImage(await iconPng(tester));
    Future<void> show(TileLook look, {ImageProvider? icon}) async {
      await tester.pumpWidget(
        themed(
          Center(
            child: ProjectTile(
              name: 'lumen-docs',
              color: 2,
              look: look,
              icon: icon,
            ),
          ),
        ),
      );
      await decodeImages(tester);
    }

    await show(const TileLook());
    expect(find.text('LD'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await show(const TileLook(), icon: icon);
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.text('LD'), findsNothing);

    // Either of the user's wins over the icon.
    await show(const TileLook(mark: '🦊'), icon: icon);
    expect(find.text('🦊'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await show(const TileLook(color: 'rust'), icon: icon);
    expect(find.text('LD'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final box = tester.widget<Container>(
      find.ancestor(of: find.text('LD'), matching: find.byType(Container)),
    );
    expect((box.decoration! as BoxDecoration).color, Tokens.dark.avatars[4]);
  });

  testWidgets('an icon that can’t be drawn leaves the initials', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        Center(
          child: ProjectTile(
            name: 'lumen',
            color: 0,
            icon: MemoryImage(Uint8List.fromList([1, 2, 3, 4])),
          ),
        ),
      ),
    );
    // On the real clock, as a decode is; the failure is the tile's to
    // show, not the test's.
    await tester.runAsync(() async {
      final e = find.byType(Image).evaluate().single;
      await precacheImage((e.widget as Image).image, e, onError: (_, _) {});
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('LU'), findsOneWidget);
  });

  testWidgets('each folder’s icon is asked of the daemon once', (tester) async {
    final png = await iconPng(tester);
    final fake = FakeDaemon([])..projectIcons[garden] = png;
    final d = await fake.connect(tester);
    int asks() => fake.calls.whereType<GetProjectIconRequest>().length;

    expect(d.projectIcons.of(garden), isNull);
    expect(d.projectIcons.of(cappy), isNull);
    expect(d.projectIcons.of(''), isNull);
    var told = 0;
    d.projectIcons.addListener(() => told++);
    await tester.pump();
    expect(asks(), 2);
    expect(told, 1);
    expect(d.projectIcons.of(garden)?.bytes, png);
    expect(d.projectIcons.of(cappy), isNull);
    await tester.pump();
    expect(asks(), 2);
    d.dispose();
  });

  testWidgets('a daemon that can’t answer leaves no icon, and is asked '
      'again once it’s back', (tester) async {
    final png = await iconPng(tester);
    final fake = FakeDaemon([])..projectIcons[garden] = png;
    final d = await fake.connect(tester);
    fake.down = true;
    expect(d.projectIcons.of(garden), isNull);
    await tester.pump();
    expect(d.projectIcons.of(garden), isNull);
    await fake.restart(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(d.projectIcons.of(garden)?.bytes, png);
    d.dispose();
  });
}
