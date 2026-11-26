import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_groups.dart';

import 'fake_daemon.dart';
import 'sidebar_fixture.dart';

// The sidebar's rows arrive, leave and move (the fluidity review's idea
// 9): a new row grows in, one that goes fades and folds, one pinned glides
// to its new place, and a starting chat's placeholder row is replaced by
// its row with no jump; only when the lists change, never on a status.

const _parcel = '/Users/me/parcel-poc';
const _garden = '/Users/me/garden';

List<Chat> _chats() => [
  chat('a', 'claude', 'Wire the parcel', folder: _parcel),
  chat('c', 'codex', 'Fold the maps', folder: '/Users/me/cubby', age: 1),
  chat('d', 'claude', 'Plant the beds', folder: _garden, age: 2),
  chat('b', 'pig', 'Seed data', folder: _parcel, age: 5),
  chat('f', 'claude', 'Sweep the porch', folder: _parcel, age: 6),
];

/// The sidebar alone on [_chats], with Reduce Motion when [still].
Future<(Daemon, FakeDaemon)> _sidebar(
  WidgetTester tester, {
  bool still = false,
}) => arrangedSidebar(
  tester,
  chats: _chats(),
  size: const Size(280, 560),
  still: still,
  settle: false,
);

Finder _in(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text));

/// Where [text] is drawn (its first, as a row leaving may be under it).
double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(_in(text).first).dy;

/// The height of [text]'s row as the list lays it out.
double _height(WidgetTester tester, String text) => tester
    .getSize(
      find.ancestor(of: _in(text), matching: find.byType(Presence)).first,
    )
    .height;

/// Whether some row is coming or going: drawn faded by its [Presence].
bool _moving(WidgetTester tester) => find
    .byType(Presence)
    .evaluate()
    .any(
      (e) =>
          tester
              .widget<Opacity>(
                find
                    .descendant(
                      of: find.byWidget(e.widget),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity <
          1,
    );

void main() {
  setUpAll(loadFonts);

  testWidgets('as the sidebar is first built nothing moves; a new chat’s '
      'row grows in and rises, the rows under it moving down with it', (
    tester,
  ) async {
    final (d, fake) = await _sidebar(tester);
    expect(_moving(tester), isFalse);
    final row = _height(tester, 'Seed data');
    final seed = _y(tester, 'Seed data');

    final n = chat('n', 'ante', 'Try the ghost', folder: _parcel, age: -1);
    fake
      ..chats.add(n)
      ..emit(EventsResponse(chatId: 'n', chat: n));
    await tester.pump();
    await tester.pump();
    expect(_height(tester, 'Try the ghost'), 0);
    await tester.pump(Motion.standard ~/ 2);
    final mid = _height(tester, 'Try the ghost');
    expect(mid, inExclusiveRange(1, row - 1));
    expect(_moving(tester), isTrue);
    expect(_y(tester, 'Seed data'), inExclusiveRange(seed, seed + row));
    // It takes a click as it comes.
    await tester.tap(_in('Try the ghost'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'n');
    expect(_height(tester, 'Try the ghost'), row);
    expect(_y(tester, 'Seed data'), seed + row);
    expect(_moving(tester), isFalse);
    d.dispose();
  });

  testWidgets('an archived chat’s row fades and folds, taking no clicks as '
      'it goes; a status change moves nothing', (tester) async {
    final (d, fake) = await _sidebar(tester);
    final price = _y(tester, 'Sweep the porch');
    final row = _height(tester, 'Seed data');

    final working = fake.chats.firstWhere((c) => c.id == 'a')
      ..status = ChatStatus(busy: true);
    fake.emit(EventsResponse(chatId: 'a', chat: working));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_moving(tester), isFalse);

    final seed = fake.chats.firstWhere((c) => c.id == 'b')..archived = true;
    fake.emit(EventsResponse(chatId: 'b', chat: seed));
    // The event in, then the row built going: with nothing looping, the
    // first pump has no frame to draw it in.
    await tester.pump();
    await tester.pump();
    await tester.pump(Motion.exit ~/ 2);
    expect(_in('Seed data'), findsOneWidget);
    expect(_moving(tester), isTrue);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: _in('Seed data'),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    expect(_y(tester, 'Sweep the porch'), inExclusiveRange(price - row, price));
    await tester.pump(Motion.exit);
    await tester.pump();
    expect(_in('Seed data'), findsNothing);
    expect(_y(tester, 'Sweep the porch'), price - row);
    d.dispose();
  });

  testWidgets('a pinned chat glides from its place to Pinned, from where '
      'it was drawn', (tester) async {
    final (d, _) = await _sidebar(tester);
    final from = _y(tester, 'Sweep the porch');
    unawaited(setChatPins(d, ['f']));
    await tester.pump();
    // The first frame draws it where it was, in its new list (Pinned,
    // first; the place it left is empty).
    expect(_y(tester, 'Sweep the porch'), closeTo(from, 0.5));
    await tester.pump(Motion.standard ~/ 2);
    final mid = _y(tester, 'Sweep the porch');
    expect(mid, lessThan(from - 20));
    await tester.pumpAndSettle();
    final to = _y(tester, 'Sweep the porch');
    expect(mid, greaterThan(to));
    expect(to, lessThan(_y(tester, 'Wire the parcel')));

    // Unpinned and pinned again mid-glide: it ends up shown, once, and
    // takes clicks.
    unawaited(setChatPins(d, []));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 4);
    unawaited(setChatPins(d, ['f']));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_in('Sweep the porch'), findsOneWidget);
    await tester.tap(_in('Sweep the porch'));
    await tester.pump();
    expect(d.selectedId, 'f');
    d.dispose();
  });

  testWidgets('a starting chat’s placeholder row, its project gliding to '
      'the top where its row will be, then its row in its place with no '
      'jump', (tester) async {
    final (d, fake) = await _sidebar(tester);
    final reply = Completer<StartChatResponse>();
    fake.answer = (input) => input is StartChatRequest ? reply.future : null;
    final row = _height(tester, 'Plant the beds');
    final first = _y(tester, 'Wire the parcel');
    final was = _y(tester, 'Plant the beds');
    unawaited(d.startChat(_garden, 'claude'));
    await tester.pump();
    // garden goes first, as its new chat will put it: it glides there
    // from where it was drawn.
    expect(_y(tester, 'Plant the beds'), closeTo(was, 0.5));
    await tester.pump(Motion.standard ~/ 2);
    expect(_y(tester, 'Plant the beds'), inExclusiveRange(first, was));
    // Its ring turns while it starts: no settling.
    await tester.pump(Motion.standard * 2);
    expect(find.byType(StartingRow), findsOneWidget);
    expect(_in('Starting Claude…'), findsOneWidget);
    final at = _y(tester, 'Starting Claude…');
    expect(at, lessThan(_y(tester, 'Plant the beds')));
    // As tall as a row, so the row replaces it with no jump.
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byType(StartingRow),
                  matching: find.byType(Presence),
                )
                .first,
          )
          .height,
      row,
    );
    final plant = _y(tester, 'Plant the beds');

    // The chat's event comes first, then the reply, as the daemon sends.
    final n = chat('n', 'claude', 'Water the roses', folder: _garden, age: -1);
    fake
      ..chats.add(n)
      ..emit(EventsResponse(chatId: 'n', chat: n));
    await tester.pump(); // the event
    await tester.pump(); // its frame
    expect(find.byType(StartingRow), findsNothing);
    expect(_y(tester, 'Water the roses'), at);
    expect(_height(tester, 'Water the roses'), row);
    expect(_y(tester, 'Plant the beds'), plant);
    reply.complete(StartChatResponse(chatId: 'n'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_moving(tester), isFalse);
    expect(_y(tester, 'Plant the beds'), plant);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'n');
    d.dispose();
  });

  testWidgets('with Reduce Motion rows come and go at once; the placeholder '
      'still shows', (tester) async {
    final (d, fake) = await _sidebar(tester, still: true);
    final row = _height(tester, 'Seed data');
    final n = chat('n', 'ante', 'Try the ghost', folder: _parcel, age: -1);
    fake
      ..chats.add(n)
      ..emit(EventsResponse(chatId: 'n', chat: n));
    final seed = fake.chats.firstWhere((c) => c.id == 'b')..archived = true;
    fake.emit(EventsResponse(chatId: 'b', chat: seed));
    await tester.pump();
    await tester.pump();
    expect(_height(tester, 'Try the ghost'), row);
    expect(_in('Seed data'), findsNothing);
    expect(_moving(tester), isFalse);

    final reply = Completer<StartChatResponse>();
    fake.answer = (input) => input is StartChatRequest ? reply.future : null;
    unawaited(d.startChat(_garden, 'claude'));
    await tester.pump();
    await tester.pump();
    expect(_in('Starting Claude…'), findsOneWidget);
    reply.complete(StartChatResponse(chatId: 'd'));
    await tester.pumpAndSettle();
    expect(find.byType(StartingRow), findsNothing);
    d.dispose();
  });
}
