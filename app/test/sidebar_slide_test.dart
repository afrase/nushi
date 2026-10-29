import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The sidebar's drags slide: the other rows or projects move
// apart to open the gap where the dragged one would land, and settle on
// the drop; a list that refuses the drag doesn't move.

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

/// The sidebar alone, 260 wide, on [_chats] with [pins]; with Reduce
/// Motion when [still].
Future<(Daemon, FakeDaemon)> _sidebar(
  WidgetTester tester, {
  Map<String, int> pins = const {},
  bool still = false,
}) async {
  viewport(tester, const Size(280, 560));
  final fake = FakeDaemon(_chats(pins: pins));
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('screen'), // the dragged title too, over the list
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
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
  return (d, fake);
}

/// [text] in the sidebar (not the dragged copy under the pointer).
Finder _in(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text));

double _y(WidgetTester tester, String text) => tester.getCenter(_in(text)).dy;

/// Where each of [texts] shows now.
Map<String, double> _ys(WidgetTester tester, List<String> texts) => {
  for (final t in texts) t: _y(tester, t),
};

/// Starts dragging [text] with the mouse (as on the Mac: a touch drag
/// scrolls the list) and moves it in small steps until the pointer is at
/// [goal]'s height, each step a frame with no time passing.
Future<TestGesture> _drag(WidgetTester tester, String text, double goal) async {
  var at = tester.getCenter(_in(text));
  final down = goal > at.dy;
  final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
  while (down ? at.dy < goal : at.dy > goal) {
    at += Offset(0, down ? 6 : -6);
    await drag.moveTo(at);
    await tester.pump();
  }
  return drag;
}

/// The opacity [text]'s row (or header) shows at.
double _opacity(WidgetTester tester, String text) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(of: _in(text), matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

const _slide = Duration(milliseconds: 200);

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('a chat dragged in its project: the rows it passes slide '
      'apart to open the gap, it shows faded there, and the drop settles '
      'without sliding again', (tester) async {
    final (d, _) = await _sidebar(tester);
    const ledger = ['Wire the ledger', 'Seed data', 'Price the bonds'];
    final before = _ys(tester, ledger);
    final row = before['Seed data']! - before['Wire the ledger']!;

    // Up, into the top half of Wire the ledger's row.
    final drag = await _drag(
      tester,
      'Price the bonds',
      before['Wire the ledger']! - 4,
    );
    expect(find.text('Price the bonds'), findsNWidgets(2)); // and lifted
    // The gap opened, the rows not moved yet: they slide.
    expect(_y(tester, 'Wire the ledger'), before['Wire the ledger']);
    await tester.pump(_slide ~/ 2);
    final midway = _y(tester, 'Wire the ledger');
    expect(midway, greaterThan(before['Wire the ledger']!));
    expect(midway, lessThan(before['Wire the ledger']! + row));
    await tester.pump(_slide);
    expect(_ys(tester, ledger), {
      'Wire the ledger': before['Wire the ledger']! + row,
      'Seed data': before['Seed data']! + row,
      'Price the bonds': before['Wire the ledger'], // in the gap
    });
    expect(_opacity(tester, 'Price the bonds'), 0.4);
    expect(_opacity(tester, 'Wire the ledger'), 1);
    // The projects below don't move.
    expect(_y(tester, 'cappy'), greaterThan(before['Price the bonds']!));

    await drag.up();
    await tester.pump();
    // Already where they land: no slide back and forth.
    expect(_ys(tester, ledger), {
      'Price the bonds': before['Wire the ledger'],
      'Wire the ledger': before['Seed data'],
      'Seed data': before['Price the bonds'],
    });
    await tester.pump(_slide);
    expect(_opacity(tester, 'Price the bonds'), 1); // settled
    expect(sidebarChats.value, {
      _ledger: ['f', 'a', 'b'],
    });
    expect(chatOrder(d).take(3).map((c) => c.id), ['f', 'a', 'b']);
    d.dispose();
  });

  testWidgets('refused: a chat over another project, a pinned chat over '
      'its project, nothing slides; dragged off its list, the rows slide '
      'back and nothing moves', (tester) async {
    final (d, fake) = await _sidebar(tester, pins: {'b': 1});
    const ledger = ['Wire the ledger', 'Price the bonds'];
    final before = _ys(tester, [...ledger, 'Cap the rates', 'Seed data']);

    // Cap the rates (cappy) onto ledger-poc's rows.
    var drag = await _drag(
      tester,
      'Cap the rates',
      before['Wire the ledger']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_ys(tester, ledger), {for (final t in ledger) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(_y(tester, 'Cap the rates'), before['Cap the rates']);

    // Seed data (pinned, of ledger-poc) onto its project's rows.
    drag = await _drag(tester, 'Seed data', before['Price the bonds']! + 4);
    await tester.pump(_slide * 2);
    expect(_ys(tester, ledger), {for (final t in ledger) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(fake.calls.whereType<PinChatsRequest>(), isEmpty);

    // Price the bonds up over Wire the ledger, then off, onto cappy's.
    drag = await _drag(
      tester,
      'Price the bonds',
      before['Wire the ledger']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_y(tester, 'Wire the ledger'), isNot(before['Wire the ledger']));
    await drag.moveTo(tester.getCenter(_in('Cap the rates')));
    await tester.pump();
    await tester.pump(_slide * 2);
    expect(_ys(tester, ledger), {for (final t in ledger) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(_ys(tester, ledger), {for (final t in ledger) t: before[t]});
    expect(sidebarChats.value, isEmpty);
    d.dispose();
  });

  testWidgets('a project dragged by its header: the projects it passes '
      'slide apart by its height, and a collapsed one stays collapsed', (
    tester,
  ) async {
    final (d, _) = await _sidebar(tester);
    // notes collapsed: its row hidden, its header alone.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: _in('notes'),
          matching: find.byWidgetPredicate((w) => w is Draggable),
        ),
        matching: find.byTooltip('Collapse'),
      ),
    );
    await tester.pump();
    expect(_in('Jot it down'), findsNothing);
    const headers = ['ledger-poc', 'cappy', 'garden', 'notes'];
    final before = _ys(tester, headers);
    // A collapsed group is its header: cappy's group less its one row.
    final row = _y(tester, 'Seed data') - _y(tester, 'Wire the ledger');
    final notes = before['garden']! - before['cappy']! - row;

    final drag = await _drag(tester, 'notes', before['ledger-poc']! - 4);
    await tester.pump(_slide * 2);
    final moved = _ys(tester, headers);
    // ledger-poc, cappy and garden down by the same: notes's height.
    final by = moved['ledger-poc']! - before['ledger-poc']!;
    expect(by, closeTo(notes, 0.01));
    for (final h in ['cappy', 'garden']) {
      expect(moved[h], closeTo(before[h]! + by, 0.01));
    }
    expect(moved['notes'], closeTo(before['ledger-poc']!, 0.01));
    expect(_opacity(tester, 'notes'), 0.4);

    await drag.up();
    await tester.pump();
    expect(_ys(tester, headers), {
      'notes': closeTo(before['ledger-poc']!, 0.01),
      for (final h in ['ledger-poc', 'cappy', 'garden'])
        h: closeTo(before[h]! + by, 0.01),
    });
    expect(sidebarOrder.value, [
      '/Users/me/notes',
      _ledger,
      '/Users/me/cappy',
      '/Users/me/garden',
    ]);
    expect(sidebarCollapsed.value, {'/Users/me/notes'});
    expect(_in('Jot it down'), findsNothing);
    // ⌘1–9 go through the chats shown: notes's is hidden, collapsed.
    expect(chatOrder(d).map((c) => c.id), ['a', 'b', 'f', 'c', 'd']);
    d.dispose();
  });

  testWidgets('Pinned slides too, and the drop sends the new order to the '
      'daemon', (tester) async {
    final (d, fake) = await _sidebar(tester, pins: {'e': 1, 'b': 2, 'c': 3});
    const pinned = ['Jot it down', 'Seed data', 'Cap the rates'];
    final before = _ys(tester, pinned);
    final row = before['Seed data']! - before['Jot it down']!;

    final drag = await _drag(
      tester,
      'Cap the rates',
      before['Jot it down']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_ys(tester, pinned), {
      'Jot it down': before['Jot it down']! + row,
      'Seed data': before['Seed data']! + row,
      'Cap the rates': before['Jot it down'],
    });
    await drag.up();
    await tester.pump();
    expect(fake.calls.whereType<PinChatsRequest>().last.chatIds, [
      'c',
      'e',
      'b',
    ]);
    expect(_ys(tester, pinned), {
      'Cap the rates': before['Jot it down'],
      'Jot it down': before['Seed data'],
      'Seed data': before['Cap the rates'],
    });
    expect(chatOrder(d).take(3).map((c) => c.id), ['c', 'e', 'b']);
    d.dispose();
  });

  testWidgets('Reduce Motion: the gap opens at once, no slide', (tester) async {
    final (d, _) = await _sidebar(tester, still: true);
    final before = _ys(tester, ['Wire the ledger', 'Seed data']);
    final row = before['Seed data']! - before['Wire the ledger']!;
    final drag = await _drag(
      tester,
      'Price the bonds',
      before['Wire the ledger']! - 4,
    );
    // No time has passed, and it's there.
    expect(_y(tester, 'Wire the ledger'), before['Wire the ledger']! + row);
    await drag.up();
    await tester.pump();
    expect(_opacity(tester, 'Price the bonds'), 1);
    expect(sidebarChats.value[_ledger], ['f', 'a', 'b']);
    d.dispose();
  });

  testWidgets('golden: a chat mid-drag, the gap open (dark)', (tester) async {
    final (d, _) = await _sidebar(tester, pins: {'e': 1, 'c': 2});
    final drag = await _drag(
      tester,
      'Price the bonds',
      _y(tester, 'Wire the ledger') - 4,
    );
    await tester.pump(_slide * 2);
    await tester.pump(); // the hover, moved after the slide's last frame
    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('goldens/sidebar_drag_dark.png'),
    );
    await drag.up();
    await tester.pump(_slide * 2);
    d.dispose();
  });
}
