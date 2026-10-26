import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';

import 'fake_daemon.dart';

/// A subagent that worked in the background, and two messages for it that
/// Claude was asked to pass on: one it did, one it didn't.
final _items = [
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    agentId: 'ab59',
    title: 'Find the redirect',
    status: 'completed',
    subagent: Subagent(state: 'done'),
  ),
  Item(
    id: 'r',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'a',
    title: 'Read auth/redirect.go',
    status: 'completed',
  ),
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Look at auth/session.go too',
    relayTo: 'Explore',
    relayCall: 'a',
    relayState: 'relayed',
    relayedBy: 'sm1',
  ),
  Item(
    id: 'sm1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    title: 'SendMessage',
    tool: 'SendMessage',
    agentId: 'ab59',
    status: 'completed',
  ),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'And the tests',
    relayTo: 'Explore',
    relayCall: 'a',
    relayState: 'failed',
  ),
];

void main() {
  testWidgets('a message for a subagent shows in its pane, with how the '
      'relay went', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1400, 700);
    addTearDown(tester.view.reset);
    showDetails.value = false;
    subagentWide.value = false;
    paneWidths.value = {};
    final c = chat('c', 'claude', 'Fix the login redirect');
    final fake = FakeDaemon([c])
      ..answer = (input) => input is GetChatRequest
          ? GetChatResponse(chat: c, items: _items)
          : null;
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(find.byType(SubagentPane), findsNothing);

    // The message's line in the chat opens the subagent's pane.
    await tester.tap(
      find.textContaining('→ Explore', findRichText: true).first,
    );
    await tester.pumpAndSettle();
    final pane = find.byType(SubagentPane);
    expect(pane, findsOneWidget);
    Finder inPane(String text) => find.descendant(
      of: pane,
      matching: find.textContaining(text, findRichText: true),
    );
    expect(inPane('Look at auth/session.go too'), findsOneWidget);
    expect(inPane('through Claude · passed on'), findsOneWidget);
    expect(inPane('Claude didn’t pass it on'), findsOneWidget);
    // Where it was sent: after the step before it.
    expect(
      tester.getRect(inPane('Read auth/redirect.go')).top,
      lessThan(tester.getRect(inPane('Look at auth/session.go too')).top),
    );
    await tester.pumpWidget(const SizedBox()); // its timers end
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
