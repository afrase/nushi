// What reaches past a long chat's recent part (ADR 0026): a pane open on
// an early subagent outlives the chat going back to its recent part, and a
// chat let go scrolled up reopens where it was; Up reaches a last message
// above the recent part; a task running before it shows.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The window on chat c, [items] paged, with another chat s to switch to.
Future<(Daemon, PagedChat)> _open(
  WidgetTester tester,
  List<Item> items, {
  ChatStatus? status,
  bool details = false,
}) async {
  viewport(tester, const Size(1700, 900));
  showDetails.value = details;
  final c = chat('c', 'claude', 'A long chat', status: status);
  final paged = PagedChat(c, items);
  final other = chat('s', 'claude', 'Short', age: 5);
  final fake = FakeDaemon([c, other])
    ..answer = (input) =>
        paged.answer(input) ??
        (input is GetChatRequest
            ? GetChatResponse(chat: other, items: longChat('s', turns: 1))
            : null);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await _settle(tester);
  return (d, paged);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a pane open on an early subagent stays after switching away '
      'at the bottom and back', (tester) async {
    final (d, _) = await _open(tester, longChat('c', turns: 100));
    final c = d.chats['c']!;
    await d.loadOlder(c, all: true);
    await _settle(tester);
    c.pane.value = 'c-sa3'; // opened from its row
    await _settle(tester);
    // Still at its bottom: away and back, which lets go of what's above.
    d.select('s');
    await _settle(tester);
    d.select('c');
    await _settle(tester);
    expect(c.older, greaterThan(0), reason: 'back to its recent part');
    expect(c.pane.value, 'c-sa3');
    expect(c.items.any((it) => it.id == 'c-sa3'), isTrue);
    expect(find.text('This subagent is no longer in the chat.'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('left scrolled to its start and let go (not among the last '
      'six), a chat reopens where it was', (tester) async {
    viewport(tester, const Size(1400, 900));
    showDetails.value = false;
    final c = chat('c', 'claude', 'A long chat');
    final paged = PagedChat(c, longChat('c', turns: 100));
    final others = [
      for (var i = 0; i < 7; i++) chat('s$i', 'claude', 'Short $i', age: 5 + i),
    ];
    final fake = FakeDaemon([c, ...others])
      ..answer = (input) =>
          paged.answer(input) ??
          (input is GetChatRequest
              ? GetChatResponse(
                  chat: others.firstWhere((o) => o.id == input.chatId),
                  items: longChat(input.chatId, turns: 1),
                )
              : null);
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await _settle(tester);
    final cs = d.chats['c']!;
    await d.loadOlder(cs, all: true);
    await _settle(tester);
    ScrollPosition scroll() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SelectionArea),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    scroll().jumpTo(0); // reading its start
    await _settle(tester);
    for (final o in others) {
      d.select(o.id);
      await _settle(tester);
    }
    expect(cs.items, isEmpty, reason: 'let go');
    d.select('c');
    await _settle(tester);
    await _settle(tester);
    expect(cs.older, 0);
    expect(scroll().pixels, lessThan(1));
    final list = tester.getRect(find.byType(SelectionArea));
    final start = tester.getRect(
      find.textContaining('Turn 0:', findRichText: true).first,
    );
    expect(start.top, greaterThanOrEqualTo(list.top));
    expect(start.bottom, lessThanOrEqualTo(list.bottom));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Up recalls the last message when the last turn is longer '
      'than the recent part', (tester) async {
    final items = [
      ...longChat('c', turns: 80),
      Item(
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        id: 'u-last',
        text: 'refactor the whole thing',
      ),
      for (var i = 0; i < 125; i++) ...[
        Item(
          id: 'say$i',
          kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
          text: 'Step $i: now I read the next file to see how it does it.',
        ),
        Item(
          id: 'step$i',
          kind: ItemKind.ITEM_KIND_TOOL_CALL,
          toolKind: 'read',
          title: 'Read f$i.go',
          status: 'completed',
        ),
      ],
    ];
    final (d, _) = await _open(tester, items);
    final c = d.chats['c']!;
    expect(c.items.any((it) => it.id == 'u-last'), isFalse);
    final box = find.descendant(
      of: find.byType(Composer),
      matching: find.byType(TextField),
    );
    await tester.tap(box);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _settle(tester);
    expect(
      tester.widget<TextField>(box).controller!.text,
      'refactor the whole thing',
    );
    expect(c.older, greaterThan(0), reason: 'only the pages back to it');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a background command started early and still running shows '
      'in Background tasks, and its events keep it up', (tester) async {
    final items = [
      Item(kind: ItemKind.ITEM_KIND_USER_MESSAGE, id: 'u-start', text: 'go'),
      Item(
        id: 'bg',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        title: 'npm run dev',
        status: 'completed',
        backgroundCommand: BackgroundCommand(id: 'b1', state: 'running'),
      ),
      ...longChat('c', turns: 100),
    ];
    final (d, _) = await _open(
      tester,
      items,
      status: ChatStatus(background: 1),
      details: true,
    );
    final c = d.chats['c']!;
    expect(c.older, greaterThan(0));
    expect(c.items.any((it) => it.id == 'bg'), isFalse);
    expect(find.text('npm run dev'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget); // it runs
    // It ends: its event, before the recent part, still reaches it.
    c.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1000),
        item: ItemEvent(
          index: 1,
          item: items[1].deepCopy()
            ..backgroundCommand = BackgroundCommand(
              id: 'b1',
              state: 'completed',
            ),
        ),
      ),
    );
    await _settle(tester);
    expect(c.runningBefore.single.backgroundCommand.state, 'completed');
    expect(find.byTooltip('Stop'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);
}
