import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/slop_draggable.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'project_tile_fixture.dart';
import 'sidebar_fixture.dart';

// The project rail's tiles move by dragging (ADR 0112), as the sidebar's
// project headers do: the order is the sidebar's own (`sidebarOrder`), so
// the list follows. A click is still a click, and All projects and Add
// project… stay put.

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

/// The projects' headers in the sidebar's list, top to bottom.
List<String> _headers(WidgetTester tester) => shownInOrder(tester, _names);

const _names = ['ledger-poc', 'cappy', 'garden', 'notes', 'attic'];

/// Presses [name]'s tile with the mouse and moves it, in small steps, to
/// [goal] (a height in the window), pumping each.
Future<TestGesture> _drag(WidgetTester tester, String name, double goal) async {
  var at = tester.getCenter(_tile(name));
  final down = goal > at.dy;
  final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
  while (down ? at.dy < goal : at.dy > goal) {
    at += Offset(0, down ? 6 : -6);
    await drag.moveTo(at);
    await tester.pump();
  }
  return drag;
}

/// The sidebar of `arrangedSidebar` with no chat pinned, so each
/// project's name shows only in its header: the projects, the newest chat
/// first, are ledger-poc, cappy, garden, notes and attic.
Future<(Daemon, FakeDaemon)> _sidebar(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  Size size = const Size(560, 700),
}) => arrangedSidebar(
  tester,
  chats: [for (final c in arrangeChats()) c..pin = 0],
  tokens: tokens,
  size: size,
);

double _top(WidgetTester tester, String name) =>
    tester.getRect(_tile(name)).top;

double _bottom(WidgetTester tester, String name) =>
    tester.getRect(_tile(name)).bottom;

void main() {
  setUpAll(loadFonts);
  setUp(() => projectRail.value = true);

  testWidgets('a tile dragged lands where it’s dropped: the sidebar’s '
      'order is saved, and its list follows', (tester) async {
    final (d, _) = await _sidebar(tester);
    const before = ['ledger-poc', 'cappy', 'garden', 'notes', 'attic'];
    expect(_tiles(tester), ['All projects', ...before, 'Add project…']);
    expect(_headers(tester), before);

    // Down: ledger-poc to the lower half of garden, after it.
    var drag = await _drag(tester, 'ledger-poc', _bottom(tester, 'garden'));
    await drag.up();
    await tester.pumpAndSettle();
    const once = ['cappy', 'garden', 'ledger-poc', 'notes', 'attic'];
    expect(sidebarOrder.value, [cappy, garden, ledger, notes, attic]);
    expect(readSaved()['sidebarOrder'], sidebarOrder.value);
    expect(_tiles(tester), ['All projects', ...once, 'Add project…']);
    expect(_headers(tester), once);
    // A move isn't a click: the sidebar isn't narrowed.
    expect(sidebarProject.value, isNull);

    // Up: attic to the upper half of cappy, first.
    drag = await _drag(tester, 'attic', _top(tester, 'cappy') + 4);
    await drag.up();
    await tester.pumpAndSettle();
    const twice = ['attic', 'cappy', 'garden', 'ledger-poc', 'notes'];
    expect(_tiles(tester), ['All projects', ...twice, 'Add project…']);
    expect(_headers(tester), twice);

    // A header dragged in the list moves the tile too: one order.
    expect(arrangeSidebar(d).folders, sidebarOrder.value);
    d.dispose();
  });

  testWidgets('a folder the order doesn’t name keeps its place among the '
      'others; No folder’s place is kept', (tester) async {
    // garden and notes are placed, '' (No folder) too; the rest aren't,
    // so they go first.
    sidebarOrder.value = [garden, '', notes];
    final (d, _) = await _sidebar(tester);
    const before = ['ledger-poc', 'cappy', 'attic', 'garden', 'notes'];
    expect(_tiles(tester), ['All projects', ...before, 'Add project…']);
    final drag = await _drag(tester, 'notes', _top(tester, 'cappy') + 4);
    await drag.up();
    await tester.pumpAndSettle();
    const after = ['ledger-poc', 'notes', 'cappy', 'attic', 'garden'];
    expect(_tiles(tester), ['All projects', ...after, 'Add project…']);
    expect(_headers(tester), after);
    expect(sidebarOrder.value, [ledger, '', notes, cappy, attic, garden]);
    d.dispose();
  });

  testWidgets('a click is still a click: a press that moves less than the '
      'drag waits for narrows to the project; the menu and tooltip are '
      'the tile’s', (tester) async {
    final (d, _) = await _sidebar(tester);
    final order = [...sidebarOrder.value];
    final at = tester.getCenter(_tile('garden'));
    final press = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
    await press.moveTo(at + const Offset(dragSlop - 1, 1));
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(sidebarProject.value, garden);
    expect(sidebarOrder.value, order);

    // Just past it, it's a drag: dropped where it was, nothing changes,
    // and it's no click.
    sidebarProject.value = null;
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
    await drag.moveTo(at + const Offset(0, dragSlop + 1));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(sidebarProject.value, isNull);
    expect(sidebarOrder.value, order);

    // A right-click opens its menu.
    await tester.tap(_tile('garden'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Change tile…'), findsOneWidget);
    expect(sidebarOrder.value, order);
    d.dispose();
  });

  testWidgets('All projects and Add project… stay put: neither drags, and '
      'a tile dragged over either lands at that end', (tester) async {
    final (d, _) = await _sidebar(tester);
    final all = tester.getRect(_tile('All projects'));
    final add = tester.getRect(_tile('Add project…'));

    // Over All projects: the gap opens at the top, under it.
    var drag = await _drag(tester, 'garden', all.center.dy);
    expect(tester.getRect(_tile('All projects')), all);
    expect(_top(tester, 'ledger-poc'), greaterThan(_top(tester, 'garden')));
    await drag.up();
    await tester.pumpAndSettle();
    expect(_tiles(tester), [
      'All projects',
      'garden',
      'ledger-poc',
      'cappy',
      'notes',
      'attic',
      'Add project…',
    ]);
    expect(tester.getRect(_tile('All projects')), all);

    // Over Add project…: last, over it.
    drag = await _drag(tester, 'cappy', add.center.dy);
    expect(tester.getRect(_tile('Add project…')), add);
    await drag.up();
    await tester.pumpAndSettle();
    expect(_tiles(tester), [
      'All projects',
      'garden',
      'ledger-poc',
      'notes',
      'attic',
      'cappy',
      'Add project…',
    ]);
    expect(tester.getRect(_tile('Add project…')), add);
    expect(sidebarOrder.value, [garden, ledger, notes, attic, cappy]);

    // All projects doesn't drag: pressed and moved over the tiles, it
    // moves nothing, and the release isn't its click.
    sidebarProject.value = garden;
    await tester.pumpAndSettle();
    final order = [...sidebarOrder.value];
    drag = await _drag(tester, 'All projects', _bottom(tester, 'garden'));
    await drag.up();
    await tester.pumpAndSettle();
    expect(sidebarOrder.value, order);
    expect(sidebarProject.value, garden);
    d.dispose();
  });

  testWidgets('a tile dragged to the rail’s bottom edge scrolls it', (
    tester,
  ) async {
    sidebarProjects.value = {
      for (final n in ['alpha', 'bravo', 'delta', 'echo']) '/Users/me/$n',
    };
    final (d, _) = await _sidebar(tester, size: const Size(560, 420));
    final rail = find.descendant(
      of: find.byType(ProjectRail),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(rail).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, 0);
    final edge = tester.getRect(rail).bottom;
    final drag = await _drag(tester, 'cappy', edge - 4);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(position.pixels, greaterThan(0));
    await drag.up();
    await tester.pumpAndSettle();
    d.dispose();
  });

  // A tile mid-drag: lifted under the pointer, faded where it was, and the
  // others moved apart where it would land.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: a tile mid-drag, $name', (tester) async {
      // The window is the sidebar: the lifted tile is drawn over it, in
      // the app's overlay.
      final (d, _) = await _sidebar(
        tester,
        tokens: tokens,
        size: const Size(260, 560),
      );
      final drag = await _drag(tester, 'cappy', _bottom(tester, 'notes') - 6);
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/project_rail_drag_$name.png'),
      );
      await drag.up();
      await tester.pumpAndSettle();
      d.dispose();
    });
  }
}
