import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_row.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'sidebar_fixture.dart';

// Pinned while the sidebar is narrowed to a project in the rail (ADR
// 0112): every project's pins at first, each of another project marked
// with its tile and name (Settings › Appearance's Pinned from every
// project); off, only the shown project's. Renders to look at:
// `make renders TEST=test/sidebar_pins_every_test.dart`.

const _ledger = '/Users/me/parcel-poc';

/// The fixture's chats, parcel-poc's Wire the parcel pinned under attic's
/// Keep this, and a chat with no folder pinned last.
List<Chat> _chats() => [
  for (final c in arrangeChats())
    if (c.id == 'a') (c..pin = 2) else c,
  Chat(
    id: 's',
    agent: 'claude',
    title: 'Scratch notes',
    folder: '/tmp/scratch-1',
    scratch: true,
    pin: 3,
  ),
];

/// The row of the chat called [title].
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SidebarRow));

/// What the row of [title] says of its project: its tile's folder, if it
/// has one, and the project's name after its title.
(String?, bool) _mark(WidgetTester tester, String title, String project) {
  final tile = find.descendant(
    of: _row(title),
    matching: find.byType(FolderTile),
  );
  return (
    tile.evaluate().isEmpty ? null : tester.widget<FolderTile>(tile).folder,
    find
        .descendant(of: _row(title), matching: find.text(project))
        .evaluate()
        .isNotEmpty,
  );
}

List<String> _shown(WidgetTester tester) =>
    shownInOrder(tester, ['Pinned', ...arrangeTitles, 'Scratch notes']);

void main() {
  setUpAll(loadFonts);
  setUp(() {
    projectRail.value = true;
    // Only the project's name says it: what Show has doesn't hide it.
    sidebarShows.value = {...sidebarShows.value}..remove(RowPart.project);
  });

  testWidgets('narrowed to a project, Pinned shows every project’s pins, '
      'each of another marked with its tile and name; off, only its own', (
    tester,
  ) async {
    expect(pinnedEveryProject.value, isTrue);
    sidebarProject.value = _ledger;
    final (d, _) = await arrangedSidebar(tester, chats: _chats());
    expect(_shown(tester), [
      'Pinned',
      'Keep this',
      'Wire the parcel',
      'Scratch notes',
      'Seed data',
    ]);
    expect(_mark(tester, 'Keep this', 'attic'), ('/Users/me/attic', true));
    expect(_mark(tester, 'Scratch notes', 'No folder'), (null, true));
    // The shown project's own pin is as it was.
    expect(_mark(tester, 'Wire the parcel', 'parcel-poc'), (null, false));
    // ⌘1–⌘9 and ⌥⌘↑↓ go through the rows shown.
    expect([for (final c in chatOrder(d)) c.id], ['p', 'a', 's', 'b']);

    pinnedEveryProject.value = false;
    await tester.pumpAndSettle();
    expect(_shown(tester), ['Pinned', 'Wire the parcel', 'Seed data']);
    expect([for (final c in chatOrder(d)) c.id], ['a', 'b']);

    // All projects: none is marked, as before.
    pinnedEveryProject.value = true;
    sidebarProject.value = null;
    await tester.pumpAndSettle();
    expect(_mark(tester, 'Keep this', 'attic'), (null, false));
    d.dispose();
  });

  testWidgets('a pin of another project opens its chat and the sidebar '
      'stays on the project picked; off, it goes to the pin’s', (tester) async {
    sidebarProject.value = _ledger;
    final (d, _) = await arrangedSidebar(tester, chats: _chats());
    d.select('a');
    await tester.pumpAndSettle();
    stepChat(d, -1); // the row above: attic's pin
    await tester.pumpAndSettle();
    expect(d.selectedId, 'p');
    expect(sidebarProject.value, _ledger, reason: 'a look in, not a move');
    expect(_mark(tester, 'Keep this', 'attic').$1, '/Users/me/attic');
    // Back to the project's own chat, then the pin by a click: the same.
    await tester.tap(_row('Wire the parcel'));
    await tester.pumpAndSettle();
    await tester.tap(_row('Keep this'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'p');
    expect(sidebarProject.value, _ledger);

    // Off, Pinned is the picked project's only, and the open chat's
    // project is followed as any other's is.
    d.select('a');
    await tester.pumpAndSettle();
    pinnedEveryProject.value = false;
    await tester.pumpAndSettle();
    d.select('p');
    await tester.pumpAndSettle();
    expect(sidebarProject.value, '/Users/me/attic');
    d.dispose();
  });

  testWidgets('Pinned collapsed shows only the open chat, another '
      'project’s too', (tester) async {
    final (d, _) = await arrangedSidebar(tester, chats: _chats());
    d.select('p');
    await tester.pumpAndSettle();
    // A tile picked with a chat open stays picked.
    sidebarProject.value = _ledger;
    pinnedCollapsed.value = true;
    await tester.pumpAndSettle();
    expect(_shown(tester), ['Pinned', 'Keep this', 'Seed data']);
    expect(_mark(tester, 'Keep this', 'attic'), ('/Users/me/attic', true));
    expect([for (final c in chatOrder(d)) c.id], ['p', 'b']);
    pinnedEveryProject.value = false;
    await tester.pumpAndSettle();
    expect(_shown(tester), ['Pinned', 'Seed data']);
    d.dispose();
  });

  testWidgets('Pinned from every project is a switch in Appearance, on at '
      'first, kept once set', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.appearance,
    );
    final row = find.widgetWithText(SettingsRow, 'Pinned from every project');
    final toggle = find.descendant(
      of: row,
      matching: find.byType(SettingsSwitch),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsSwitch>(toggle).value, isTrue);
    final at = tester.getRect(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(pinnedEveryProject.value, isFalse);
    expect(readSaved()['pinnedEveryProject'], isFalse);
    expect(tester.getRect(toggle), at); // it doesn't move
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(pinnedEveryProject.value, isTrue);
    expect(readSaved()['pinnedEveryProject'], isTrue);
    d.dispose();
  }, variant: onMac);

  for (final width in [1700.0, 720.0]) {
    for (final brightness in renderThemes) {
      final name = '${width.toInt()}_${brightness.name}';
      testWidgets('the window narrowed to a project, another’s pin in '
          'Pinned, $name', (tester) async {
        viewport(tester, Size(width, 900), brightness: brightness);
        sidebarProject.value = _ledger;
        final fake = FakeDaemon(_chats());
        final d = await fake.connect(tester);
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.select('b');
        await tester.pumpAndSettle();
        // A window 720 wide has no room for the rail, so the sidebar
        // isn't narrowed and Pinned is as it always was.
        final rail = width > 720;
        expect(find.byType(ProjectRail), rail ? findsOne : findsNothing);
        expect(
          _mark(tester, 'Keep this', 'attic').$1,
          rail ? '/Users/me/attic' : null,
        );
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'pins_every_$name');
        // The row's tile and title are inside the sidebar.
        final sidebar = tester.getRect(find.byType(Sidebar));
        expect(
          tester.getRect(_row('Keep this')).right,
          lessThanOrEqualTo(sidebar.right),
        );

        d.openSettings(section: SettingsSection.appearance);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'pins_setting_$name');
        d.dispose();
      }, variant: onMac);
    }
  }
}
