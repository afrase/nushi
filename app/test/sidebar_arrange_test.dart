import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_arrange.dart';

import 'fake_daemon.dart';
import 'sidebar_fixture.dart';

final Finder _arrange = find.byTooltip(RegExp('^Arrange the sidebar'));

/// A menu row labelled [label], its detail after it or not.
Finder _row(String label) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      switch (w.textSpan?.toPlainText() ?? w.data) {
        final text? => text == label || text.startsWith('$label   '),
        null => false,
      },
);

/// Opens the Arrange menu, then each of [path] in turn (a submenu, then
/// a row of it).
Future<void> _pick(WidgetTester tester, List<String> path) async {
  await tester.tap(_arrange);
  await tester.pumpAndSettle();
  for (final label in path) {
    await tester.tap(_row(label).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadFonts);

  // The agents' names as each test knows them.
  List<String> headers() => [
    'Pinned',
    'Today',
    'Yesterday',
    'Previous 7 days',
    'Previous 30 days',
    'September',
    'Needs you',
    'Working',
    'Done',
    'Idle',
    'In a worktree',
    'Not in a worktree',
    for (final a in ['ante', 'claude', 'codex', 'pig']) agentTitle(a),
  ];
  List<String> order(WidgetTester tester) =>
      shownInOrder(tester, [...headers(), ...arrangeTitles]);

  testWidgets('at first, grouped by project and sorted by hand, as before; '
      'the button shows under the pointer, unmarked', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    expect(
      shownInOrder(tester, [
        ...headers(),
        ...arrangeTitles,
        'ledger-poc',
        'cappy',
        'garden',
        'notes',
      ]),
      [
        'Pinned',
        'Keep this',
        'ledger-poc',
        'Wire the ledger',
        'Seed data',
        'cappy',
        'Cap the rates',
        'garden',
        'Plant the beds',
        'notes',
        'Jot it down',
      ],
    );
    expect(arrangedAsDefault, isTrue);
    double opacity() => tester
        .widget<Opacity>(
          find.ancestor(of: _arrange, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 300));
    await tester.pump();
    expect(opacity(), 1);
    expect(find.byTooltip('Arrange the sidebar'), findsOne);
    await mouse.moveTo(const Offset(500, 300));
    await tester.pump();
    expect(opacity(), 0);
    d.dispose();
  });

  testWidgets('each grouping, Pinned always on top', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    await _pick(tester, ['Group by', 'Date']);
    expect(sidebarGroupBy.value, GroupBy.date);
    // Manual reads as Date created outside projects.
    expect(order(tester), [
      'Pinned',
      'Keep this',
      'Today',
      'Wire the ledger',
      'Yesterday',
      'Seed data',
      'Previous 7 days',
      'Cap the rates',
      'Previous 30 days',
      'Plant the beds',
      'September',
      'Jot it down',
    ]);
    // By last updated, Cap the rates is today's.
    sidebarSort.value = SortBy.updated;
    await tester.pumpAndSettle();
    expect(order(tester).sublist(2, 5), [
      'Today',
      'Wire the ledger',
      'Cap the rates',
    ]);

    sidebarGroupBy.value = GroupBy.status;
    sidebarSort.value = SortBy.created;
    await tester.pumpAndSettle();
    expect(order(tester), [
      'Pinned',
      'Keep this',
      'Needs you',
      'Wire the ledger',
      'Working',
      'Cap the rates',
      'Done',
      'Plant the beds',
      'Idle',
      'Seed data',
      'Jot it down',
    ]);

    sidebarGroupBy.value = GroupBy.agent;
    await tester.pumpAndSettle();
    final byAgent =
        {
            'ante': ['Jot it down'],
            'claude': ['Wire the ledger', 'Plant the beds'],
            'codex': ['Cap the rates'],
            'pig': ['Seed data'],
          }.entries.toList()
          ..sort((a, b) => agentTitle(a.key).compareTo(agentTitle(b.key)));
    expect(order(tester), [
      'Pinned',
      'Keep this',
      for (final MapEntry(:key, :value) in byAgent) ...[
        agentTitle(key),
        ...value,
      ],
    ]);

    sidebarGroupBy.value = GroupBy.worktree;
    await tester.pumpAndSettle();
    expect(order(tester), [
      'Pinned',
      'Keep this',
      'In a worktree',
      'Seed data',
      'Not in a worktree',
      'Wire the ledger',
      'Cap the rates',
      'Plant the beds',
      'Jot it down',
    ]);

    sidebarGroupBy.value = GroupBy.none;
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, ['Pinned', ...arrangeTitles]), [
      'Pinned',
      'Keep this',
      'Wire the ledger',
      'Seed data',
      'Cap the rates',
      'Plant the beds',
      'Jot it down',
    ]);
    // A row outside its project's group says its project.
    expect(find.text('ledger-poc'), findsNWidgets(2));
    d.dispose();
  });

  testWidgets('a chat changing state moves between Status groups, and '
      'only then', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    sidebarGroupBy.value = GroupBy.status;
    await tester.pumpAndSettle();
    d.chats['c']!.listed(ChatStatus());
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNothing);
    expect(order(tester).sublist(order(tester).indexOf('Idle')), [
      'Idle',
      'Seed data',
      'Cap the rates',
      'Jot it down',
    ]);
    d.dispose();
  });

  testWidgets('each sort, each way; the menu says which order a drag sets', (
    tester,
  ) async {
    final (d, _) = await arrangedSidebar(tester);
    await _pick(tester, ['Group by', 'None']);
    await _pick(tester, ['Sort by']);
    // Manual is the projects' alone.
    expect(find.textContaining('by Project only'), findsOne);
    expect(
      find.text('The sort sets the order; drag a chat into a section'),
      findsOne,
    );
    await tester.tap(_row('Name').last);
    await tester.pumpAndSettle();
    expect(sidebarAscending.value, isTrue); // names from A
    final titles = shownInOrder(tester, arrangeTitles).sublist(1);
    expect(titles, [
      'Cap the rates',
      'Jot it down',
      'Plant the beds',
      'Seed data',
      'Wire the ledger',
    ]);
    await _pick(tester, ['Sort by', 'Z to A']);
    expect(shownInOrder(tester, arrangeTitles).sublist(1), titles.reversed);

    await _pick(tester, ['Sort by', 'Last updated']);
    expect(sidebarAscending.value, isFalse);
    expect(shownInOrder(tester, arrangeTitles).sublist(1), [
      'Wire the ledger',
      'Cap the rates',
      'Seed data',
      'Plant the beds',
      'Jot it down',
    ]);
    await _pick(tester, ['Sort by', 'Oldest first']);
    expect(shownInOrder(tester, arrangeTitles).sublist(1, 3), [
      'Jot it down',
      'Plant the beds',
    ]);
    await _pick(tester, ['Sort by', 'Date created']);
    expect(shownInOrder(tester, arrangeTitles).sublist(1, 4), [
      'Wire the ledger',
      'Seed data',
      'Cap the rates',
    ]);

    // By project and by hand, dragging orders.
    await _pick(tester, ['Group by', 'Project']);
    await _pick(tester, ['Sort by', 'Manual']);
    await _pick(tester, ['Sort by']);
    expect(find.text('Drag chats to put them in order'), findsOne);
    d.dispose();
  });

  testWidgets('⌘1–⌘9 and ⌘] follow the order shown', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    sidebarGroupBy.value = GroupBy.none;
    sidebarSort.value = SortBy.name;
    sidebarAscending.value = true;
    await tester.pumpAndSettle();
    expect(
      [for (final c in chatOrder(d)) c.shownTitle],
      [
        'Keep this',
        'Cap the rates',
        'Jot it down',
        'Plant the beds',
        'Seed data',
        'Wire the ledger',
      ],
    );
    openNthChat(d, 2);
    expect(d.selectedId, 'c');
    stepChat(d, 1);
    expect(d.selectedId, 'e');
    // A collapsed group's chats are skipped, but the open one: idle, Jot
    // it down shows; Seed data doesn't.
    sidebarGroupBy.value = GroupBy.status;
    sidebarCollapsed.value = {'status:09'};
    await tester.pumpAndSettle();
    expect(chatOrder(d).map((c) => c.id), containsAllInOrder(['p', 'a']));
    expect(chatOrder(d).map((c) => c.id), contains('e'));
    expect(chatOrder(d).map((c) => c.id), isNot(contains('b')));
    d.dispose();
  });

  testWidgets('Show picks what rows show; the button is marked until Reset '
      'to defaults', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    expect(find.text('brisk-otter'), findsOne); // the branch
    await _pick(tester, ['Show', 'Branch']);
    expect(find.text('brisk-otter'), findsNothing);
    await _pick(tester, ['Show', 'Time']);
    expect(find.text('10m'), findsOne); // Wire the ledger's age
    expect(arrangedAsDefault, isFalse);
    expect(find.byTooltip('Arrange the sidebar (arranged your way)'), findsOne);
    await _pick(tester, ['Reset to defaults']);
    expect(arrangedAsDefault, isTrue);
    expect(sidebarShows.value, defaultRowParts);
    expect(find.text('brisk-otter'), findsOne);
    expect(find.text('10m'), findsNothing);
    // At the defaults, there's nothing to reset.
    await tester.tap(_arrange);
    await tester.pumpAndSettle();
    final reset = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Reset to defaults'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(reset.onPressed, isNull);
    d.dispose();
  });

  testWidgets('View all opens Chat history', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    await _pick(tester, ['View all']);
    expect(d.settingsOpen?.section.title, 'Chat history');
    d.dispose();
  });

  testWidgets('the arrangement is kept across a relaunch', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    await _pick(tester, ['Group by', 'Agent']);
    await _pick(tester, ['Sort by', 'Name']);
    await _pick(tester, ['Show', 'Status']);
    d.dispose();
    final saved = readSaved();
    expect(saved['sidebarGroupBy'], 'agent');
    expect(saved['sidebarSort'], 'name');
    expect(saved['sidebarAscending'], true);
    expect(saved['sidebarShows'], ['agent', 'branch', 'project']);
    // As the next launch reads them.
    expect(GroupBy.values.asNameMap()[saved['sidebarGroupBy']], GroupBy.agent);
    expect(SortBy.values.asNameMap()[saved['sidebarSort']], SortBy.name);
  });

  testWidgets('the menu works from the keyboard', (tester) async {
    final (d, _) = await arrangedSidebar(tester);
    // Focused, as Tab leaves it.
    Focus.of(
      tester.element(
        find.descendant(of: _arrange, matching: find.byType(GestureDetector)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_row('Group by'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Worktree'), findsOne); // Group by's submenu
    // Project has the focus; Date is next.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sidebarGroupBy.value, GroupBy.date);
    expect(find.text('Worktree'), findsNothing); // closed
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
