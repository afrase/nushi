import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';

import 'fake_daemon.dart';
import 'sidebar_fixture.dart';

// The sidebar's drags slide: the other rows or projects move
// apart to open the gap where the dragged one would land, and settle on
// the drop; a list that refuses the drag doesn't move.

const _parcel = '/Users/me/parcel-poc';

/// Four projects, the newest chat first: parcel-poc (three chats), cubby,
/// garden, notes; [pins] pinned, by id, at their places.
List<Chat> _chats({Map<String, int> pins = const {}}) => [
  for (final c in [
    chat('a', 'claude', 'Wire the parcel', folder: _parcel),
    chat('c', 'codex', 'Fold the maps', folder: '/Users/me/cubby', age: 1),
    chat('d', 'claude', 'Plant the beds', folder: '/Users/me/garden', age: 2),
    chat('e', 'ante', 'Jot it down', folder: '/Users/me/notes', age: 3),
    chat('b', 'pig', 'Seed data', folder: _parcel, age: 5),
    chat('f', 'claude', 'Sweep the porch', folder: _parcel, age: 6),
  ])
    c..pin = pins[c.id] ?? 0,
];

/// The sidebar alone, 260 wide and [height] high, on [_chats] with [pins];
/// with Reduce Motion when [still].
Future<(Daemon, FakeDaemon)> _sidebar(
  WidgetTester tester, {
  Map<String, int> pins = const {},
  bool still = false,
  double height = 560,
}) => arrangedSidebar(
  tester,
  chats: _chats(pins: pins),
  size: Size(280, height),
  still: still,
  settle: false,
);

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
  setUpAll(loadFonts);

  testWidgets('a chat dragged in its project: the rows it passes slide '
      'apart to open the gap, it shows faded there, and the drop settles '
      'without sliding again', (tester) async {
    final (d, _) = await _sidebar(tester);
    const parcelRows = ['Wire the parcel', 'Seed data', 'Sweep the porch'];
    final before = _ys(tester, parcelRows);
    final row = before['Seed data']! - before['Wire the parcel']!;

    // Up, into the top half of Wire the parcel's row.
    final drag = await _drag(
      tester,
      'Sweep the porch',
      before['Wire the parcel']! - 4,
    );
    expect(find.text('Sweep the porch'), findsNWidgets(2)); // and lifted
    // The gap opened, the rows not moved yet: they slide.
    expect(_y(tester, 'Wire the parcel'), before['Wire the parcel']);
    await tester.pump(_slide ~/ 2);
    final midway = _y(tester, 'Wire the parcel');
    expect(midway, greaterThan(before['Wire the parcel']!));
    expect(midway, lessThan(before['Wire the parcel']! + row));
    await tester.pump(_slide);
    expect(_ys(tester, parcelRows), {
      'Wire the parcel': before['Wire the parcel']! + row,
      'Seed data': before['Seed data']! + row,
      'Sweep the porch': before['Wire the parcel'], // in the gap
    });
    expect(_opacity(tester, 'Sweep the porch'), 0.4);
    expect(_opacity(tester, 'Wire the parcel'), 1);
    // The projects below don't move.
    expect(_y(tester, 'cubby'), greaterThan(before['Sweep the porch']!));

    await drag.up();
    await tester.pump();
    // Already where they land: no slide back and forth.
    expect(_ys(tester, parcelRows), {
      'Sweep the porch': before['Wire the parcel'],
      'Wire the parcel': before['Seed data'],
      'Seed data': before['Sweep the porch'],
    });
    await tester.pump(_slide);
    expect(_opacity(tester, 'Sweep the porch'), 1); // settled
    expect(sidebarChats.value, {
      _parcel: ['f', 'a', 'b'],
    });
    expect(chatOrder(d).take(3).map((c) => c.id), ['f', 'a', 'b']);
    d.dispose();
  });

  testWidgets('refused: a chat over another project, a pinned chat over '
      'its project, nothing slides; dragged off its list, the rows slide '
      'back and nothing moves', (tester) async {
    final (d, fake) = await _sidebar(tester, pins: {'b': 1});
    const parcelRows = ['Wire the parcel', 'Sweep the porch'];
    final before = _ys(tester, [...parcelRows, 'Fold the maps', 'Seed data']);

    // Fold the maps (cubby) onto parcel-poc's rows.
    var drag = await _drag(
      tester,
      'Fold the maps',
      before['Wire the parcel']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_ys(tester, parcelRows), {for (final t in parcelRows) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(_y(tester, 'Fold the maps'), before['Fold the maps']);

    // Seed data (pinned, of parcel-poc) onto its project's rows.
    drag = await _drag(tester, 'Seed data', before['Sweep the porch']! + 4);
    await tester.pump(_slide * 2);
    expect(_ys(tester, parcelRows), {for (final t in parcelRows) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(fake.calls.whereType<PinChatsRequest>(), isEmpty);

    // Sweep the porch up over Wire the parcel, then off, onto cubby's.
    drag = await _drag(
      tester,
      'Sweep the porch',
      before['Wire the parcel']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_y(tester, 'Wire the parcel'), isNot(before['Wire the parcel']));
    await drag.moveTo(tester.getCenter(_in('Fold the maps')));
    await tester.pump();
    await tester.pump(_slide * 2);
    expect(_ys(tester, parcelRows), {for (final t in parcelRows) t: before[t]});
    await drag.up();
    await tester.pump(_slide * 2);
    expect(_ys(tester, parcelRows), {for (final t in parcelRows) t: before[t]});
    expect(sidebarChats.value, isEmpty);
    d.dispose();
  });

  testWidgets('a project dragged by its header: the projects it passes '
      'slide apart by its height, and a collapsed one stays collapsed', (
    tester,
  ) async {
    // High enough for the last project under the Mac's top strip, which
    // is as high as a header (ADR 0111): the list doesn't scroll.
    final (d, _) = await _sidebar(tester, height: 584);
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
    await tester.pumpAndSettle(); // its rows fold (a Disclosure)
    expect(_in('Jot it down'), findsNothing);
    const headers = ['parcel-poc', 'cubby', 'garden', 'notes'];
    final before = _ys(tester, headers);
    // A collapsed group is its header: cubby's group less its one row.
    final row = _y(tester, 'Seed data') - _y(tester, 'Wire the parcel');
    final notes = before['garden']! - before['cubby']! - row;

    final drag = await _drag(tester, 'notes', before['parcel-poc']! - 4);
    await tester.pump(_slide * 2);
    final moved = _ys(tester, headers);
    // parcel-poc, cubby and garden down by the same: notes's height.
    final by = moved['parcel-poc']! - before['parcel-poc']!;
    expect(by, closeTo(notes, 0.01));
    for (final h in ['cubby', 'garden']) {
      expect(moved[h], closeTo(before[h]! + by, 0.01));
    }
    expect(moved['notes'], closeTo(before['parcel-poc']!, 0.01));
    expect(_opacity(tester, 'notes'), 0.4);

    await drag.up();
    await tester.pump();
    expect(_ys(tester, headers), {
      'notes': closeTo(before['parcel-poc']!, 0.01),
      for (final h in ['parcel-poc', 'cubby', 'garden'])
        h: closeTo(before[h]! + by, 0.01),
    });
    expect(sidebarOrder.value, [
      '/Users/me/notes',
      _parcel,
      '/Users/me/cubby',
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
    const pinned = ['Jot it down', 'Seed data', 'Fold the maps'];
    final before = _ys(tester, pinned);
    final row = before['Seed data']! - before['Jot it down']!;

    final drag = await _drag(
      tester,
      'Fold the maps',
      before['Jot it down']! - 4,
    );
    await tester.pump(_slide * 2);
    expect(_ys(tester, pinned), {
      'Jot it down': before['Jot it down']! + row,
      'Seed data': before['Seed data']! + row,
      'Fold the maps': before['Jot it down'],
    });
    await drag.up();
    await tester.pump();
    expect(fake.calls.whereType<PinChatsRequest>().last.chatIds, [
      'c',
      'e',
      'b',
    ]);
    expect(_ys(tester, pinned), {
      'Fold the maps': before['Jot it down'],
      'Jot it down': before['Seed data'],
      'Seed data': before['Fold the maps'],
    });
    expect(chatOrder(d).take(3).map((c) => c.id), ['c', 'e', 'b']);
    d.dispose();
  });

  testWidgets('Reduce Motion: the gap opens at once, no slide', (tester) async {
    final (d, _) = await _sidebar(tester, still: true);
    final before = _ys(tester, ['Wire the parcel', 'Seed data']);
    final row = before['Seed data']! - before['Wire the parcel']!;
    final drag = await _drag(
      tester,
      'Sweep the porch',
      before['Wire the parcel']! - 4,
    );
    // No time has passed, and it's there.
    expect(_y(tester, 'Wire the parcel'), before['Wire the parcel']! + row);
    await drag.up();
    await tester.pump();
    expect(_opacity(tester, 'Sweep the porch'), 1);
    expect(sidebarChats.value[_parcel], ['f', 'a', 'b']);
    d.dispose();
  });

  testWidgets('golden: a chat mid-drag, the gap open (dark)', (tester) async {
    final (d, _) = await _sidebar(tester, pins: {'e': 1, 'c': 2});
    final drag = await _drag(
      tester,
      'Sweep the porch',
      _y(tester, 'Wire the parcel') - 4,
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
