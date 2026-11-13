import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';
import 'sidebar_fixture.dart';

// The project rail (ADR 0112), which Settings › Appearance turns on: its
// tiles and their order, narrowing the sidebar to a project, the badge,
// Add project…; and with it off, the sidebar as it was with a header's
// small tile, Change tile… and the Arrange menu's Add project… row. The
// whole window is in `project_rail_window_test.dart`.

/// The rail's tile of the project called [name], or of the rail's own
/// ("All projects", "Add project…").
Finder _tile(String name) => find.byWidgetPredicate(
  (w) =>
      w is RailTile && (w.tooltip == name || w.tooltip.startsWith('$name\n')),
);

/// The rail's tiles' names, top to bottom.
List<String> _tiles(WidgetTester tester) {
  final tiles = find.byType(RailTile).evaluate().toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a.widget))
          .dy
          .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
    );
  return [
    for (final e in tiles) (e.widget as RailTile).tooltip.split('\n').first,
  ];
}

/// The chats' titles the sidebar shows, top to bottom.
List<String> _chats(WidgetTester tester) => shownInOrder(tester, arrangeTitles);

Future<void> _press(WidgetTester tester, String tile) async {
  await tester.tap(_tile(tile));
  await tester.pumpAndSettle();
}

/// Opens the menu of [tile] (a right-click) and picks [entry].
Future<void> _menu(WidgetTester tester, String tile, [String? entry]) async {
  await tester.tap(_tile(tile), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
  if (entry == null) return;
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

/// The tile ringed, if one is.
String? _picked(WidgetTester tester) => tester
    .widgetList<RailTile>(find.byType(RailTile))
    .where((t) => t.picked)
    .map((t) => t.tooltip.split('\n').first)
    .singleOrNull;

void main() {
  setUpAll(loadFonts);
  // The rail is off at first (Settings › Appearance): on, for its tests.
  setUp(() => projectRail.value = true);

  testWidgets('the rail has All projects, the projects in the sidebar’s '
      'order, kept empty ones too, and Add project…', (tester) async {
    sidebarProjects.value = {'/Users/me/zeta'};
    sidebarOrder.value = [garden, '/Users/me/zeta', ledger];
    final (d, _) = await arrangedSidebar(tester);
    // cappy and notes aren't placed, so first; attic's one chat is pinned.
    final groups = arrangeSidebar(d).projects.keys;
    expect(groups, [cappy, notes, garden, '/Users/me/zeta', ledger, attic]);
    expect(_tiles(tester), [
      'All projects',
      'cappy',
      'notes',
      'garden',
      'zeta',
      'ledger-poc',
      'attic',
      'Add project…',
    ]);
    expect(_picked(tester), 'All projects');
    // A tile says its project's name and path.
    expect(tester.widget<RailTile>(_tile('garden')).tooltip, 'garden\n$garden');

    // The tiles are 38 square, in a column 48 wide, inside the sidebar.
    final sidebar = tester.getRect(find.byType(Sidebar));
    for (final e in find.byType(RailTile).evaluate()) {
      final box = tester.getRect(find.byWidget(e.widget));
      expect(box.size, const Size.square(ProjectTile.large));
      expect(box.left, sidebar.left + 13);
    }
    expect(tester.getSize(find.byType(ProjectRail)).width, ProjectRail.width);
    // The chats' rows start as far past the tiles as the tiles are in.
    final newChat = tester.getRect(find.byType(WideButton));
    expect(newChat.left - (sidebar.left + 13 + ProjectTile.large), 13);
    expect(newChat.right, sidebar.right - Sidebar.end);
    d.dispose();
  });

  testWidgets('a project’s tile narrows the sidebar to its chats, its '
      'pinned ones and its sections’ too; All projects shows all; the '
      'choice is kept', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['c', 'e']),
      Section(id: 's2', name: 'Later', chats: ['d']),
    ];
    final (d, _) = await arrangedSidebar(tester);
    const headers = ['Pinned', 'Reviews', 'Later', 'ledger-poc', 'attic'];
    List<String> shown() =>
        shownInOrder(tester, [...headers, ...arrangeTitles, 'No chats']);
    expect(_chats(tester), [
      'Keep this',
      'Cap the rates',
      'Jot it down',
      'Plant the beds',
      'Wire the ledger',
      'Seed data',
    ]);

    await _press(tester, 'ledger-poc');
    expect(_picked(tester), 'ledger-poc');
    expect(shown(), ['ledger-poc', 'Wire the ledger', 'Seed data']);
    expect(sidebarProject.value, ledger);
    expect(readSaved()['sidebarProject'], ledger);
    // ⌘1–⌘9 go through what shows.
    expect([for (final c in chatOrder(d)) c.id], ['a', 'b']);

    // A section shows the project's chats of it; one with none is left
    // out, and so is an empty Pinned.
    await _press(tester, 'cappy');
    expect(shown(), ['Reviews', 'Cap the rates']);
    await _press(tester, 'attic');
    expect(shown(), ['Pinned', 'Keep this', 'attic']);

    await _press(tester, 'All projects');
    expect(_picked(tester), 'All projects');
    expect(_chats(tester), hasLength(6));
    expect(readSaved()['sidebarProject'], isNull);
    d.dispose();
  });

  testWidgets('the tile picked at the last launch is still picked', (
    tester,
  ) async {
    sidebarProject.value = garden;
    final (d, _) = await arrangedSidebar(tester);
    expect(_picked(tester), 'garden');
    expect(_chats(tester), ['Plant the beds']);
    d.dispose();
  });

  testWidgets('narrowed to a project, the sidebar goes to another’s as a '
      'chat of it opens; a project removed shows all again', (tester) async {
    sidebarProject.value = cappy;
    final (d, fake) = await arrangedSidebar(tester);
    expect(_chats(tester), ['Cap the rates']);
    d.select('d');
    await tester.pumpAndSettle();
    expect(sidebarProject.value, garden);
    expect(_chats(tester), ['Plant the beds']);
    // The same project's: it stays.
    await _press(tester, 'ledger-poc');
    d.select('b');
    await tester.pumpAndSettle();
    expect(sidebarProject.value, ledger);

    // A tile picked while a chat is open stays picked.
    await _press(tester, 'notes');
    expect(_chats(tester), ['Jot it down']);
    expect(d.selectedId, 'b');

    fake.emit(
      EventsResponse(
        chatId: 'e',
        chat: fake.chats.firstWhere((c) => c.id == 'e')..archived = true,
      ),
    );
    await tester.pumpAndSettle();
    await _menu(tester, 'notes', 'Remove from sidebar');
    expect(sidebarProject.value, isNull);
    expect(_picked(tester), 'All projects');
    expect(_tiles(tester), isNot(contains('notes')));
    d.dispose();
  });

  // Deep review 2026-11-13, 14: the sidebar isn't built while it's
  // hidden, so a chat opened meanwhile wasn't followed.
  testWidgets('a chat of another project opened while the sidebar is '
      'hidden is followed once it shows', (tester) async {
    sidebarProject.value = cappy;
    viewport(tester, const Size(560, 700));
    final fake = FakeDaemon(arrangeChats());
    final d = await fake.connect(tester);
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: ValueListenableBuilder(
                valueListenable: shown,
                builder: (context, show, _) => show
                    ? ListenableBuilder(
                        listenable: d,
                        builder: (context, _) => Sidebar(daemon: d),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    d.select('c'); // cappy's
    await tester.pumpAndSettle();
    expect(sidebarProject.value, cappy);

    // Hidden and shown again with no other chat opened: as it was, and a
    // tile picked meanwhile stays picked.
    shown.value = false;
    await tester.pumpAndSettle();
    sidebarProject.value = notes;
    shown.value = true;
    await tester.pumpAndSettle();
    expect(sidebarProject.value, notes);

    shown.value = false;
    await tester.pumpAndSettle();
    d.select('d'); // garden's
    await tester.pumpAndSettle();
    shown.value = true;
    await tester.pumpAndSettle();
    expect(sidebarProject.value, garden);
    expect(_chats(tester), ['Plant the beds']);
    d.dispose();
  });

  testWidgets('a tile counts its project’s chats that need you, pinned '
      'ones too', (tester) async {
    final (d, fake) = await arrangedSidebar(tester);
    String? badge(String tile) => switch (find.descendant(
      of: _tile(tile),
      matching: find.descendant(
        of: find.byKey(const Key('tile badge')),
        matching: find.byType(Text),
      ),
    )) {
      final f when f.evaluate().isNotEmpty => tester.widget<Text>(f).data,
      _ => null,
    };
    expect(badge('ledger-poc'), '1');
    expect(badge('cappy'), isNull);
    expect(badge('attic'), isNull);

    Future<void> waits(String id, {bool waiting = true}) async {
      fake.emit(
        EventsResponse(
          chatId: id,
          chat: fake.chats.firstWhere((c) => c.id == id)
            ..status = ChatStatus(busy: waiting, waiting: waiting),
        ),
      );
      await tester.pumpAndSettle();
    }

    await waits('b');
    expect(badge('ledger-poc'), '2');
    await waits('p'); // attic's pinned chat
    expect(badge('attic'), '1');
    await waits('a', waiting: false);
    await waits('b', waiting: false);
    expect(badge('ledger-poc'), isNull);
    // At its tile's top right corner, a little past it.
    final tile = tester.getRect(_tile('attic'));
    final mark = tester.getRect(find.byKey(const Key('tile badge')));
    expect(mark.right, greaterThan(tile.right));
    expect(mark.top, lessThan(tile.top));
    expect(
      mark.right,
      lessThanOrEqualTo(tester.getRect(find.byType(ProjectRail)).right + 4),
    );
    d.dispose();
  });

  testWidgets('Add project… adds the folder picked, and starts no chat', (
    tester,
  ) async {
    final before = chooseProjectFolder;
    addTearDown(() => chooseProjectFolder = before);
    String? picks = '/Users/me/fresh-start';
    chooseProjectFolder = () async => picks;
    final (d, fake) = await arrangedSidebar(tester);
    await _press(tester, 'Add project…');
    expect(sidebarProjects.value, contains('/Users/me/fresh-start'));
    expect(_tiles(tester), containsAllInOrder(['attic', 'fresh-start']));
    expect(find.text('fresh-start'), findsOneWidget);
    expect(fake.started, isEmpty);
    expect(
      tester
          .widget<ProjectTile>(
            find.descendant(
              of: _tile('fresh-start'),
              matching: find.byType(ProjectTile),
            ),
          )
          .name,
      'fresh-start',
    );

    // Its menu is its header's, and Change tile….
    await _menu(tester, 'fresh-start');
    for (final entry in [
      'New chat here',
      'Open in terminal',
      'Remove from sidebar',
      'Change tile…',
    ]) {
      expect(find.text(entry), findsOneWidget);
    }
    await tester.tap(find.text('Remove from sidebar'));
    await tester.pumpAndSettle();
    expect(_tiles(tester), isNot(contains('fresh-start')));

    // The panel closed without a folder: nothing is added.
    picks = null;
    final had = sidebarProjects.value;
    await _press(tester, 'Add project…');
    expect(sidebarProjects.value, had);
    d.dispose();
  });

  testWidgets('with the rail off the sidebar is as it was, with the '
      'headers’ tiles: no rail, every project, a stored pick ignored', (
    tester,
  ) async {
    projectRail.value = false;
    sidebarProject.value = cappy;
    final (d, _) = await arrangedSidebar(tester);
    expect(find.byType(ProjectRail), findsNothing);
    expect(railShows, isFalse);
    expect(shownProject, isNull);
    expect(_chats(tester), hasLength(6));
    expect([for (final c in chatOrder(d)) c.id], hasLength(6));
    // New chat and the rows have the sidebar's whole width.
    final sidebar = tester.getRect(find.byType(Sidebar));
    final newChat = tester.getRect(find.byType(WideButton));
    expect(newChat.left, sidebar.left + Sidebar.start);
    expect(newChat.right, sidebar.right - Sidebar.end);
    expect(find.byType(FolderTile), findsNWidgets(5));
    // A chat of another project opening moves no pick.
    d.select('d');
    await tester.pumpAndSettle();
    expect(sidebarProject.value, cappy);
    expect(_chats(tester), hasLength(6));
    d.dispose();
  });

  testWidgets('turned on and off, the rail comes and goes, the pick with '
      'it; the sidebar’s buttons and edge stay; none by Date', (tester) async {
    sidebarProject.value = cappy;
    final (d, _) = await arrangedSidebar(tester);
    final arrange = find.byTooltip(RegExp('^Arrange the sidebar'));
    expect(find.byType(ProjectRail), findsOneWidget);
    expect(_chats(tester), ['Cap the rates']);
    final button = tester.getRect(arrange);
    final withRail = tester.getRect(find.byType(WideButton));

    projectRail.value = false;
    await tester.pumpAndSettle();
    expect(readSaved()['projectRailOn'], isFalse);
    expect(find.byType(ProjectRail), findsNothing);
    expect(_chats(tester), hasLength(6));
    expect(tester.getRect(arrange), button);
    final without = tester.getRect(find.byType(WideButton));
    expect(without.right, withRail.right);
    expect(without.left, Sidebar.start);

    projectRail.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(ProjectRail), findsOneWidget);
    expect(_chats(tester), ['Cap the rates']);

    // The rail is the projects': none by Date.
    sidebarGroupBy.value = GroupBy.date;
    await tester.pumpAndSettle();
    expect(find.byType(ProjectRail), findsNothing);
    expect(_chats(tester), hasLength(6));
    expect(tester.getRect(arrange), button);
    d.dispose();
  });

  testWidgets('the Arrange menu’s Add project… adds the folder picked, '
      'with the rail off; by Project only', (tester) async {
    projectRail.value = false;
    final before = chooseProjectFolder;
    addTearDown(() => chooseProjectFolder = before);
    chooseProjectFolder = () async => '/Users/me/fresh-start';
    final (d, fake) = await arrangedSidebar(tester);
    final arrange = find.byTooltip(RegExp('^Arrange the sidebar'));
    await tester.tap(arrange);
    await tester.pumpAndSettle();
    expect(find.text('Project rail'), findsNothing);
    await tester.tap(find.text('Add project…'));
    await tester.pumpAndSettle();
    expect(sidebarProjects.value, contains('/Users/me/fresh-start'));
    expect(fake.started, isEmpty);
    // Its group, empty, with its tile.
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('fresh-start'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FolderTile), findsNWidgets(6));

    sidebarGroupBy.value = GroupBy.date;
    await tester.pumpAndSettle();
    await tester.tap(arrange);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Only when grouped by Project'), findsOneWidget);
    expect(
      tester
          .widget<MenuItemButton>(
            find.ancestor(
              of: find.text('Add project…'),
              matching: find.byType(MenuItemButton),
            ),
          )
          .onPressed,
      isNull,
    );
    d.dispose();
  });

  testWidgets('a sidebar too narrow for the rail has none, and shows '
      'every project', (tester) async {
    sidebarProject.value = cappy;
    final (d, _) = await arrangedSidebar(tester, width: 240);
    expect(find.byType(ProjectRail), findsNothing);
    expect(railShows, isFalse);
    expect(_chats(tester), hasLength(6));
    expect(sidebarProject.value, cappy); // kept, for when there's room
    d.dispose();
  });

  testWidgets('a project’s header starts with its tile, small', (tester) async {
    final (d, _) = await arrangedSidebar(
      tester,
      icons: {garden: await iconPng(tester)},
    );
    await decodeImages(tester);
    for (final name in ['ledger-poc', 'cappy', 'garden', 'notes', 'attic']) {
      final small = find.byWidgetPredicate(
        (w) =>
            w is ProjectTile && w.name == name && w.size == ProjectTile.small,
      );
      expect(small, findsOneWidget, reason: name);
      final box = tester.getRect(small);
      final label = tester.getRect(
        find
            .descendant(
              of: find.byType(Sidebar),
              matching: find.textContaining(RegExp('^$name\$')),
            )
            .last,
      );
      expect(box.size, const Size.square(ProjectTile.small));
      expect(box.right, lessThan(label.left));
      expect(box.center.dy, moreOrLessEquals(label.center.dy, epsilon: 1.5));
      // The same color as its tile in the rail.
      final large = tester.widget<ProjectTile>(
        find.descendant(of: _tile(name), matching: find.byType(ProjectTile)),
      );
      expect(tester.widget<ProjectTile>(small).color, large.color);
    }
    // Pinned and a section have none.
    expect(find.byType(FolderTile), findsNWidgets(10));
    d.dispose();
  });

  testWidgets('Change tile… sets an emoji or letters and a color, which '
      'win over the repository’s icon; Reset puts it back', (tester) async {
    final (d, _) = await arrangedSidebar(
      tester,
      icons: {garden: await iconPng(tester)},
    );
    await decodeImages(tester);
    Finder inTile(Finder what) =>
        find.descendant(of: _tile('garden'), matching: what);
    expect(inTile(find.byType(RawImage)), findsOneWidget);
    expect(inTile(find.text('GA')), findsNothing);

    await _menu(tester, 'garden', 'Change tile…');
    expect(find.text('Change tile'), findsOneWidget);
    // Three characters don't go in.
    await tester.enterText(find.byType(TextField), '🌱x');
    await tester.enterText(find.byType(TextField), '🌱xy');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '🌱x',
    );
    await tester.enterText(find.byType(TextField), '🌱');
    await tester.tap(find.byTooltip('Violet'));
    await tester.pump();
    // The dialog shows the tile as it will be.
    final preview = tester.widget<ProjectTile>(
      find.byKey(const Key('tile preview')),
    );
    expect(preview.look.mark, '🌱');
    expect(preview.look.color, 'violet');
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();

    expect(projectTiles.value[garden]?.toJson(), {
      'mark': '🌱',
      'color': 'violet',
    });
    expect(readSaved()['projectTiles'], {
      garden: {'mark': '🌱', 'color': 'violet'},
    });
    expect(inTile(find.text('🌱')), findsOneWidget);
    expect(inTile(find.byType(Image)), findsNothing);
    // Its header's small tile is the same.
    expect(find.text('🌱'), findsNWidgets(2));

    // The header's menu has it too; Cancel changes nothing.
    await tester.tap(
      find.descendant(of: find.byType(Sidebar), matching: find.text('garden')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change tile…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'G');
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]?.mark, '🌱');

    await _menu(tester, 'garden', 'Change tile…');
    await tester.tap(find.widgetWithText(Button, 'Reset'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);
    await decodeImages(tester);
    expect(inTile(find.byType(RawImage)), findsOneWidget);
    d.dispose();
  });

  // The rail in the sidebar: all the projects, then narrowed to one.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the sidebar with its rail, $name', (tester) async {
      sidebarProjects.value = {'/Users/me/zeta'};
      projectTiles.value = {cappy: const TileLook(mark: 'CR', color: 'teal')};
      final (d, _) = await arrangedSidebar(
        tester,
        tokens: tokens,
        icons: {garden: await iconPng(tester)},
      );
      await decodeImages(tester);
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/project_rail_$name.png'),
      );
      await _press(tester, 'ledger-poc');
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/project_rail_one_$name.png'),
      );
      d.dispose();
    });
  }
}
