import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';

import 'fake_daemon.dart';
import 'harness.dart';

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
    toSubagentName: 'Explore',
    toSubagent: 'a',
    toSubagentState: 'relayed',
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
    toSubagentName: 'Explore',
    toSubagent: 'a',
    toSubagentState: 'failed',
  ),
];

void main() {
  // The real fonts: the header beside a pane is sized for them.
  setUpAll(loadFonts);

  testWidgets('a message for a subagent shows in its pane, with how the '
      'agent passed it on', (tester) async {
    showDetails.value = false;
    final c = chat('c', 'claude', 'Fix the login redirect');
    final fake = FakeDaemon([c])..chatItems['c'] = _items;
    final d = await openApp(tester, fake, size: const Size(1400, 700));
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
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('what is typed while a message to a subagent sends stays, '
      'and a failed one comes back before it', (tester) async {
    showDetails.value = false;
    final c = chat('c', 'claude', 'Fix the login redirect');
    var sent = Completer<SendPromptResponse>();
    final fake = FakeDaemon([c])
      ..chatItems['c'] = _items
      ..answer = (input) => switch (input) {
        SendPromptRequest() => sent.future,
        _ => null,
      };
    final d = await openApp(tester, fake, size: const Size(1400, 700));
    await tester.tap(
      find.textContaining('→ Explore', findRichText: true).first,
    );
    await tester.pumpAndSettle();
    final box = find.descendant(
      of: find.byType(SubagentPane),
      matching: find.byType(TextField),
    );
    String typed() => tester.widget<TextField>(box).controller!.text;

    Future<void> sendThenType(String first, String then) async {
      await tester.enterText(box, first);
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.enterText(box, then);
      await tester.pump();
    }

    await sendThenType('Look at the tests too', 'and the docs');
    sent.complete(SendPromptResponse());
    await tester.pumpAndSettle();
    expect(typed(), 'and the docs');

    sent = Completer();
    await sendThenType('Look at the tests too', 'and the docs');
    sent.completeError(Exception('the agent stopped'));
    await tester.pumpAndSettle();
    expect(typed(), 'Look at the tests too\n\nand the docs');
    await closeView(tester, d);
  }, variant: onMac);
}
