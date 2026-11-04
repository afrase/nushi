// Pinned messages (ADR 0085): the pin among an agent message's actions
// (none on the user's), the rail at the transcript's top left, its current
// entry following the scroll, its menu opened by the pointer, a click or
// the keyboard, a pick going there; the phone's, its pins on older pages.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/pins_rail.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';

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

/// [_items], the text of [id] [text].
List<Item> _itemsWith(String id, String text) => [
  for (final it in _items)
    if (it.id == id) it.deepCopy()..text = text else it,
];

/// The titles the daemon gave the agent's messages.
const _titles = {
  'a1': 'Relay restart plan',
  'a2': 'The tests reasoned through',
  'a3': 'Relay restarts shipped',
};

/// Chat c, its messages [pins] pinned, titled as [_titles] has them;
/// running a turn if [busy].
Chat _chat(List<String> pins, {bool busy = false}) =>
    chat('c', 'claude', 'Relay restarts', status: ChatStatus(busy: busy))
      ..pinnedMessages.addAll(pins)
      ..messagePins.addAll([
        for (final id in pins) MessagePin(itemId: id, title: _titles[id]),
      ]);

/// The window on chat c, its messages [pins] pinned.
Future<(Daemon, FakeDaemon)> _window(
  WidgetTester tester, {
  List<String> pins = const [],
  double width = 1400,
  Brightness brightness = Brightness.dark,
  bool busy = false,
  List<Item>? items,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  final c = _chat(pins, busy: busy);
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: items ?? _items, status: c.status)
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  if (busy) {
    // A running turn's spinner never settles.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  } else {
    await tester.pumpAndSettle();
  }
  return (d, fake);
}

// The test's mouse, made by its first _move.
final _mice = Expando<TestGesture>();

/// The pointer at [at].
Future<void> _move(WidgetTester tester, Offset at) async {
  var mouse = _mice[tester];
  if (mouse == null) {
    mouse = _mice[tester] = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
  }
  await mouse.moveTo(at);
  await tester.pumpAndSettle();
}

/// The pointer over [text] in the transcript.
Future<void> _hover(WidgetTester tester, String text) =>
    _move(tester, tester.getCenter(find.text(text).first));

/// The rail's dashes (not its menu's).
Finder get _railDashes =>
    find.descendant(of: find.byType(PinsRail), matching: find.byType(PinDash));

/// Which of the rail's [count] entries is current: its long dash.
int _current(WidgetTester tester, int count) => tester
    .widgetList<PinDash>(_railDashes)
    .take(count)
    .toList()
    .indexWhere((d) => d.on);

/// The menu's row of [title].
Finder _row(String title) =>
    find.descendant(of: find.byType(PinsRail), matching: find.text(title));

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

/// The transcript scrolled to [to], and laid out.
Future<void> _scrollTo(WidgetTester tester, double to) async {
  final p = _scroll(tester);
  p.jumpTo(to.clamp(p.minScrollExtent, p.maxScrollExtent));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200)); // the dashes' change
}

/// Where the message that opens with [text] starts in the scroll.
double _topOf(WidgetTester tester, String text) {
  final list = tester.getRect(find.byType(SelectionArea)).top;
  final at = tester.getRect(
    find.textContaining(text, findRichText: true).first,
  );
  return _scroll(tester).pixels + at.top - list;
}

/// The room from the rail's long dash to the words of the last message.
double _gapToWords(WidgetTester tester) {
  final long = tester.getRect(_railDashes.at(_current(tester, 4)));
  final words = tester.getRect(
    find.textContaining('Done: the relay', findRichText: true).last,
  );
  return words.left - long.right;
}

/// Opens the menu with the pointer over the rail, come from elsewhere: a
/// pick leaves the menu closed until the pointer has left the rail.
Future<void> _openMenu(WidgetTester tester) async {
  final rail = tester.getRect(find.byType(PinsRail));
  await _move(tester, rail.bottomRight + const Offset(40, 40));
  await _move(tester, tester.getCenter(_railDashes.first));
  expect(_row('Session start'), findsOneWidget);
}

void main() {
  setUpAll(loadFonts);

  test('a pin without a title is listed by its message’s first line', () {
    Item m(String text) => Item(text: text);
    expect(firstLine(m('\n\n## The plan\nmore')), 'The plan');
    expect(firstLine(m('> quoted **bold** `code`')), 'quoted bold code');
    expect(firstLine(m('- one\n- two')), 'one');
    expect(firstLine(Item(images: [ImageData()])), 'Image');
  });

  testWidgets('pin and unpin an agent message from its actions; none on '
      'the user’s', (tester) async {
    final (d, fake) = await _window(tester);
    expect(find.byType(PinsRail), findsNothing); // nothing pinned: no rail

    await _hover(tester, 'Ship it');
    expect(find.byTooltip('Pin'), findsNothing);

    await _hover(tester, 'Done: the relay restarts without dropping a phone.');
    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<PinMessageRequest>().single;
    expect((asked.chatId, asked.itemId, asked.pinned), ('c', 'a3', true));
    expect(d.chats['c']!.pinnedMessages, ['a3']);
    // Its pin held down and filled, Unpin under the pointer; the rail: the
    // start and the pin.
    final pin = tester.widget<IconTap>(
      find.ancestor(
        of: find.byTooltip('Unpin'),
        matching: find.byType(IconTap),
      ),
    );
    expect((pin.held, pin.icon), (true, Icons.push_pin));
    expect(_railDashes, findsNWidgets(2));

    await tester.tap(find.byTooltip('Unpin'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.pinnedMessages, isEmpty);
    expect(find.byType(PinsRail), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('no Pin on the message still being written', (tester) async {
    final (d, _) = await _window(tester, busy: true);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<void> over(String text) async {
      await mouse.moveTo(
        tester.getCenter(find.textContaining(text, findRichText: true).last),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await over('Done: the relay restarts without dropping a phone.');
    expect(
      find.byTooltip('Copy as Markdown'),
      findsOneWidget,
      reason: 'its actions',
    );
    expect(find.byTooltip('Pin'), findsNothing);
    await over('The tests, line 39');
    expect(find.byTooltip('Pin'), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a pin the daemon refuses goes back', (tester) async {
    final (d, fake) = await _window(tester);
    fake.answer = (input) =>
        input is PinMessageRequest ? throw StateError('no such message') : null;
    await _hover(tester, 'Done: the relay restarts without dropping a phone.');
    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.pinnedMessages, isEmpty);
    expect(find.byType(PinsRail), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('what can be pinned: an agent message of the chat’s own, '
      'shown by a daemon that keeps pins', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')..items.addAll(_items);
    expect(
      canPinMessage(d, chat, _items[1], live: false),
      isFalse,
    ); // a side chat's
    d.chats['c'] = chat;
    final step = Item(
      id: 's',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'Inside',
      parent: 't1',
    );
    expect(canPinMessage(d, chat, _items[1], live: false), isTrue);
    expect(
      canPinMessage(d, chat, _items[0], live: false),
      isFalse,
    ); // the user's
    expect(
      canPinMessage(d, chat, _items[2], live: false),
      isFalse,
    ); // a tool call
    expect(canPinMessage(d, chat, step, live: false), isFalse); // a subagent's
    // The one still being written: its title would be its first words.
    expect(canPinMessage(d, chat, _items[1], live: true), isFalse);
    d.daemonApi = messagePinApi - 1;
    expect(canPinMessage(d, chat, _items[1], live: false), isFalse);
    d.dispose();
  });

  testWidgets('the rail: the start, then the pins in the transcript’s '
      'order; the current one follows the scroll', (tester) async {
    final (d, _) = await _window(tester, pins: ['a3', 'a1', 'a2']);
    final rail = tester.getRect(_railDashes.first);
    final list = tester.getRect(find.byType(SelectionArea));
    expect(rail.left - list.left, lessThan(24), reason: 'in the margin');
    expect(rail.top - list.top, lessThan(24), reason: 'at the top');
    expect(_railDashes, findsNWidgets(4));

    // Opened at the bottom: the last pin, though its message is short.
    expect(_current(tester, 4), 3);
    final railAt = tester.getTopLeft(_railDashes.first);

    await _scrollTo(tester, 0);
    expect(_current(tester, 4), 0, reason: 'the start, at the top');
    expect(
      tester.getTopLeft(_railDashes.first),
      railAt,
      reason: 'it stays put',
    );
    // a1, a little way down, is current a little way down.
    await _scrollTo(tester, _topOf(tester, 'The relay, line 0'));
    expect(_current(tester, 4), 1);

    // Scrolled up near a pin, it changes as the pin's top crosses the line
    // a third down.
    final third = _scroll(tester).viewportDimension / 3;
    final a2 = _topOf(tester, 'The tests, line 0');
    await _scrollTo(tester, a2 - third - 40);
    expect(_current(tester, 4), 1);
    await _scrollTo(tester, a2 - third + 40);
    expect(_current(tester, 4), 2);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('two short answers at the end: each is current somewhere, '
      'and a pick is current until the list scrolls', (tester) async {
    final items = _itemsWith('a2', 'The tests pass.');
    final (d, _) = await _window(
      tester,
      pins: ['a1', 'a2', 'a3'],
      items: items,
    );
    final p = _scroll(tester);
    final seen = <int>{};
    for (var at = p.maxScrollExtent; at > -5; at -= 5) {
      await _scrollTo(tester, at);
      seen.add(_current(tester, 4));
    }
    expect(seen, {0, 1, 2, 3});

    for (final (row, want) in [
      ('The tests reasoned through', 2), // a2, near the bottom
      ('Session start', 0),
      ('Relay restart plan', 1),
    ]) {
      await _openMenu(tester);
      await tester.tap(_row(row));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(_current(tester, 4), want, reason: row);
    }
    // Scrolled from there, it's found again.
    await _scrollTo(tester, p.maxScrollExtent);
    expect(_current(tester, 4), 3);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a call opened above a pin moves it: the current entry '
      'follows, though nothing scrolled', (tester) async {
    final items = _itemsWith(
      't1',
      [for (var i = 0; i < 60; i++) 'out $i'].join('\n'),
    );
    final (d, _) = await _window(tester, pins: ['a1', 'a2'], items: items);
    final third = _scroll(tester).viewportDimension / 3;
    await _scrollTo(tester, _topOf(tester, 'The tests, line 0') - third + 30);
    expect(_current(tester, 3), 2);
    final call = find.text('Read relay/relay.go').first;
    final list = tester.getRect(find.byType(SelectionArea));
    expect(list.contains(tester.getCenter(call)), isTrue, reason: 'in view');
    final before = _scroll(tester).pixels;
    await tester.tap(call);
    await tester.pumpAndSettle();
    expect(_scroll(tester).pixels, before, reason: 'nothing scrolled');
    expect(_topOf(tester, 'The tests, line 0') - before, greaterThan(third));
    expect(_current(tester, 3), 1);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the pointer over the rail opens its menu; leaving both '
      'closes it; a pick goes there', (tester) async {
    final (d, _) = await _window(tester, pins: ['a3', 'a1', 'a2']);
    expect(_row('Session start'), findsNothing);
    await _openMenu(tester);
    final rows = [
      'Session start',
      'Relay restart plan',
      'The tests reasoned through',
      'Relay restarts shipped',
    ];
    final tops = [for (final r in rows) tester.getRect(_row(r)).top];
    expect(tops, orderedEquals([...tops]..sort()));
    // The current row's title bright, the others dim.
    final t = NushiTheme.of(tester.element(_row(rows.last))).t;
    Color? colorOf(String r) => tester.widget<Text>(_row(r)).style?.color;
    expect(colorOf(rows.last), t.text);
    expect(colorOf(rows[1]), pinTitleDim(t));

    // Over the menu it stays; away from both it goes.
    await _move(tester, tester.getCenter(_row(rows[1])));
    expect(colorOf(rows[1]), t.text, reason: 'the row under the pointer');
    await _move(tester, const Offset(900, 600));
    await tester.pump(PinsRail.linger);
    await tester.pumpAndSettle();
    expect(_row('Session start'), findsNothing);

    // A pick takes the list to the message, its top near the
    // transcript's, and tints it for a moment.
    await _openMenu(tester);
    await tester.tap(_row('The tests reasoned through'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final p = _scroll(tester);
    expect(p.pixels, greaterThan(0));
    expect(p.pixels, lessThan(p.maxScrollExtent));
    final list = tester.getRect(find.byType(SelectionArea));
    final at = tester.getRect(
      find.textContaining('The tests, line 0', findRichText: true).first,
    );
    expect(at.top - list.top, inInclusiveRange(0, 60));
    expect(_current(tester, 4), 2);
    PinFlash flash() => tester.widget<PinFlash>(
      find.ancestor(
        of: find.textContaining('The tests, line 0', findRichText: true).first,
        matching: find.byType(PinFlash),
      ),
    );
    expect(flash().on, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(flash().on, isFalse);

    // The start: the top.
    await _openMenu(tester);
    await tester.tap(_row('Session start'));
    await tester.pumpAndSettle();
    expect(_scroll(tester).pixels, 0);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a click on a menu row over the rail picks it, and the '
      'menu stays closed until the pointer leaves the rail', (tester) async {
    final (d, _) = await _window(tester, pins: ['a1', 'a2', 'a3']);
    final rail = tester.getRect(find.byType(PinsRail));
    await _openMenu(tester);
    final row = tester.getRect(_row('Session start'));
    final at = Offset(rail.right - 3, row.center.dy);
    expect(rail.contains(at), isTrue, reason: 'the row is over the rail');
    await _move(tester, at);
    final mouse = _mice[tester]!;
    await mouse.down(at);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_scroll(tester).pixels, 0, reason: 'picked');
    expect(_row('Session start'), findsNothing, reason: 'closed');
    await _move(tester, at + const Offset(1, 0)); // still over the rail
    expect(_row('Session start'), findsNothing);

    await _move(tester, const Offset(900, 600));
    await _move(tester, at);
    expect(_row('Session start'), findsOneWidget, reason: 'back over it');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the rail from the keyboard: focus opens its menu at the '
      'current entry, ↑↓ move, Enter picks, Esc closes', (tester) async {
    final (d, _) = await _window(tester, pins: ['a1', 'a2']);
    final inside = find.descendant(
      of: find.byType(PinsRail),
      matching: find.byType(GestureDetector),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    Focus.of(tester.element(inside.first)).requestFocus();
    await tester.pumpAndSettle();
    expect(_row('Session start'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_row('Session start'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // opens it
    await tester.pumpAndSettle();
    expect(_row('Session start'), findsOneWidget);
    expect(_current(tester, 3), 2); // at the bottom: a2
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // a1
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(_row('Session start'), findsNothing);
    expect(_current(tester, 3), 1);
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a title from the agent repaints the open menu', (tester) async {
    final (d, fake) = await _window(tester, pins: ['a1']);
    await _openMenu(tester);
    expect(_row('Relay restart plan'), findsOneWidget);
    final c = fake.chats.single
      ..messagePins.first.title = 'How the relay restarts';
    fake.emit(EventsResponse(chatId: 'c', chat: c));
    await tester.pumpAndSettle();
    expect(_row('How the relay restarts'), findsOneWidget);
    expect(_row('Relay restart plan'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  test('the menu’s dim titles are told from the current one’s, and read, '
      'in every built-in theme', () {
    for (final theme in builtInThemes) {
      for (final t in [theme.dark, theme.light]) {
        final dim = pinTitleDim(t);
        final what = '${theme.id} ${t == theme.dark ? 'dark' : 'light'}';
        // Claude's are about 2.2 from the current one's; themes whose text
        // is dimmer on its fill (Solarized dark) get less, to stay legible.
        expect(contrast(t.text, dim), greaterThan(1.5), reason: what);
        expect(contrast(dim, t.raised), greaterThanOrEqualTo(4), reason: what);
      }
    }
  });

  for (final b in Brightness.values) {
    testWidgets('the rail and its menu, ${b.name}', (tester) async {
      viewport(tester, const Size(420, 260), brightness: b);
      final current = ValueNotifier(2);
      addTearDown(current.dispose);
      final theme = NushiTheme(
        b == Brightness.dark ? Tokens.dark : Tokens.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey(#host),
          debugShowCheckedModeBanner: false,
          theme: theme.toThemeData(),
          home: Scaffold(
            backgroundColor: theme.t.base,
            body: Align(
              alignment: Alignment.topLeft,
              child: PinsRail(
                entries: const [
                  PinEntry.start,
                  PinEntry('a', 'Stripe UI styling'),
                  PinEntry('b', 'Inline code formatting display'),
                  PinEntry(
                    'c',
                    'Theme-card screenshots and the v0.3.0 release notes',
                  ),
                  PinEntry('d', 'v0.3.1 deployment and parallel features'),
                ],
                current: current,
                fit: RailFit.wide,
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/pins_rail_${b.name}.png'),
      );
      await _openMenu(tester);
      await _move(tester, tester.getCenter(_row('Session start')));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/pins_menu_${b.name}.png'),
      );
    }, variant: _mac);
  }

  for (final (width, b) in [
    (1700.0, Brightness.dark),
    (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    (720.0, Brightness.light),
  ]) {
    testWidgets('the window, $width wide, ${b.name}: the rail at the top, '
        'the middle and the bottom, the menu open', (tester) async {
      paneWidths.value = {};
      if (width < 1000) sidebarHidden.value = true;
      final (d, _) = await _window(
        tester,
        pins: ['a1', 'a2', 'a3'],
        width: width,
        brightness: b,
      );
      final name = 'message_pins_${width.toInt()}_${b.name}';
      // The dashes clear of the text, a long one by a gap.
      expect(_gapToWords(tester), greaterThanOrEqualTo(RailFit.gap));
      await render(tester, find.byType(NushiApp), '${name}_bottom');
      await _scrollTo(tester, 0);
      await render(tester, find.byType(NushiApp), '${name}_top');
      await _scrollTo(tester, _scroll(tester).maxScrollExtent / 2);
      await render(tester, find.byType(NushiApp), '${name}_middle');
      await _openMenu(tester);
      expect(tester.takeException(), isNull);
      final menu = tester.getRect(_row('The tests reasoned through'));
      expect(menu.right, lessThan(width));
      await render(tester, find.byType(NushiApp), '${name}_menu');
      await closeView(tester, d);
    }, variant: _mac);
  }

  for (final (size, b) in [
    (const Size(390, 844), Brightness.dark),
    (const Size(390, 844), Brightness.light),
    (const Size(430, 932), Brightness.dark),
    (const Size(844, 390), Brightness.dark),
  ]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}_${b.name}';
    testWidgets('the phone: a tap on the rail takes the older page a pin is '
        'on and opens its menu ($name)', (tester) async {
      viewport(tester, size, ratio: 2, brightness: b);
      final c = _chat(['a1', 'a3', 'a2']);
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
      // Every pin on the rail, though one is on a page not taken yet; no
      // Pin on the phone, which has no actions row.
      expect(_railDashes, findsNWidgets(4));
      expect(find.byTooltip('Pin'), findsNothing);
      expect(_gapToWords(tester), greaterThanOrEqualTo(RailFit.gap));
      await render(tester, find.byType(PhoneApp), 'message_pins_phone_$name');

      await tester.tap(_railDashes.first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(pages, ['u2']);
      expect(_row('Relay restart plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/message_pins_phone_${b.name}.png'),
        );
      } else {
        await render(
          tester,
          find.byType(PhoneApp),
          'message_pins_phone_${name}_menu',
        );
      }

      await tester.tap(_row('Relay restart plan'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final at = tester.getRect(
        find.textContaining('The relay, line 0', findRichText: true).first,
      );
      expect(at.top, greaterThan(0));
      expect(at.bottom, lessThan(size.height));
      await endPhone(tester, phone);
    });
  }
}
