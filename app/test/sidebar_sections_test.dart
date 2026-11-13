import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_view.dart' show shownProject;
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'sidebar_fixture.dart';

Finder _in(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text)).first;

/// A menu row labelled [label], its detail after it or not.
Finder _row(String label) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      switch (w.textSpan?.toPlainText() ?? w.data) {
        final text? => text == label || text.startsWith('$label   '),
        null => false,
      },
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Makes a section from the Arrange menu and names it [name].
Future<void> _newSection(WidgetTester tester, String name) async {
  await _tap(tester, find.byTooltip(RegExp('^Arrange the sidebar')));
  await _tap(tester, _row('New section').last);
  // Its name is a field at once, all of it selected.
  await tester.enterText(find.byType(TextField), name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// [title]'s row's right-click menu, then each of [path].
Future<void> _rowMenu(
  WidgetTester tester,
  String title,
  List<String> path,
) async {
  await tester.tap(_in(title), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
  for (final label in path) {
    await _tap(
      tester,
      find
          .ancestor(
            of: _row(label),
            matching: find.byWidgetPredicate(
              (w) => w is MenuItemButton || w is SubmenuButton,
            ),
          )
          .first, // the nearest: a submenu's rows are in its button
    );
  }
}

/// Drags [text]'s row with the mouse to [to], and drops it there.
Future<void> _dragTo(WidgetTester tester, String text, Offset to) async {
  var at = tester.getCenter(_in(text));
  final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
  final step = (to - at) / 20;
  for (var i = 0; i < 20; i++) {
    at += step;
    await drag.moveTo(at);
    await tester.pump();
  }
  await drag.up();
  await tester.pumpAndSettle();
}

List<String> _order(WidgetTester tester) => shownInOrder(tester, [
  'Pinned',
  'Reviews',
  'Later',
  'Drag chats here',
  'ledger-poc',
  'cappy',
  'garden',
  'notes',
  ...arrangeTitles,
]);

/// The headers of Pinned and the sections, and the chats, top to bottom.
List<String> _titles(WidgetTester tester) =>
    shownInOrder(tester, ['Pinned', 'Reviews', 'Later', ...arrangeTitles]);

void main() {
  setUpAll(loadFonts);

  testWidgets('a section made from the menu sits under Pinned; chats move '
      'in by their menu and by a drag, out by a drag, and it deletes', (
    tester,
  ) async {
    final (d, fake) = await arrangedSidebar(tester);
    await _newSection(tester, 'Reviews');
    expect(sidebarSections.value.single.name, 'Reviews');
    expect(_order(tester).take(4), [
      'Pinned',
      'Keep this',
      'Reviews',
      'Drag chats here',
    ]);

    // By the row's menu: first in it, out of its project.
    await _rowMenu(tester, 'Plant the beds', ['Move to section', 'Reviews']);
    expect(_order(tester), [
      'Pinned',
      'Keep this',
      'Reviews',
      'Plant the beds',
      'garden', // its row says its project
      'ledger-poc',
      'Wire the ledger',
      'Seed data',
      'cappy',
      'Cap the rates',
      'notes',
      'Jot it down',
    ]);
    expect(sidebarSections.value.single.chats, ['d']);
    // Its project stays, its header alone, under those with chats (as
    // attic, whose one chat is pinned): neither is without chats.
    expect(find.text('garden'), findsNWidgets(2));
    expect(find.text('No chats'), findsNothing);
    expect(
      tester.getCenter(find.text('garden').last).dy,
      greaterThan(tester.getCenter(_in('Jot it down')).dy),
    );

    // By a drag onto its header; the last moved in comes first.
    await _dragTo(tester, 'Cap the rates', tester.getCenter(_in('Reviews')));
    expect(sidebarSections.value.single.chats, ['c', 'd']);
    // Its row says its project, whose group stays too.
    expect(find.text('cappy'), findsNWidgets(2));
    expect(_titles(tester).sublist(2, 5), [
      'Reviews',
      'Cap the rates',
      'Plant the beds',
    ]);

    // A pinned chat moved in leaves Pinned.
    await _rowMenu(tester, 'Keep this', ['Move to section', 'Reviews']);
    expect(fake.calls.whereType<PinChatsRequest>().last.chatIds, isEmpty);
    expect(find.text('Pinned'), findsNothing);
    expect(sidebarSections.value.single.chats, ['p', 'c', 'd']);

    // Dragged onto the groups, it goes back to its project.
    await _dragTo(tester, 'Cap the rates', tester.getCenter(_in('notes')));
    expect(sidebarSections.value.single.chats, ['p', 'd']);
    expect(_order(tester), containsAllInOrder(['cappy', 'Cap the rates']));

    // Remove from section, from the row's menu.
    await _rowMenu(tester, 'Keep this', [
      'Move to section',
      'Remove from section',
    ]);
    expect(sidebarSections.value.single.chats, ['d']);

    // Deleted, its chats go back.
    await tester.tap(_in('Reviews'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await _tap(tester, _row('Delete section').last);
    expect(sidebarSections.value, isEmpty);
    expect(_order(tester), containsAllInOrder(['garden', 'Plant the beds']));
    d.dispose();
  });

  testWidgets('sections drag into another order, rename, and collapse to '
      'the open chat; kept across a relaunch', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['a', 'b']),
      Section(id: 's2', name: 'Later', chats: ['e']),
    ];
    final (d, _) = await arrangedSidebar(tester);
    expect(shownInOrder(tester, arrangeTitles + ['Reviews', 'Later']), [
      'Keep this',
      'Reviews',
      'Wire the ledger',
      'Seed data',
      'Later',
      'Jot it down',
      'Cap the rates',
      'Plant the beds',
    ]);
    // ledger-poc's chats are all in Reviews: the rows say it, over its
    // group, which stays with none.
    expect(find.text('ledger-poc'), findsNWidgets(3));

    // Later, by its header, above Reviews.
    await _dragTo(
      tester,
      'Later',
      tester.getTopLeft(_in('Reviews')) + const Offset(10, -4),
    );
    expect(
      [for (final s in sidebarSections.value) s.name],
      ['Later', 'Reviews'],
    );

    // Its rows move by hand within it (Manual, by project).
    await _dragTo(
      tester,
      'Seed data',
      tester.getTopLeft(_in('Wire the ledger')) + const Offset(10, 2),
    );
    expect(sidebarSections.value[1].chats, ['b', 'a']);

    // Renamed from its menu.
    await tester.tap(_in('Reviews'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await _tap(tester, _row('Rename').last);
    await tester.enterText(find.byType(TextField), 'To review');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(sidebarSections.value[1].name, 'To review');

    // Collapsed, only the open chat's row shows; ⌘ keys skip the rest.
    d.select('a');
    await tester.pumpAndSettle();
    await _tap(
      tester,
      find
          .descendant(
            of: find.ancestor(of: _in('To review'), matching: find.byType(Row)),
            matching: find.byTooltip('Collapse'),
          )
          .first,
    );
    expect(sidebarSections.value[1].collapsed, isTrue);
    expect(chatOrder(d).map((c) => c.id), isNot(contains('b')));
    expect(chatOrder(d).map((c) => c.id), contains('a'));

    final saved = readSaved()['sidebarSections']! as List;
    expect(
      [for (final s in saved) Section.read(s)!.name],
      ['Later', 'To review'],
    );
    expect(Section.read(saved[1])!.chats, ['b', 'a']);
    expect(Section.read(saved[1])!.collapsed, isTrue);
    d.dispose();
  });

  testWidgets('a chat deleted, or gone while the app was away, drops out '
      'of its section', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['a', 'gone', 'd']),
    ];
    final (d, fake) = await arrangedSidebar(tester);
    // Gone while away: forgotten as the chats are listed.
    expect(sidebarSections.value.single.chats, ['a', 'd']);
    fake.chats.removeWhere((c) => c.id == 'a');
    fake.emit(EventsResponse(chatId: 'a', removed: true));
    await tester.pumpAndSettle();
    expect(sidebarSections.value.single.chats, ['d']);
    expect(find.text('Wire the ledger'), findsNothing);
    d.dispose();
  });

  testWidgets('Pinned stays above the sections; under a sort the rows drag '
      'only into a section', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['d']),
    ];
    sidebarGroupBy.value = GroupBy.none;
    sidebarSort.value = SortBy.name;
    sidebarAscending.value = true;
    final (d, _) = await arrangedSidebar(tester);
    expect(_titles(tester).take(5), [
      'Pinned',
      'Keep this',
      'Reviews',
      'Plant the beds',
      'Cap the rates',
    ]);
    // Dropped among the others, nothing moves: the sort decides.
    await _dragTo(
      tester,
      'Wire the ledger',
      tester.getTopLeft(_in('Cap the rates')) + const Offset(10, 2),
    );
    expect(sidebarChats.value, isEmpty);
    expect(_titles(tester).sublist(4), [
      'Cap the rates',
      'Jot it down',
      'Seed data',
      'Wire the ledger',
    ]);
    // Onto the section, it moves in.
    await _dragTo(tester, 'Jot it down', tester.getCenter(_in('Reviews')));
    expect(sidebarSections.value.single.chats, ['e', 'd']);
    // Sorted by name in it too.
    expect(_titles(tester).sublist(2, 5), [
      'Reviews',
      'Jot it down',
      'Plant the beds',
    ]);
    d.dispose();
  });

  // Deep review 2026-11-13, 15: a chat dragged within a section while the
  // sidebar was narrowed to a project sent the section's chats of other
  // projects to its end.
  testWidgets('a chat dragged in a section narrowed to a project leaves '
      'the chats of other projects where they were', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['e', 'a', 'b']),
    ];
    sidebarGroupBy.value = GroupBy.project;
    sidebarSort.value = SortBy.manual;
    projectRail.value = true;
    sidebarProject.value = '/Users/me/ledger-poc';
    final (d, _) = await arrangedSidebar(tester);
    expect(shownProject, '/Users/me/ledger-poc');
    expect(_titles(tester).take(3), [
      'Reviews',
      'Wire the ledger',
      'Seed data',
    ]);
    await _dragTo(
      tester,
      'Seed data',
      tester.getTopLeft(_in('Wire the ledger')) + const Offset(10, 2),
    );
    expect(sidebarSections.value.single.chats, ['e', 'b', 'a']);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: grouped by status, a section, arranged ($name)', (
      tester,
    ) async {
      sidebarSections.value = const [
        Section(id: 's1', name: 'Reviews', chats: ['d', 'b']),
        Section(id: 's2', name: 'Later'),
      ];
      sidebarGroupBy.value = GroupBy.status;
      sidebarShows.value = {...defaultRowParts, RowPart.time};
      final (d, _) = await arrangedSidebar(
        tester,
        tokens: tokens,
        size: const Size(560, 620),
      );
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/sidebar_arranged_$name.png'),
      );
      d.dispose();
    });

    testWidgets('golden: the Arrange menu, its Sort by open ($name)', (
      tester,
    ) async {
      sidebarGroupBy.value = GroupBy.date;
      sidebarSort.value = SortBy.updated;
      final (d, _) = await arrangedSidebar(
        tester,
        tokens: tokens,
        size: const Size(560, 620),
      );
      await _tap(tester, find.byTooltip(RegExp('^Arrange the sidebar')));
      await _tap(tester, _row('Sort by').last);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sidebar_arrange_menu_$name.png'),
      );
      d.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
