// What a long chat takes in above what's built builds over a few frames
// (ADR 0026), never all at once: a page that ends inside a run of calls,
// a pin near the start, ⌘F's Load all.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<(Daemon, PagedChat)> _window(
  WidgetTester tester,
  List<Item> items, {
  List<String> pins = const [],
}) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final c = chat('c', 'claude', 'A long chat')
    ..pinnedMessages.addAll(pins)
    ..messagePins.addAll([
      for (final id in pins) MessagePin(itemId: id, title: 'Pin $id'),
    ]);
  final paged = PagedChat(c, items);
  final fake = FakeDaemon([c])..answer = paged.answer;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await _settle(tester);
  return (d, paged);
}

Future<void> _settle(WidgetTester tester, [int n = 40]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// How many entries are built.
int _built() => find.byType(PinFlash).evaluate().length;

/// The most entries any one of the next [frames] frames built.
Future<int> _mostAFrame(WidgetTester tester, {int frames = 200}) async {
  var was = _built();
  var most = 0;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final now = _built();
    if (now - was > most) most = now - was;
    was = now;
  }
  return most;
}

/// Blocks of a message, three reads (one run) and an answer: a page's
/// first item is the second read of a run its page before has the first
/// of, given [extra] items at the end.
List<Item> _runs(int blocks, {int extra = 2}) => [
  for (var n = 0; n < blocks; n++) ...[
    Item(
      id: 'u$n',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: 'Ask #$n please',
    ),
    for (var r = 0; r < 3; r++)
      Item(
        id: 'r$n-$r',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        toolKind: 'read',
        title: 'Read f$r.go',
        status: 'completed',
      ),
    Item(
      id: 'a$n',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'Answer #$n: it reads the files.',
    ),
  ],
  for (var i = 0; i < extra; i++)
    Item(id: 'end$i', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done $i.'),
];

ChatState _chat(Daemon d) => d.chats['c']!;

void main() {
  setUpAll(loadFonts);

  testWidgets('a page that ends inside a run of calls builds over frames', (
    tester,
  ) async {
    final (d, _) = await _window(tester, _runs(200));
    final c = _chat(d);
    // The recent part starts at the second read of a run.
    expect(c.items.first.id, 'r160-1');
    final page = d.loadOlder(c);
    final most = await _mostAFrame(tester);
    await page;
    expect(c.items.first.id, 'r120-1');
    expect(
      most,
      lessThanOrEqualTo(30),
      reason: 'the page, about 120 entries, a few frames',
    );
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a pin near a long chat’s start builds up to it over frames, '
      'then goes there', (tester) async {
    final (d, paged) = await _window(
      tester,
      longChat('c', turns: 100),
      pins: ['c-a2'],
    );
    final c = _chat(d);
    expect(c.items.any((it) => it.id == 'c-a2'), isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 600));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(
      tester.getCenter(
        find
            .descendant(of: find.byType(Rail), matching: find.byType(RailDash))
            .first,
      ),
    );
    await _settle(tester);
    final before = _built();
    await tester.tap(
      find.descendant(of: find.byType(Rail), matching: find.text('Pin c-a2')),
    );
    final most = await _mostAFrame(tester);
    expect(c.items.length, paged.items.length - c.older);
    expect(_built(), greaterThan(before + 300));
    expect(most, lessThanOrEqualTo(4 * 24 + 4), reason: 'never all at once');
    final list = tester.getRect(find.byType(SelectionArea));
    final at = tester.getRect(
      find.textContaining('What turn 2 found', findRichText: true).first,
    );
    expect(at.top - list.top, inInclusiveRange(0, 80));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⌘F’s Load all builds over frames, then finds', (tester) async {
    final (d, _) = await _window(tester, longChat('c', turns: 100));
    final c = _chat(d);
    c.find
      ..open()
      ..query = 'Turn 3:';
    await _settle(tester);
    expect(c.find.count, 'None');
    await tester.tap(find.text('Load all'));
    final most = await _mostAFrame(tester);
    expect(c.older, 0);
    expect(most, lessThanOrEqualTo(4 * 24 + 4), reason: 'never all at once');
    expect(c.find.count, '1 of 1');
    final list = tester.getRect(find.byType(SelectionArea));
    final hit = tester.getRect(
      find.textContaining('Turn 3:', findRichText: true).first,
    );
    expect(hit.top, greaterThanOrEqualTo(list.top));
    expect(hit.bottom, lessThanOrEqualTo(list.bottom));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a page fills in over frames while a find looks, and the '
      'find keeps what it found', (tester) async {
    final (d, _) = await _window(tester, longChat('c', turns: 100));
    final c = _chat(d);
    c.find
      ..open()
      ..query = 'Turn 95:';
    await _settle(tester);
    expect(c.find.count, '1 of 1');
    final hit = c.find.current;
    final page = d.loadOlder(c);
    final most = await _mostAFrame(tester, frames: 60);
    await page;
    expect(most, lessThanOrEqualTo(4 * 24 + 4));
    expect(c.find.count, '1 of 1');
    expect(c.find.current, hit);
    await closeView(tester, d);
  }, variant: _mac);
}
