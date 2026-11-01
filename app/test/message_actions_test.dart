import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final _user = Item(
  id: 'u',
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: 'Run the suite',
  sent: Int64(fixtureNow.millisecondsSinceEpoch - 75 * 60 * 1000),
);

final _agent = Item(
  id: 'a',
  kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
  text: 'It **passes**.',
  sent: Int64(fixtureNow.millisecondsSinceEpoch - 60 * 1000),
);

/// [item] of a chat with [items], hovered, and what's copied.
Future<(Daemon, List<String>)> _hovered(
  WidgetTester tester,
  Item item,
  List<Item> items, {
  VoidCallback? onRewind,
  VoidCallback? onFork,
  bool hover = true,
}) async {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  final d = await FakeDaemon([]).connect(tester);
  final chat = ChatState('c', '/x')
    ..agent = 'claude'
    ..loaded = true
    ..items.addAll(items);
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: ItemView(
            item,
            chat,
            d,
            live: false,
            still: false,
            onRewind: onRewind,
            onFork: onFork,
          ),
        ),
      ),
    ),
  );
  if (hover) {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(ItemView)));
    await tester.pumpAndSettle();
  }
  return (d, copied);
}

void main() {
  test('a date and time as the tooltip says it', () {
    expect(fullTime(DateTime(2026, 11, 1, 8, 45)), 'Nov 1, 2026, 8:45 AM');
    expect(fullTime(DateTime(2026, 1, 9, 12, 5)), 'Jan 9, 2026, 12:05 PM');
    expect(fullTime(DateTime(2026, 1, 9)), 'Jan 9, 2026, 12:00 AM');
  });

  testWidgets('a user message: sent, then read, its time, Copy and Rewind', (
    tester,
  ) async {
    var rewound = 0;
    final (d, copied) = await _hovered(tester, _user, [
      _user,
    ], onRewind: () => rewound++);
    expect(find.byTooltip('Sent'), findsOneWidget);
    expect(find.text('1h ago'), findsOneWidget);
    expect(
      find.byTooltip(
        fullTime(DateTime.fromMillisecondsSinceEpoch(_user.sent.toInt())),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Copy as Markdown'));
    await tester.pump();
    expect(copied, ['Run the suite']);
    await tester.tap(find.byTooltip('Rewind to here (Esc Esc)'));
    expect(rewound, 1);
    d.dispose();
  }, variant: _mac);

  testWidgets('read once something of the agent’s follows', (tester) async {
    final (d, _) = await _hovered(tester, _user, [_user, _agent]);
    expect(find.byTooltip('Read by Claude'), findsOneWidget);
    expect(find.byTooltip('Sent'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('a subagent’s step isn’t the agent reading it', (tester) async {
    final step = Item(
      id: 's',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'Inside',
      parent: 'call',
    );
    final (d, _) = await _hovered(tester, _user, [_user, step]);
    expect(find.byTooltip('Sent'), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('an agent’s message copies its Markdown; no time when unknown', (
    tester,
  ) async {
    final replayed = _agent.deepCopy()..clearSent();
    final (d, copied) = await _hovered(tester, replayed, [replayed]);
    expect(find.textContaining('ago'), findsNothing);
    await tester.tap(find.byTooltip('Copy as Markdown'));
    await tester.pump();
    expect(copied, ['It **passes**.']);
    d.dispose();
  }, variant: _mac);

  testWidgets('nothing moves as the pointer comes', (tester) async {
    final (still, _) = await _hovered(tester, _user, [_user], hover: false);
    final height = tester.getSize(find.byType(ItemView)).height;
    expect(find.byTooltip('Copy as Markdown'), findsNothing);
    still.dispose();
    await tester.pumpWidget(const SizedBox());
    final (d, _) = await _hovered(tester, _user, [_user]);
    expect(find.byTooltip('Copy as Markdown'), findsOneWidget);
    expect(tester.getSize(find.byType(ItemView)).height, height);
    d.dispose();
  }, variant: _mac);
}
