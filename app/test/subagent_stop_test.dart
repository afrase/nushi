import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';

import 'fake_daemon.dart';

/// A chat that stopped one background subagent and started another like
/// it, which still runs, beside a background command.
final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Build the ClickHouse time binding in sqrly.',
  ),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'general-purpose',
    title: 'Build ClickHouse time binding in sqrly',
    status: 'completed',
    model: 'sonnet',
    agentId: 'ab89b68fab85fc5e7',
    subagent: Subagent(
      state: 'stopped',
      started: Int64(1793088263304),
      ended: Int64(1793088325304),
      session: 'ab89b68fab85fc5e7',
    ),
  ),
  for (final (id, title) in [
    ('a1', 'Read sqrly/bind.go'),
    ('a2', 'Edit sqrly/bind.go'),
  ])
    Item(
      id: id,
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      parent: 'a',
      title: title,
      status: 'completed',
    ),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Use Opus for it instead.',
  ),
  // Its Stop, asked of Claude (as without a session of its own).
  Item(
    id: 'u3',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    relayTo: 'general-purpose',
    relayCall: 'a',
    relayState: 'relayed',
    relayStop: true,
  ),
  Item(
    id: 'b',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'general-purpose',
    title: 'Build ClickHouse time binding (Opus)',
    status: 'completed',
    model: 'opus',
    agentId: 'aba0c75971268c18b',
    subagent: Subagent(state: 'running', session: 'aba0c75971268c18b'),
  ),
  Item(
    id: 'b1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'b',
    title: 'Read sqrly/bind.go',
    status: 'completed',
  ),
  Item(
    id: 'b2',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'b',
    title: 'go test ./sqrly/...',
    toolKind: 'execute',
    status: 'in_progress',
  ),
  Item(
    id: 's',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    tool: 'Bash',
    title: 'make watch',
    toolKind: 'execute',
    status: 'completed',
    shell: Shell(id: 'bgu2i75cc', state: 'running', output: 'watching…\n'),
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Stopped the Sonnet one; the Opus one is building it now.',
  ),
];

/// The app at [width] on that chat, the details panel shown, and the fake
/// daemon that gets its calls.
Future<(Daemon, FakeDaemon)> _app(WidgetTester tester, double width) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 640);
  addTearDown(tester.view.reset);
  showDetails.value = true;
  paneWidths.value = {};
  subagentWide.value = false;
  // The turn ended; the running subagent and make watch go on (API 84).
  final running = ChatStatus(background: 2);
  final c = chat('c', 'claude', 'ClickHouse time binding', status: running);
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: _items, status: running)
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  // Spinners never settle: pump a while instead.
  await tester.pump(const Duration(milliseconds: 500));
  return (d, fake);
}

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A mouse over [finder]'s middle.
Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(finder));
  addTearDown(mouse.removePointer);
  await _pump(tester);
  return mouse;
}

Finder _line(String id) =>
    find.byWidgetPredicate((w) => w is SubagentLine && w.s.call.id == id);

Finder get _stops =>
    find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Stop');

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('a stopped subagent says so everywhere; a running one stops '
      'from its row, its pane and the card', (tester) async {
    final (d, fake) = await _app(tester, 1700);
    // The stopped one: its row and the card say "stopped", time frozen.
    expect(
      find.textContaining('stopped · 2 tool calls · 1m 02s'),
      findsWidgets,
    );
    expect(find.textContaining('Running go test'), findsWidgets);
    expect(_stops, findsNothing); // until under the pointer

    // The running one's row: under the pointer, its mark is its Stop.
    final mouse = await _hover(tester, _line('b'));
    expect(_stops, findsOneWidget);
    await tester.tap(_stops);
    await _pump(tester);
    expect(fake.calls.whereType<StopTaskRequest>().map((r) => r.callId), ['b']);
    await mouse.moveTo(tester.getCenter(_line('a')));
    await _pump(tester);
    expect(_stops, findsNothing); // the stopped one has none

    // Its pane has Stop beside Wider and Close; the stopped one's none.
    await tester.tap(_line('b'));
    await _pump(tester);
    final pane = find.byType(SubagentPane);
    expect(find.descendant(of: pane, matching: _stops), findsOneWidget);
    await tester.tap(_line('a'));
    await _pump(tester);
    expect(find.descendant(of: pane, matching: _stops), findsNothing);
    expect(
      find.descendant(of: pane, matching: find.textContaining('stopped')),
      findsWidgets,
    );

    // The card's rows: the subagent's and the command's, under the pointer.
    final card = find.byType(DetailsPanel);
    for (final row in [
      'Build ClickHouse time binding (Opus)',
      r'$ make watch',
    ]) {
      await mouse.moveTo(
        tester.getCenter(
          find.descendant(of: card, matching: find.textContaining(row)),
        ),
      );
      await _pump(tester);
      expect(find.descendant(of: card, matching: _stops), findsOneWidget);
      await tester.tap(find.descendant(of: card, matching: _stops));
      await _pump(tester);
    }
    expect(fake.calls.whereType<StopTaskRequest>().map((r) => r.callId), [
      'b',
      'b',
      's',
    ]);
    d.dispose();
  }, variant: _mac);

  for (final (name, mode) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      testWidgets('stopped beside running, $size ($name)', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = mode;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final (d, _) = await _app(tester, width);
        // Wide: the stopped one's pane, the card's finished ones open and
        // its running subagent under the pointer (the row's Stop is in the
        // test above); narrow: the running one's pane, with its Stop.
        await tester.tap(_line(size == 'wide' ? 'a' : 'b'));
        await _pump(tester);
        if (size == 'wide') {
          await tester.tap(find.text('1 finished'));
          await _pump(tester);
          await _hover(
            tester,
            find.descendant(
              of: find.byType(DetailsPanel),
              matching: find.textContaining('(Opus)'),
            ),
          );
        }
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/subagent_stop_${size}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
