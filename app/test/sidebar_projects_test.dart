import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// A project stays in the Mac's sidebar with no chats (`sidebarProjects`):
// what joins it, where its empty group goes, how it looks and how it's
// removed. Its renders: `make renders TEST=test/sidebar_projects_test.dart`.

const _ledger = '/Users/me/ledger-poc';
const _cappy = '/Users/me/cappy';
const _garden = '/Users/me/garden';

/// Three projects of one chat each, the newest first (ledger-poc, cappy,
/// garden), a chat with no folder, and an archived one in attic.
List<Chat> _chats() => [
  chat('a', 'claude', 'Wire the ledger', folder: _ledger),
  chat('c', 'codex', 'Cap the rates', folder: _cappy, age: 1),
  chat('d', 'claude', 'Plant the beds', folder: _garden, age: 2),
  chat('s', 'ante', 'Loose end', folder: '/tmp/scratch/s', age: 3)
    ..scratch = true,
  chat('x', 'claude', 'Old boxes', folder: '/Users/me/attic', age: 9)
    ..archived = true,
];

/// Archives chat [id] as the daemon does (it unpins), or deletes it.
Future<void> _gone(
  WidgetTester tester,
  FakeDaemon fake,
  String id, {
  bool deleted = false,
}) async {
  final c = fake.chats.firstWhere((c) => c.id == id);
  if (deleted) {
    fake.chats.remove(c);
    fake.emit(EventsResponse(chatId: id, removed: true));
  } else {
    fake.emit(
      EventsResponse(
        chatId: id,
        chat: c
          ..archived = true
          ..pin = 0,
      ),
    );
  }
  await tester.pumpAndSettle();
}

Finder _in(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text));

double _y(WidgetTester tester, String text) => tester.getCenter(_in(text)).dy;

/// Opens the menu of [project]'s header (a right-click); a pinned chat's
/// row, above it, may say the project too.
Future<void> _menu(WidgetTester tester, String project) async {
  await tester.tap(_in(project).last, buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

/// Closes the open menu with a click beside the sidebar. (Escape closes
/// one only with the focus in it, which a test's right-click doesn't
/// give: the menu stayed open under the next click.)
Future<void> _away(WidgetTester tester) async {
  await tester.tapAt(const Offset(520, 680));
  await tester.pumpAndSettle();
  expect(find.byType(MenuItemButton), findsNothing);
}

/// The open menu's row [label].
MenuItemButton _entry(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton)),
);

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('a folder joins the projects with an unarchived chat, and '
      'stays, an empty group, with its chats archived or deleted', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats());
    final d = await fake.connect(tester);
    // Not the scratch folder, nor attic, whose one chat is archived.
    expect(sidebarProjects.value, [_ledger, _cappy, _garden]);
    expect(readSaved()['sidebarProjects'], [_ledger, _cappy, _garden]);
    expect(sidebarGroups(d).keys, [_ledger, _cappy, _garden, '']);

    await _gone(tester, fake, 'c');
    expect(sidebarGroups(d).keys, [_ledger, _garden, '', _cappy]);
    expect(sidebarGroups(d)[_cappy], isEmpty);
    await _gone(tester, fake, 'a', deleted: true);
    // After those with chats, in the order they joined.
    expect(sidebarGroups(d).keys, [_garden, '', _ledger, _cappy]);
    expect(liveFolders(d), {_garden});
    // The phone's list has only folders with chats.
    expect(chatGroups(d).keys, [_garden, '']);
    // The last chat with no folder gone, "No folder" goes too.
    await _gone(tester, fake, 's');
    expect(sidebarGroups(d).keys, [_garden, _ledger, _cappy]);

    // Unarchived, its chat is in its group again: the newest, so first.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        chat: fake.chats.firstWhere((c) => c.id == 'c')..archived = false,
      ),
    );
    await tester.pumpAndSettle();
    expect(sidebarGroups(d).keys, [_cappy, _garden, _ledger]);
    expect(sidebarProjects.value, [_ledger, _cappy, _garden]);
    d.dispose();
  });

  testWidgets('an empty project keeps the place it was dragged to; a chat '
      'starting there puts one not placed first', (tester) async {
    sidebarOrder.value = [_cappy, _ledger];
    final fake = FakeDaemon(_chats());
    final d = await fake.connect(tester);
    expect(sidebarGroups(d).keys, [_garden, '', _cappy, _ledger]);
    await _gone(tester, fake, 'c');
    await _gone(tester, fake, 'd');
    // cappy where it was dragged; garden, never placed, after the others.
    expect(sidebarGroups(d).keys, ['', _cappy, _ledger, _garden]);
    expect(sidebarGroups(d, starting: _garden).keys, [
      _garden,
      '',
      _cappy,
      _ledger,
    ]);
    expect(sidebarGroups(d, starting: _cappy).keys, [
      '',
      _cappy,
      _ledger,
      _garden,
    ]);
    d.dispose();
  });

  testWidgets('a project whose chats are all pinned or in a section stays, '
      'empty; only under Project grouping', (tester) async {
    sidebarSections.value = const [
      Section(id: 's1', name: 'Reviews', chats: ['a']),
    ];
    final fake = FakeDaemon(_chats()..[1].pin = 1);
    final d = await fake.connect(tester);
    final view = arrangeSidebar(d);
    expect(view.projects.keys, [_garden, '', _ledger, _cappy]);
    expect(view.projects[_ledger], isEmpty); // its chat is in Reviews
    expect(view.projects[_cappy], isEmpty); // its chat is pinned
    // Their chats aren't archived: neither can be removed.
    expect(liveFolders(d), {_ledger, _cappy, _garden});

    sidebarGroupBy.value = GroupBy.none;
    expect(arrangeSidebar(d).projects, isEmpty);
    expect(
      [for (final g in arrangeSidebar(d).groups) ...g.chats].map((c) => c.id),
      ['d', 's'],
    );
    d.dispose();
  });

  testWidgets('a project removed is forgotten with its place, its collapse '
      "and its chats' order, until a chat is there again", (tester) async {
    sidebarOrder.value = [_cappy, _ledger];
    sidebarCollapsed.value = {_cappy, _garden};
    sidebarChats.value = {
      _cappy: ['c'],
      _ledger: ['a'],
    };
    final fake = FakeDaemon(_chats());
    final d = await fake.connect(tester);
    await _gone(tester, fake, 'c');
    forgetProject(_cappy);
    await tester.pump();
    expect(sidebarGroups(d).keys, [_garden, '', _ledger]);
    expect(sidebarProjects.value, [_ledger, _garden]);
    expect(sidebarOrder.value, [_ledger]);
    expect(sidebarCollapsed.value, {_garden});
    expect(sidebarChats.value, {
      _ledger: ['a'],
    });
    final saved = readSaved();
    expect(saved['sidebarProjects'], [_ledger, _garden]);
    expect(saved['sidebarOrder'], [_ledger]);

    // The chats listed again (the daemon back): still forgotten.
    await fake.restart(tester);
    expect(sidebarProjects.value, [_ledger, _garden]);

    // A new chat there: its project is back, first, as any new one.
    final n = chat('n', 'claude', 'Cap them again', folder: _cappy, age: -1);
    fake.chats.add(n);
    fake.emit(EventsResponse(chatId: 'n', chat: n));
    await tester.pumpAndSettle();
    expect(sidebarGroups(d).keys, [_cappy, _garden, '', _ledger]);
    d.dispose();
  });

  testWidgets('an empty project shows its header over "No chats", folded '
      'away when collapsed; its + starts a chat there', (tester) async {
    final (d, fake) = await arrangedSidebar(tester, chats: _chats());
    expect(_in('No chats'), findsNothing);
    await _gone(tester, fake, 'c');
    expect(_in('Cap the rates'), findsNothing);
    expect(_in('cappy'), findsOne);
    // Last, its line under its name and starting where its header does,
    // at its tile.
    expect(_y(tester, 'cappy'), greaterThan(_y(tester, 'Loose end')));
    expect(_y(tester, 'No chats'), greaterThan(_y(tester, 'cappy')));
    final tile = find.byWidgetPredicate(
      (w) =>
          w is ProjectTile && w.name == 'cappy' && w.size == ProjectTile.small,
    );
    expect(
      tester.getTopLeft(_in('No chats')).dx,
      closeTo(tester.getTopLeft(tile).dx, 3),
    );
    expect(tester.getTopLeft(_in('cappy')).dx, tester.getTopRight(tile).dx + 6);
    expect(find.byTooltip('/Users/me/cappy'), findsOne);

    final header = find.ancestor(
      of: _in('cappy'),
      matching: find.byWidgetPredicate((w) => w is Draggable),
    );
    await tester.tap(
      find.descendant(of: header, matching: find.byTooltip('Collapse')),
    );
    await tester.pumpAndSettle();
    expect(_in('No chats'), findsNothing);
    expect(sidebarCollapsed.value, {_cappy});
    await tester.tap(
      find.descendant(of: header, matching: find.byTooltip('Expand')),
    );
    await tester.pumpAndSettle();
    expect(_in('No chats'), findsOne);

    await tester.tap(
      find.descendant(of: header, matching: find.byTooltip('New chat here')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New chat in cappy'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fake.started.single.folder, _cappy);
    d.dispose();
  });

  testWidgets('Remove from sidebar is off while a chat of the folder is '
      'unarchived, a pinned one too; picked, the project goes', (tester) async {
    final (d, fake) = await arrangedSidebar(
      tester,
      chats: _chats()..[1].pin = 1,
    );
    // cappy's one chat is pinned: its header alone, with no "No chats",
    // and it can't be removed.
    expect(_in('cappy'), findsNWidgets(2)); // the pinned row says it too
    expect(_in('No chats'), findsNothing);
    await _menu(tester, 'cappy');
    expect(_entry(tester, 'Remove from sidebar').onPressed, isNull);
    expect(find.byTooltip("It has chats that aren't archived"), findsOne);
    // Nor has an empty group a chat to open a terminal in.
    expect(_entry(tester, 'Open in terminal').onPressed, isNull);
    expect(_entry(tester, 'New chat here').onPressed, isNotNull);
    await _away(tester);

    // "No folder" isn't a project: nothing to remove.
    await _menu(tester, 'No folder');
    expect(find.text('New chat here'), findsOne);
    expect(find.text('Remove from sidebar'), findsNothing);
    await _away(tester);

    await _gone(tester, fake, 'c');
    expect(_in('No chats'), findsOne); // now it's true
    await _menu(tester, 'cappy');
    await tester.tap(find.text('Remove from sidebar'));
    await tester.pumpAndSettle();
    expect(_in('cappy'), findsNothing);
    expect(_in('No chats'), findsNothing);
    expect(sidebarProjects.value, [_ledger, _garden]);
    expect(readSaved()['sidebarProjects'], [_ledger, _garden]);
    d.dispose();
  });

  testWidgets('a chat started in a project whose folder is gone: the '
      "daemon's refusal shows, and the project stays", (tester) async {
    sidebarProjects.value = {_cappy};
    const refusal = '"/Users/me/cappy" is not an absolute path to a folder';
    final (d, fake) = await arrangedSidebar(
      tester,
      chats: [chat('a', 'claude', 'Wire the ledger', folder: _ledger)],
    );
    fake.answer = (input) => input is StartChatRequest
        ? throw ConnectException(Code.failedPrecondition, refusal)
        : null;
    await _menu(tester, 'cappy');
    await tester.tap(find.text('New chat here').last);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(refusal), findsOne);
    expect(d.starting, isNull);
    expect(_in('cappy'), findsOne);
    expect(_in('No chats'), findsOne);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: projects with no chats, one collapsed ($name)', (
      tester,
    ) async {
      sidebarProjects.value = {_ledger, _cappy, _garden, '/Users/me/notes'};
      sidebarOrder.value = [_cappy, _ledger, _garden, '/Users/me/notes'];
      sidebarCollapsed.value = {_garden};
      final (d, _) = await arrangedSidebar(
        tester,
        tokens: tokens,
        size: const Size(560, 420),
        chats: [
          chat('a', 'claude', 'Wire the ledger', folder: _ledger),
          chat('e', 'ante', 'Jot it down', folder: '/Users/me/notes', age: 3),
        ],
      );
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/sidebar_projects_$name.png'),
      );
      d.dispose();
    });

    testWidgets("golden: an empty project's menu ($name)", (tester) async {
      sidebarProjects.value = {_ledger, _cappy};
      // In a window of a size, which a menu's width goes by.
      viewport(tester, const Size(560, 420));
      final d = await FakeDaemon([
        chat('a', 'claude', 'Wire the ledger', folder: _ledger),
      ]).connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 260,
                    child: ListenableBuilder(
                      listenable: d,
                      builder: (context, _) => Sidebar(daemon: d),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _menu(tester, 'cappy');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sidebar_project_menu_$name.png'),
      );
      d.dispose();
    }, variant: macOS);
  }

  // The whole window, to look at: an empty project among the others (a
  // dragged order, so it isn't last), another collapsed, then its menu.
  for (final width in [1700.0, 720.0]) {
    for (final brightness in Brightness.values) {
      final name = '${width.toInt()}_${brightness.name}';
      testWidgets('the window with empty projects, $name', (tester) async {
        viewport(tester, Size(width, 760), brightness: brightness);
        paneWidths.value = {};
        sidebarProjects.value = {'/Users/me/zeta', '/Users/me/work/cappy'};
        sidebarOrder.value = [_ledger, '/Users/me/zeta', _cappy];
        sidebarCollapsed.value = {'/Users/me/work/cappy'};
        final d = await FakeDaemon(_chats()).connect(tester);
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pump(const Duration(seconds: 1));
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'projects_$name');

        // No header's + runs past the sidebar's edge, an empty one's too.
        final sidebar = tester.getRect(find.byType(Sidebar));
        for (final plus in find.byTooltip('New chat here').evaluate()) {
          final box = plus.renderObject! as RenderBox;
          final right = box.localToGlobal(box.size.topRight(Offset.zero)).dx;
          expect(right, lessThanOrEqualTo(sidebar.right - 4));
        }
        await _menu(tester, 'zeta');
        expect(_entry(tester, 'Remove from sidebar').onPressed, isNotNull);
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'projects_menu_$name');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 300));
        await closeView(tester, d);
      }, variant: macOS);
    }
  }
}
