// Pinned messages (ADR 0085): the pin among a message's hover actions, the
// mark a pinned one keeps, the chip over the transcript's top left and its
// list, a pick going there; the phone's list, its pins on older pages.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Int64 _ago(int minutes) =>
    Int64(fixtureNow.millisecondsSinceEpoch - minutes * 60000);

String _long(String what) =>
    [for (var i = 0; i < 40; i++) '$what, line $i of the reasoning.']
        .join('\n\n');

final List<Item> _items = [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Make the relay restart cleanly',
    sent: _ago(190),
  ),
  Item(
    id: 'a1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: '## The plan\n\n${_long('The relay')}',
    sent: _ago(188),
  ),
  Item(
    id: 't1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    title: 'Read relay/relay.go',
    toolKind: 'read',
    status: 'completed',
  ),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Now the tests',
    sent: _ago(120),
  ),
  Item(
    id: 'a2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: _long('The tests'),
    sent: _ago(118),
  ),
  Item(
    id: 'u3',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Ship it',
    sent: _ago(4),
  ),
  Item(
    id: 'a3',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Done: the relay restarts without dropping a phone.',
    sent: _ago(3),
  ),
];

/// The window on chat c, its messages [pins] pinned.
Future<(Daemon, FakeDaemon)> _window(
  WidgetTester tester, {
  List<String> pins = const [],
  double width = 1400,
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Relay restarts')..pinnedMessages.addAll(pins);
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: _items)
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

// The test's mouse, made by its first _hover.
final _mice = Expando<TestGesture>();

/// The pointer over [text] in the transcript.
Future<void> _hover(WidgetTester tester, String text) async {
  var mouse = _mice[tester];
  if (mouse == null) {
    mouse = _mice[tester] = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
  }
  await mouse.moveTo(tester.getCenter(find.text(text).first));
  await tester.pumpAndSettle();
}

/// The pins' list's row that starts with [label].
Finder _row(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.textContaining(label, findRichText: true),
);

/// The transcript's scroll.
ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<void> _openList(WidgetTester tester) async {
  await tester.tap(find.byType(PinsChip));
  await tester.pumpAndSettle();
}

/// The band behind the pins' chip is the page's down to past the chip, so
/// no line shows half-hidden beside it.
void _backdropUnder(WidgetTester tester) {
  final chip = tester.getRect(find.byType(PinsChip));
  final band = tester.getRect(find.byType(PinsBackdrop));
  expect(band.top, lessThanOrEqualTo(chip.top));
  expect(band.bottom - PinsBackdrop.fade, greaterThanOrEqualTo(chip.bottom));
}

void main() {
  setUpAll(loadFonts);

  test('a row’s first line drops what opens Markdown', () {
    Item m(String text) => Item(text: text);
    expect(firstLine(m('\n\n## The plan\nmore')), 'The plan');
    expect(firstLine(m('> quoted **bold** `code`')), 'quoted bold code');
    expect(firstLine(m('- one\n- two')), 'one');
    expect(firstLine(Item(images: [ImageData()])), 'Image');
  });

  testWidgets('pin and unpin from the hover row; a pinned message’s mark', (
    tester,
  ) async {
    final (d, fake) = await _window(tester);
    expect(find.byType(PinsChip), findsNothing); // nothing pinned: no chip
    expect(find.byType(PinnedMark), findsNothing);

    await _hover(tester, 'Ship it');
    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<PinMessageRequest>().single;
    expect((asked.chatId, asked.itemId, asked.pinned), ('c', 'u3', true));
    expect(d.chats['c']!.pinnedMessages, ['u3']);
    // Under the pointer, its action reads Unpin; elsewhere its mark stays.
    expect(find.byTooltip('Unpin'), findsOneWidget);
    await _hover(tester, 'Done: the relay restarts without dropping a phone.');
    expect(find.byType(PinnedMark), findsOneWidget);
    expect(find.byTooltip('Pinned'), findsOneWidget);
    expect(find.byType(PinsChip), findsOneWidget);
    expect(find.byTooltip('1 pinned message'), findsOneWidget);

    // The agent's message: its pin first in its row, where its mark goes.
    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.pinnedMessages, ['u3', 'a3']);
    expect(find.byTooltip('2 pinned messages'), findsOneWidget);

    await _hover(tester, 'Ship it');
    await tester.tap(find.byTooltip('Unpin'));
    await tester.pumpAndSettle();
    await _hover(tester, 'Done: the relay restarts without dropping a phone.');
    await tester.tap(find.byTooltip('Unpin'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.pinnedMessages, isEmpty);
    expect(find.byType(PinsChip), findsNothing);
    expect(find.byType(PinnedMark), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a pin the daemon refuses goes back', (tester) async {
    final (d, fake) = await _window(tester);
    fake.answer = (input) =>
        input is PinMessageRequest ? throw StateError('no such message') : null;
    await _hover(tester, 'Ship it');
    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.pinnedMessages, isEmpty);
    expect(find.byType(PinsChip), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('what can be pinned: a message of the chat’s own, shown by a '
      'daemon that keeps pins', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')..items.addAll(_items);
    expect(canPinMessage(d, chat, _items[0]), isFalse); // a side chat's
    d.chats['c'] = chat;
    final step = Item(
      id: 's',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'Inside',
      parent: 't1',
    );
    final going = Item(id: 'g', kind: ItemKind.ITEM_KIND_USER_MESSAGE);
    chat.sending.add(going);
    expect(canPinMessage(d, chat, _items[0]), isTrue);
    expect(canPinMessage(d, chat, _items[1]), isTrue);
    expect(canPinMessage(d, chat, _items[2]), isFalse); // a tool call
    expect(canPinMessage(d, chat, step), isFalse); // a subagent's
    expect(canPinMessage(d, chat, going), isFalse); // on its way
    d.daemonApi = messagePinApi - 1;
    expect(canPinMessage(d, chat, _items[0]), isFalse);
    d.dispose();
  });

  testWidgets('the list: the start first, then the pins in the transcript’s '
      'order; a pick goes there; Esc closes it', (tester) async {
    final (d, _) = await _window(tester, pins: ['a3', 'u2', 'u1']);
    final chip = tester.getRect(find.byType(PinsChip));
    final list = tester.getRect(find.byType(SelectionArea));
    expect(chip.left - list.left, lessThan(40), reason: 'at the top left');
    expect(chip.top - list.top, lessThan(20));

    await _openList(tester);
    final rows = [
      'Start of the chat',
      'Make the relay restart cleanly',
      'Now the tests',
      'Done: the relay restarts',
    ];
    final tops = [for (final r in rows) tester.getRect(_row(r)).top];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(_row('You · 3h ago'), findsOneWidget); // u1, sent 190 min ago
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_row('Start of the chat'), findsNothing);

    // A pick takes the list to the message, its top under the chip, and
    // tints it for a moment.
    await _openList(tester);
    await tester.tap(_row('Now the tests'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final p = _scroll(tester);
    expect(p.pixels, greaterThan(0));
    expect(p.pixels, lessThan(p.maxScrollExtent));
    final at = tester.getRect(find.text('Now the tests').first);
    expect(at.top, greaterThan(chip.bottom - 4));
    expect(at.top, lessThan(chip.bottom + 60));
    PinFlash flashOf(String text) => tester.widget<PinFlash>(
      find.ancestor(of: find.text(text).first, matching: find.byType(PinFlash)),
    );
    expect(flashOf('Now the tests').on, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(flashOf('Now the tests').on, isFalse);

    // The start: the top.
    await _openList(tester);
    await tester.tap(_row('Start of the chat'));
    await tester.pumpAndSettle();
    expect(_scroll(tester).pixels, 0);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the chip works from the keyboard', (tester) async {
    final (d, _) = await _window(tester, pins: ['u2']);
    final inside = find.descendant(
      of: find.byType(PinsChip),
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(inside.first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_row('Start of the chat'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_row('Start of the chat'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (width, b) in [
    (1700.0, Brightness.dark),
    (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    (720.0, Brightness.light),
  ]) {
    testWidgets('the window, $width wide, ${b.name}: pinned, the list open', (
      tester,
    ) async {
      paneWidths.value = {};
      // At 720, where the chip stands over the text, it's a window golden
      // (the sidebar hidden: it has its own); at 1700 a render.
      final golden = width == 720;
      if (golden) sidebarHidden.value = true;
      final (d, _) = await _window(
        tester,
        pins: ['u1', 'u3', 'a3'],
        width: width,
        brightness: b,
      );
      expect(find.byType(PinnedMark), findsNWidgets(3));
      await _openList(tester);
      expect(tester.takeException(), isNull);
      // The list inside the window, beside the chip.
      final menu = tester.getRect(_row('Start of the chat'));
      expect(menu.right, lessThan(width));
      // Where the chip stands over the text, the page's band behind it.
      expect(find.byType(PinsBackdrop), width < 1000 ? findsOne : findsNothing);
      if (width < 1000) _backdropUnder(tester);
      final shot = 'message_pins_${width.toInt()}_${b.name}';
      if (golden) {
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/$shot.png'),
        );
      } else {
        await render(tester, find.byType(NushiApp), shot);
      }
      await closeView(tester, d);
    }, variant: _mac);
  }

  for (final b in Brightness.values) {
    testWidgets('the phone: its list takes the older page a pin is on '
        '(390×844, ${b.name})', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
      final c = chat('c', 'claude', 'Relay restarts')
        ..pinnedMessages.addAll(['u1', 'a3', 'u3']);
      final pages = <String>[];
      final fake = FakeDaemon([c])
        ..answer = (input) {
          if (input is GetChatItemsRequest) pages.add(input.before);
          return switch (input) {
            GetChatRequest() => GetChatResponse(
              chat: c,
              items: _items.sublist(3),
              older: 3,
            ),
            GetChatItemsRequest() => GetChatItemsResponse(
              items: _items.sublist(0, 3),
            ),
            _ => null,
          };
        };
      final phone = Phone(
        PhonePlatform()..saved = pairedRecord(),
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Relay restarts'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Every pin counted, though one is on a page not taken yet; no Pin
      // on the phone, which has no actions row, but the marks.
      expect(find.byTooltip('3 pinned messages'), findsOneWidget);
      expect(find.byTooltip('Pin'), findsNothing);
      expect(find.byType(PinnedMark), findsNWidgets(2));

      await tester.tap(find.byType(PinsChip));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(pages, ['u2']);
      expect(_row('Make the relay restart cleanly'), findsOneWidget);
      expect(tester.takeException(), isNull);
      _backdropUnder(tester);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/message_pins_phone_${b.name}.png'),
      );

      await tester.tap(_row('Make the relay restart cleanly'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final at = tester.getRect(find.text('Make the relay restart cleanly'));
      expect(at.top, greaterThan(0));
      expect(at.bottom, lessThan(844));
      await endPhone(tester, phone);
    });
  }
}
