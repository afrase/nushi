import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _ledger = '/Users/me/ledger-poc';

/// Four projects, the newest chat first: ledger-poc (three chats), cappy,
/// garden, notes; [pins] pinned, by id, at their places.
List<Chat> _chats({Map<String, int> pins = const {}}) => [
  for (final c in [
    chat('a', 'claude', 'Wire the ledger', folder: _ledger),
    chat('c', 'codex', 'Cap the rates', folder: '/Users/me/cappy', age: 1),
    chat('d', 'claude', 'Plant the beds', folder: '/Users/me/garden', age: 2),
    chat('e', 'ante', 'Jot it down', folder: '/Users/me/notes', age: 3),
    chat('b', 'pig', 'Seed data', folder: _ledger, age: 5),
    chat('f', 'claude', 'Price the bonds', folder: _ledger, age: 6),
  ])
    c..pin = pins[c.id] ?? 0,
];

/// The sidebar alone, 260 wide, on [chats].
Future<Daemon> _sidebar(WidgetTester tester, List<Chat> chats) async {
  viewport(tester, const Size(400, 600));
  final d = await FakeDaemon(chats).connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const Key('shot'),
              child: SizedBox(
                width: 260,
                height: 560,
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
  await tester.pump();
  return d;
}

double _y(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text)).dy;

/// The centre's height of [text] in the sidebar.
double _ys(WidgetTester tester, String text) =>
    tester.getCenter(_inSidebar(text)).dy;

/// [titles], sorted as their rows show, top to bottom.
List<String> _rows(WidgetTester tester, List<String> titles) =>
    [...titles]..sort((a, b) => _y(tester, a).compareTo(_y(tester, b)));

/// Drags [title]'s row with the mouse until the pointer is [by] past
/// [onto]'s centre (up when negative), then drops it; [whileOver] runs
/// before the drop.
Future<void> _drag(
  WidgetTester tester,
  String title,
  String onto, {
  double by = -4,
  Future<void> Function()? whileOver,
}) async {
  var at = tester.getCenter(find.text(title));
  final goal = _y(tester, onto) + by;
  final down = goal > at.dy;
  final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
  while (down ? at.dy < goal : at.dy > goal) {
    at += Offset(0, down ? 6 : -6);
    await drag.moveTo(at);
    await tester.pump();
  }
  await whileOver?.call();
  await drag.up();
  await tester.pump();
}

/// The app on [_chats], [select] shown; archiving answered as the daemon
/// does (it unpins).
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  String? select,
  Map<String, int> pins = const {},
}) async {
  viewport(tester, const Size(1200, 700));
  final chats = _chats(pins: pins);
  late final FakeDaemon fake;
  fake = FakeDaemon(chats)
    ..answer = (input) {
      if (input is ArchiveChatRequest) {
        final c = chats.firstWhere((c) => c.id == input.chatId)
          ..archived = input.archived
          ..pin = 0; // archiving unpins; unarchiving doesn't pin again
        fake.emit(EventsResponse(chatId: c.id, chat: c));
      }
      return null;
    };
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  if (select != null) {
    d.select(select);
    await tester.pumpAndSettle();
  }
  return (d, fake);
}

/// [title]'s rows in the sidebar.
Finder _inSidebar(String title) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(title));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('a double click opens a chat; only its menu renames it', (
    tester,
  ) async {
    final d = await _sidebar(tester, _chats());
    final row = _inSidebar('Cap the rates');
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'c');
    expect(find.byType(EditableText), findsNothing);

    await tester.tap(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    d.dispose();
  });

  testWidgets('a chat is dragged into another place in its project, the '
      'rows moving apart where it goes; refused in another project; kept, a '
      'new chat first', (tester) async {
    const ledger = ['Wire the ledger', 'Seed data', 'Price the bonds'];
    var d = await _sidebar(tester, _chats());
    expect(_rows(tester, ledger), ledger); // the newest first

    // Up, into the top half of Wire the ledger's row, which moves down.
    final wire = _ys(tester, 'Wire the ledger');
    await _drag(
      tester,
      'Price the bonds',
      'Wire the ledger',
      whileOver: () async =>
          expect(_ys(tester, 'Wire the ledger'), greaterThan(wire)),
    );
    const moved = ['Price the bonds', 'Wire the ledger', 'Seed data'];
    expect(_rows(tester, ledger), moved);
    expect(sidebarChats.value, {
      _ledger: ['f', 'a', 'b'],
    });
    expect((readSaved()['sidebarChats']! as Map)[_ledger], ['f', 'a', 'b']);
    expect(chatOrder(d).take(3).map((c) => c.id), ['f', 'a', 'b']);

    // Cap the rates (cappy) onto ledger-poc's rows: they stay, no move.
    final seed = _ys(tester, 'Seed data');
    await _drag(
      tester,
      'Cap the rates',
      'Seed data',
      by: 4,
      whileOver: () async => expect(_ys(tester, 'Seed data'), seed),
    );
    expect(_rows(tester, ledger), moved);
    expect(_y(tester, 'Cap the rates'), greaterThan(_y(tester, 'Seed data')));
    expect(sidebarChats.value.keys, [_ledger]);
    d.dispose();

    // As after a restart, with a new chat in ledger-poc: it goes first.
    d = await _sidebar(tester, [
      ..._chats(),
      chat('n', 'claude', 'New ledger work', folder: _ledger, age: -1),
    ]);
    expect(_rows(tester, ['New ledger work', ...ledger]), [
      'New ledger work',
      ...moved,
    ]);
    d.dispose();
  });

  testWidgets('a pinned chat shows once, in Pinned at the top with its '
      'project; Pinned reorders by dragging, collapses, and ⌘1–9 start '
      'there', (tester) async {
    final d = await _sidebar(tester, _chats(pins: {'e': 1, 'b': 2}));
    expect(find.text('Pinned'), findsOne);
    expect(find.text('Seed data'), findsOne);
    expect(find.text('Jot it down'), findsOne);
    expect(
      _rows(tester, ['Pinned', 'Jot it down', 'Seed data', 'Wire the ledger']),
      ['Pinned', 'Jot it down', 'Seed data', 'Wire the ledger'],
    );
    // The project's name after the title, muted.
    expect(
      _y(tester, 'notes'),
      closeTo(_y(tester, 'Jot it down'), 2),
      reason: 'the project on the pinned row',
    );
    expect(find.text('ledger-poc'), findsNWidgets(2)); // b's, the header
    expect(find.text('notes'), findsOne); // all its chats pinned: no header
    expect(chatOrder(d).map((c) => c.id), ['e', 'b', 'a', 'f', 'c', 'd']);

    // Seed data dragged above Jot it down: the daemon's order changes.
    await _drag(tester, 'Seed data', 'Jot it down');
    await tester.pump();
    expect(_rows(tester, ['Jot it down', 'Seed data']), [
      'Seed data',
      'Jot it down',
    ]);
    expect(chatOrder(d).take(2).map((c) => c.id), ['b', 'e']);

    // Collapsed: only the selected chat's row, if it's pinned.
    await tester.tap(find.byTooltip('Collapse').first);
    await tester.pump();
    expect(pinnedCollapsed.value, isTrue);
    expect(find.text('Seed data'), findsNothing);
    expect(chatOrder(d).first.id, 'a');
    d.select('e');
    await tester.pump();
    expect(find.text('Jot it down'), findsOne);
    expect(chatOrder(d).first.id, 'e');
    d.dispose();
  });

  testWidgets('Pin from ⋯, ⌘D, Unpin from the palette, the pinned first '
      'in it; archiving unpins', (tester) async {
    final (d, fake) = await _app(tester, select: 'a');
    List<String> pinned() =>
        fake.calls.whereType<PinChatsRequest>().last.chatIds;
    expect(find.text('Pinned'), findsNothing);

    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.text('⌘D'), findsOne); // Pin's key, at its right
    await tester.tap(find.text('Pin', findRichText: true));
    await tester.pumpAndSettle();
    expect(pinned(), ['a']);
    expect(find.text('Pinned'), findsOne);
    expect(_inSidebar('Wire the ledger'), findsOne);

    d.select('c');
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.keyD);
    expect(pinned(), ['a', 'c']);
    expect(_ys(tester, 'Cap the rates'), lessThan(_ys(tester, 'Seed data')));

    // With nothing typed, the pinned chats first, whatever was opened last.
    d.select('d');
    await tester.pumpAndSettle();
    chatOpened.value = {...chatOpened.value, 'e': clockMs() + 1000};
    await _key(tester, LogicalKeyboardKey.keyK);
    final rows = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byType(Text),
    );
    expect([
      for (final t in tester.widgetList<Text>(rows).take(6)) t.data,
    ], containsAllInOrder(['Wire the ledger', 'Cap the rates', 'Jot it down']));
    await tester.enterText(
      find.descendant(
        of: find.byType(Palette),
        matching: find.byType(TextField),
      ),
      'pin',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(Palette),
        matching: find.text('Pin chat'),
      ),
      findsOne,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    d.select('c');
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(
      find.descendant(
        of: find.byType(Palette),
        matching: find.byType(TextField),
      ),
      'unpin',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(Palette),
        matching: find.text('Unpin chat'),
      ),
    );
    await tester.pumpAndSettle();
    expect(pinned(), ['a']);
    expect(_inSidebar('Cap the rates'), findsOne);
    expect(_ys(tester, 'Cap the rates'), greaterThan(_ys(tester, 'cappy')));

    // Archived, a's pin goes (the daemon's), and with it Pinned.
    d.select('a');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive', findRichText: true));
    await tester.pumpAndSettle();
    expect(d.chats['a']!.pin, 0);
    expect(find.text('Pinned'), findsNothing);
    expect(pinnedChats(d), isEmpty);
    d.dispose();
  }, variant: macOS);

  testWidgets('golden: two pinned chats and a reordered project (dark)', (
    tester,
  ) async {
    sidebarChats.value = {
      _ledger: ['f', 'a'],
    };
    final d = await _sidebar(tester, _chats(pins: {'e': 1, 'c': 2}));
    await expectLater(
      find.byKey(const Key('shot')),
      matchesGoldenFile('goldens/sidebar_pinned_dark.png'),
    );
    d.dispose();
  });
}

int clockMs() => DateTime.now().millisecondsSinceEpoch;
