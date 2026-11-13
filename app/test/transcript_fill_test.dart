// What a long chat takes in above what's built builds over a few frames
// (ADR 0026), never all at once: a page that ends inside a run of calls,
// one while a find looks (a pin near the start and ⌘F's Load all:
// transcript_pages_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_pins.dart';
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
