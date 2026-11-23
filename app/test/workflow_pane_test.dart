import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/task_pane.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/workflow_pane.dart';
import 'package:nushi/workflows.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'workflow_card_test.dart' show workflowCall;

/// The agents GetWorkflow answers for [workflowCall]'s run.
final List<WorkflowAgent> agents = [
  WorkflowAgent(
    id: 'a1',
    label: 'map:files',
    phase: 'Map',
    state: 'done',
    started: msAgo(const Duration(minutes: 4)),
    ended: msAgo(const Duration(minutes: 3, seconds: 20)),
    tokens: 12400,
  ),
  WorkflowAgent(
    id: 'a2',
    label: 'map:tests',
    phase: 'Map',
    state: 'done',
    started: msAgo(const Duration(minutes: 4)),
    ended: msAgo(const Duration(minutes: 3)),
    tokens: 8100,
  ),
  for (final (i, label) in [
    'review:security',
    'review:ui',
    'review:perf',
    'review:api',
  ].indexed)
    WorkflowAgent(
      id: 'r$i',
      label: label,
      phase: 'Review',
      state: i == 0 ? 'failed' : 'running',
      started: msAgo(Duration(minutes: 2, seconds: i * 10)),
      ended: i == 0 ? msAgo(const Duration(minutes: 1)) : null,
      tokens: 5000 + i * 900,
      model: 'claude-opus-5-5',
      prompt:
          'Review the diff for $label problems. Report each with its '
          'file and line.',
    ),
  for (final (i, label) in [
    'review:docs',
    'review:errors',
    'review:tests',
  ].indexed)
    WorkflowAgent(
      id: 'd$i',
      label: label,
      phase: 'Review',
      state: 'done',
      started: msAgo(const Duration(minutes: 3)),
      ended: msAgo(const Duration(minutes: 2)),
      tokens: 7000,
    ),
  WorkflowAgent(id: 'x', label: 'hotfix', state: 'done'),
];

final steps = [
  Item(
    id: 'wf/r1/0-0',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Looking at the changed views first.',
  ),
  Item(
    id: 'wf/r1/call-1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    tool: 'Read',
    title: 'Read app/lib/chat_view.dart',
    toolKind: 'read',
    status: 'completed',
  ),
  Item(
    id: 'wf/r1/call-2',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    tool: 'Grep',
    title: 'Grep SidePane',
    toolKind: 'search',
    status: 'in_progress',
  ),
];

/// A Claude chat with a workflow's call, loaded.
ChatState workflowChat({String state = 'running'}) => ChatState('c', '/x')
  ..agent = 'claude'
  ..loaded = true
  ..items.add(workflowCall(state));

/// A fake that answers the workflow's calls; [gone], refusing the run as
/// one whose files are gone.
FakeDaemon workflowFake({bool gone = false}) =>
    FakeDaemon([chat('c', 'claude', 'Review')])
      ..answer = (input) => switch (input) {
        GetWorkflowRequest() when gone => throw ConnectException(
          Code.notFound,
          'no such workflow',
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

Future<Daemon> _pane(
  WidgetTester tester,
  FakeDaemon fake,
  ChatState chat, {
  Tokens tokens = Tokens.dark,
  double width = 420,
}) async {
  viewport(tester, Size(width, 720));
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(
      WorkflowPane(chat: chat, daemon: d, id: 'wf', onClose: () {}),
      tokens: tokens,
    ),
  );
  await tester.pump();
  await tester.pump();
  return d;
}

int _asked<T>(FakeDaemon fake) => fake.calls.whereType<T>().length;

/// The app at 1700 on [workflowChat]'s chat, its pane open, with the
/// pane widths [widths].
Future<(FakeDaemon, Daemon)> _app(
  WidgetTester tester, {
  Map<String, double> widths = const {},
}) async {
  showDetails.value = false;
  paneWidths.value = widths;
  final fake = workflowFake()
    ..on(
      (input) => input is GetChatRequest
          ? GetChatResponse(
              chat: chat('c', 'claude', 'Review'),
              items: [
                Item(
                  id: 'u',
                  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                  text: 'Go',
                ),
                workflowCall('running'),
              ],
            )
          : null,
    );
  final d = await openApp(tester, fake);
  d.chats['c']!.pane.value = 'wf';
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);
  setUp(() => Shine.stopAt = 0.3);
  tearDown(() => Shine.stopAt = null);

  testWidgets('the pane slot shows a workflow, command or subagent by its '
      'call', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = workflowChat()
      ..items.addAll([
        Item(
          id: 'cmd',
          kind: ItemKind.ITEM_KIND_TOOL_CALL,
          backgroundCommand: BackgroundCommand(id: 'b1', state: 'running'),
        ),
        Item(id: 'sub', kind: ItemKind.ITEM_KIND_TOOL_CALL, agent: 'Explore'),
      ]);
    Widget pane(String id) =>
        taskPane(chat: chat, daemon: d, id: id, onClose: () {});
    expect(pane('wf'), isA<WorkflowPane>());
    expect(pane('cmd'), isA<BackgroundCommandPane>());
    expect(pane('sub'), isA<SubagentPane>());
    expect(workflowPaneOpen(chat, 'wf'), isTrue);
    expect(workflowPaneOpen(chat, 'sub'), isFalse);
    // Its call gone, the last pane shown stays the kind it was.
    expect(pane('cmd'), isA<BackgroundCommandPane>());
    chat.items.removeWhere((it) => it.id == 'cmd');
    expect(pane('cmd'), isA<BackgroundCommandPane>());
    expect(pane('nope'), isA<SubagentPane>());
    await closeView(tester, d);
  });

  testWidgets('its phases, each with its agents; no phase last', (
    tester,
  ) async {
    final fake = workflowFake();
    final d = await _pane(tester, fake, workflowChat());
    expect(find.text('Map'), findsOne);
    expect(find.text(' 4/7'), findsOne);
    expect(find.text('No phase'), findsOne);
    expect(find.text('review:security'), findsOne);
    expect(
      tester.getRect(find.text('No phase')).top,
      greaterThan(tester.getRect(find.text('review:tests')).top),
    );
    // What it plans and hasn't reached comes last, said in words, with
    // nothing to fold (ADR 0141).
    expect(find.text(' · planned'), findsOne);
    expect(
      tester.getRect(find.text('Verify')).top,
      greaterThan(tester.getRect(find.text('No phase')).top),
    );
    // A phase folds its agents.
    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(find.text('map:files'), findsNothing);
    expect(_asked<GetWorkflowRequest>(fake), 1);
    await closeView(tester, d);
  });

  testWidgets('a long phase title is cut, never its count', (tester) async {
    final long = 'Review-${'everything-' * 8}';
    final chat = workflowChat();
    chat.items.single.workflow.phases[1].title = long;
    final fake = workflowFake()
      ..answer = (input) => switch (input) {
        GetWorkflowRequest() => GetWorkflowResponse(
          workflow: chat.items.single.workflow,
          agents: [
            for (final a in agents)
              a.deepCopy()..phase = a.phase == 'Review' ? long : a.phase,
          ],
        ),
        _ => null,
      };
    final d = await _pane(tester, fake, chat, width: 280);
    final pane = tester.getRect(find.byType(WorkflowPane));
    expect(
      tester.getRect(find.text(' 4/7')).right,
      lessThanOrEqualTo(pane.right),
    );
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  });

  testWidgets('a stopped run counts its phases as its card does: an agent '
      'stopped with it is not one that ended', (tester) async {
    final stopped = [
      for (final a in agents)
        a.deepCopy()..state = a.state == 'running' ? 'stopped' : a.state,
    ];
    final chat = workflowChat(state: 'stopped');
    chat.items.single.workflow
      ..phases.clear()
      ..phases.addAll([
        WorkflowPhase(title: 'Map', started: 2, done: 2),
        WorkflowPhase(title: 'Review', started: 7, done: 3, failed: 1),
      ]);
    final fake = workflowFake()
      ..answer = (input) => switch (input) {
        GetWorkflowRequest() => GetWorkflowResponse(
          workflow: chat.items.single.workflow,
          agents: stopped,
        ),
        _ => null,
      };
    final d = await _pane(tester, fake, chat);
    expect(find.text(' 4/7'), findsOne);
    expect(phaseProgress(chat.items.single.workflow.phases[1]), 'Review 4/7');
    await closeView(tester, d);
  });

  testWidgets('its agents are read again half a second after the run '
      'changes, once for changes close together', (tester) async {
    final fake = workflowFake();
    final chat = workflowChat();
    final d = await _pane(tester, fake, chat);
    expect(_asked<GetWorkflowRequest>(fake), 1);
    void change(int done) => chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(done),
        item: ItemEvent(item: workflowCall('running')..workflow.done = done),
      ),
    );
    change(6);
    await tester.pump(
      const Duration(milliseconds: 300),
    ); // design: a test's step
    change(7);
    await tester.pump(
      const Duration(milliseconds: 499),
    ); // design: a test's step
    expect(_asked<GetWorkflowRequest>(fake), 1);
    await tester.pump(const Duration(milliseconds: 1)); // design: a test's step
    await tester.pump();
    expect(_asked<GetWorkflowRequest>(fake), 2);
    await closeView(tester, d);
  });

  testWidgets('an agent shows its steps, read again while it runs, and '
      '"All agents" goes back', (tester) async {
    final fake = workflowFake();
    final d = await _pane(tester, fake, workflowChat());
    await tester.tap(find.text('review:ui'));
    await tester.pump();
    await tester.pump();
    final asked = fake.calls.whereType<GetWorkflowAgentRequest>().single;
    expect((asked.chatId, asked.callId, asked.agentId), ('c', 'wf', 'r1'));
    expect(find.text('Looking at the changed views first.'), findsOne);
    expect(find.textContaining('Review the diff for review:ui'), findsOne);
    final back = tester.getRect(find.byTooltip('All agents'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(_asked<GetWorkflowAgentRequest>(fake), 2);
    expect(tester.getRect(find.byTooltip('All agents')), back);
    await tester.tap(find.byTooltip('All agents'));
    await tester.pump();
    expect(find.text(' 4/7'), findsOne);
    await tester.pump(const Duration(seconds: 6));
    expect(_asked<GetWorkflowAgentRequest>(fake), 2);
    await closeView(tester, d);
  });

  testWidgets('a run whose files are gone says so', (tester) async {
    final gone = workflowFake(gone: true);
    final d = await _pane(tester, gone, workflowChat());
    expect(find.text('Claude no longer has this run’s files.'), findsOne);
    await closeView(tester, d);
  });

  testWidgets("the pane has its own width, apart from a subagent's", (
    tester,
  ) async {
    var (_, d) = await _app(tester);
    double width() => tester.getSize(find.byType(WorkflowPane)).width;
    expect(width(), closeTo(420, 1));
    d.dispose();
    (_, d) = await _app(tester, widths: {'subagent': 300});
    expect(width(), closeTo(420, 1));
    d.dispose();
    (_, d) = await _app(tester, widths: {'workflow': 500});
    expect(width(), closeTo(500, 1));
    paneWidths.value = {};
    showDetails.value = true;
    d.dispose();
  }, variant: onMac);

  testWidgets('the run ending leaves the pane with its last tree; its call '
      'going leaves the pane a workflow’s, saying so', (tester) async {
    final (fake, d) = await _app(tester);
    expect(find.text(' 4/7'), findsOne);
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(item: workflowCall('done'), index: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowPane), findsOne);
    expect(find.text(' 7/7'), findsOne);
    expect(find.byTooltip('Stop'), findsNothing);
    final width = tester.getSize(find.byType(WorkflowPane)).width;
    // A rewind past the call: the pane stays a workflow's, as wide.
    fake.emit(EventsResponse(chatId: 'c', seq: Int64(2), cut: 'wf'));
    await tester.pumpAndSettle();
    expect(find.byType(SubagentPane), findsNothing);
    expect(find.byType(WorkflowPane), findsOne);
    expect(find.text('This workflow is no longer in the chat.'), findsOne);
    expect(tester.getSize(find.byType(WorkflowPane)).width, width);
    // And once the panes are laid out again (anything beside them
    // changing; here the side chat's hidden flag).
    final c = d.chats['c']!;
    c.sideHidden.value = !c.sideHidden.value;
    await tester.pumpAndSettle();
    expect(find.byType(SubagentPane), findsNothing);
    expect(find.text('This workflow is no longer in the chat.'), findsOne);
    expect(tester.getSize(find.byType(WorkflowPane)).width, width);
    c.sideHidden.value = !c.sideHidden.value;
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(WorkflowPane),
        matching: find.byTooltip('Close'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowPane), findsNothing);
    expect(d.chats['c']!.pane.value, isNull);
    paneWidths.value = {};
    showDetails.value = true;
    d.dispose();
  }, variant: onMac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a workflow pane ($name)', (tester) async {
      final d = await _pane(
        tester,
        workflowFake(),
        workflowChat(),
        tokens: tokens,
      );
      await expectLater(
        find.byType(WorkflowPane),
        matchesGoldenFile('goldens/workflow_pane_tree_$name.png'),
      );
      await tester.tap(find.text('review:ui'));
      await tester.pump();
      await tester.pump();
      await expectLater(
        find.byType(WorkflowPane),
        matchesGoldenFile('goldens/workflow_pane_agent_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
