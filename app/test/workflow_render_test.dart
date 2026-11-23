// Renders of a chat running Claude's workflows (ADR 0127): the window wide
// and narrow, dark and light, with a card in each state, the Workflow pane
// open, then an agent's steps, the sidebar and status bar showing it
// working; and the phone (`make renders TEST=test/workflow_render_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/workflow_card.dart';
import 'package:nushi/workflow_pane.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'workflow_card_test.dart' show workflowCall;
import 'workflow_pane_test.dart' show agents, steps;

final Chat _chat = chat(
  'c',
  'claude',
  'Review the right-panes branch',
  status: ChatStatus(background: 1, workflows: 1),
);

final List<Item> _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Review the branch from every angle, then fix what holds up.',
  ),
  workflowCall('done', id: 'w1')..workflow.name = 'map-the-code',
  workflowCall('failed', id: 'w2')..workflow.name = 'design-panel',
  workflowCall('stopped', id: 'w3')..workflow.name = 'try-a-fix',
  workflowCall('unknown', id: 'w4')..workflow.name = 'paused-run',
  workflowCall('running', stalled: true, id: 'w5')..workflow.name = 'quiet-run',
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The review runs in the background; I’ll report when it ends.',
  ),
  workflowCall('running'),
];

FakeDaemon _fake() =>
    FakeDaemon([
        _chat,
        chat('b', 'claude', 'Fix the login redirect', status: ChatStatus()),
        chat('d', 'codex', 'Sort the imports')..done = true,
      ])
      ..answer = (input) => switch (input) {
        GetChatRequest() => GetChatResponse(
          chat: _chat,
          items: _items,
          status: _chat.status,
        ),
        GetWorkflowRequest() => GetWorkflowResponse(
          workflow: workflowCall('running').workflow,
          agents: agents,
        ),
        GetWorkflowAgentRequest() => GetWorkflowAgentResponse(
          items: steps,
          agent: agents[3],
        ),
        _ => null,
      };

/// Lets the window settle without waiting for what loops (the working
/// dot, the shine) to stop.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // design: a test's step
  }
}

void main() {
  setUpAll(loadFonts);
  setUp(() => Shine.stopAt = 0.3);
  tearDown(() => Shine.stopAt = null);

  for (final width in [1700.0, 720.0]) {
    for (final dark in [true, if (rendering) false]) {
      final name = '${width.round()}_${dark ? 'dark' : 'light'}';
      testWidgets('the window at $name: the cards, the pane, an agent', (
        tester,
      ) async {
        viewport(
          tester,
          Size(width, 1000),
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        sidebarHidden.value = width < 1000;
        showDetails.value = false;
        final d = await _fake().connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await _settle(tester);
        expect(find.byType(WorkflowCard), findsNWidgets(6));
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'workflow_cards_$name');

        await tester.tap(find.byTooltip('Open its agents').last);
        await _settle(tester);
        expect(find.byType(WorkflowPane), findsOne);
        expectTextInside(tester, width);
        final pane = tester.getRect(find.byType(WorkflowPane));
        final close = tester.getRect(
          find.descendant(
            of: find.byType(WorkflowPane),
            matching: find.byTooltip('Close'),
          ),
        );
        expect(close.right, greaterThan(pane.right - 28));
        await render(tester, find.byType(NushiApp), 'workflow_pane_$name');

        await tester.tap(find.text('review:ui'));
        await _settle(tester);
        expect(find.text('Looking at the changed views first.'), findsOne);
        await render(tester, find.byType(NushiApp), 'workflow_agent_$name');

        if (width > 1000) {
          sidebarHidden.value = false;
          showDetails.value = true;
          await _settle(tester);
          await render(tester, find.byType(NushiApp), 'workflow_details_$name');
        }
        sidebarHidden.value = false;
        showDetails.value = true;
        await closeView(tester, d);
      }, variant: onMac);
    }
  }

  for (final size in [
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
  ]) {
    final name = '${size.width.round()}x${size.height.round()}';
    testWidgets('the phone at $name: the list, the card, the sheet', (
      tester,
    ) async {
      viewport(tester, size, ratio: 3);
      final platform = PhonePlatform()..saved = pairedRecord();
      final fake = _fake();
      final phone = await startPhone(tester, fake, platform: platform);
      await _settle(tester);
      await render(tester, find.byType(PhoneApp), 'workflow_phone_list_$name');
      await tester.tap(find.text('Review the right-panes branch'));
      await _settle(tester);
      expectTextInside(tester, size.width);
      await render(tester, find.byType(PhoneApp), 'workflow_phone_chat_$name');
      // No pane to open: each card's one chevron opens it in place.
      for (final card in find.byType(WorkflowCard).evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(card.widget),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOne,
        );
      }
      await tester.tap(find.byIcon(Icons.more_horiz));
      await _settle(tester);
      await render(tester, find.byType(PhoneApp), 'workflow_phone_sheet_$name');
      expect(fake.calls.whereType<GetWorkflowRequest>(), isEmpty);
      await endPhone(tester, phone);
    });
  }
}
