import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Fork chat (the chat's menu, the palette), Fork from here (an agent
// message, on hover) and a side chat's Keep as chat (ADR 0067).

const ItemKind _user = ItemKind.ITEM_KIND_USER_MESSAGE;
const ItemKind _agent = ItemKind.ITEM_KIND_AGENT_MESSAGE;

/// The app on chat c, whose agent [canFork] (and forks at messages):
/// a question, the agent's forkable answer, then one it can't fork at.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  bool canFork = true,
  Size size = const Size(1400, 800),
  Brightness? brightness,
}) async {
  viewport(tester, size, brightness: brightness);
  paneWidths.value = {};
  showDetails.value = false;
  final c = chat('c', 'claude', 'Fix the login redirect');
  final status = ChatStatus(canFork: canFork, canRewind: canFork);
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest(chatId: 'c') => GetChatResponse(
        chat: c,
        status: status,
        items: [
          Item(id: 'u1', kind: _user, text: 'Why keep the query string?'),
          Item(
            id: 'm1',
            kind: _agent,
            text: 'So the page you asked for opens after you sign in.',
            forkable: true,
          ),
          Item(id: 'u2', kind: _user, text: 'Drop it for the logout page.'),
          Item(id: 'item-3', kind: _agent, text: 'Done.'),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  // The list carries no status: the chat's event does.
  fake.emit(EventsResponse(chatId: 'c', seq: Int64(9), status: status));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// The forks asked for, as chat:item.
List<String> _forks(FakeDaemon fake) => [
  for (final f in fake.calls.whereType<ForkAsChatRequest>())
    '${f.chatId}:${f.itemId}',
];

Future<void> _palette(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Palette), matching: find.byType(TextField)),
    'fork',
  );
  await tester.pump();
}

/// The mouse, over [target]; the same one the next time.
Future<void> _hover(WidgetTester tester, Finder target) async {
  var mouse = _mice[tester];
  if (mouse == null) {
    mouse = _mice[tester] = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(() async {
      await _mice.remove(tester)?.removePointer();
    });
  }
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}

final _mice = <WidgetTester, TestGesture>{};

Finder get _forkHere =>
    find.byTooltip('Fork from here: a new chat up to this message');

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('Fork in the chat menu forks all of it and shows the fork', (
    tester,
  ) async {
    final (d, fake) = await _app(tester);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fork'));
    await tester.pumpAndSettle();
    expect(_forks(fake), ['c:']);
    expect(d.selectedId, 'fork');
    expect(find.text('Fix the login redirect (fork)'), findsWidgets);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Fork chat in the palette; not offered when the agent can’t', (
    tester,
  ) async {
    var (d, fake) = await _app(tester);
    await _palette(tester);
    await tester.tap(find.text('Fork chat'));
    await tester.pumpAndSettle();
    expect(_forks(fake), ['c:']);
    await closeView(tester, d);

    (d, fake) = await _app(tester, canFork: false);
    await _palette(tester);
    expect(find.text('Fork chat'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.text('Fork'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Fork from here on a forkable agent message, on hover', (
    tester,
  ) async {
    final (d, fake) = await _app(tester);
    await _hover(tester, find.text('Done.'));
    expect(_forkHere, findsNothing); // no messageId: no fork point
    await _hover(tester, find.textContaining('So the page you asked'));
    // At the right end of the message, whose text stops at the readable
    // width.
    expect(
      tester.getRect(_forkHere).right,
      greaterThan(260 + NushiTheme.gutter + readableWidth - 12),
    );
    await tester.tap(_forkHere);
    await tester.pumpAndSettle();
    expect(_forks(fake), ['c:m1']);
    expect(d.selectedId, 'fork');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('no Fork from here when the agent can’t fork', (tester) async {
    final (d, _) = await _app(tester, canFork: false);
    await _hover(tester, find.textContaining('So the page you asked'));
    expect(_forkHere, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Keep as chat: the side pane closes, the chat stays, a toast '
      'goes to the kept chat', (tester) async {
    final (d, fake) = await _app(tester);
    _side(d);
    await tester.pumpAndSettle();
    // In the header, before its − and ×, at the pane's edge.
    final keep = tester.getRect(find.text('Keep as chat'));
    expect(
      keep.right,
      lessThan(tester.getRect(find.byIcon(Icons.remove)).left),
    );
    expect(
      tester.getRect(find.byIcon(Icons.close)).right,
      greaterThan(1400 - NushiTheme.gutter - 8),
    );
    // Not during its turn.
    fake.emit(_sideStatus(1, busy: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep as chat'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<KeepSideChatRequest>(), isEmpty);
    fake.emit(_sideStatus(2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep as chat'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<KeepSideChatRequest>().single.chatId, 's');
    expect(find.byType(SideChat), findsNothing);
    expect(d.chats['c']!.side.value, isNull);
    expect(fake.calls.whereType<CloseSideChatRequest>(), isEmpty);
    expect(d.selectedId, 'c');
    expect(find.text('The side chat is now a chat in the sidebar'), findsOne);
    await tester.tap(find.text('Go to chat'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'kept');
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    for (final (what, size) in [
      ('wide', const Size(1700, 900)),
      ('narrow', const Size(720, 800)),
    ]) {
      testWidgets('the menu, $what ($name)', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: brightness);
        await tester.tap(find.byTooltip('Chat menu'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/fork_menu_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('the palette, $what ($name)', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: brightness);
        await _palette(tester);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/fork_palette_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('Fork from here, $what ($name)', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: brightness);
        await _hover(tester, find.textContaining('So the page you asked'));
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/fork_here_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('the side chat header, $what ($name)', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: brightness);
        _side(d);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/fork_keep_side_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}

/// Opens a side chat s on chat c, with a question and its answer in it.
ChatState _side(Daemon d) {
  final side = ChatState('s', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  side.items.addAll([
    Item(id: 'su', kind: _user, text: 'Does the logout page need it?'),
    Item(id: 'sm', kind: _agent, text: 'No: it never redirects back.'),
  ]);
  d
    ..sides['s'] = side
    ..chats['c']!.side.value = side;
  return side;
}

/// The side chat's status event [seq]: a turn runs while [busy].
EventsResponse _sideStatus(int seq, {bool busy = false}) => EventsResponse(
  chatId: 's',
  seq: Int64(seq),
  status: ChatStatus(busy: busy, canFork: true),
);
