import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript_entries.dart';
import 'package:nushi/workflow_card.dart';
import 'package:nushi/workflow_phases.dart';
import 'package:nushi/workflows.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A workflow's call, its run in [state].
Item workflowCall(String state, {bool stalled = false, String id = 'wf'}) {
  final ended = state != 'running' && state.isNotEmpty;
  return Item(
    id: id,
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    tool: 'Workflow',
    title: 'Workflow',
    status: 'completed',
    text: 'Workflow launched in background. Task ID: w1',
    workflow: Workflow(
      runId: 'wf_769a004c-2aa',
      name: 'review-changes',
      description: 'Review the diff from five angles, then verify',
      state: state,
      end: switch (state) {
        'done' => 'completed',
        'stopped' => 'killed',
        'failed' => 'failed',
        'unknown' => 'paused',
        _ => '',
      },
      summary: state == 'failed' ? 'Error: the script threw' : '',
      started: msAgo(const Duration(minutes: 4, seconds: 12)),
      ended: ended ? msAgo(Duration.zero) : null,
      active: stalled ? msAgo(const Duration(hours: 1, minutes: 5)) : null,
      stalled: stalled,
      // While it runs, as workflow_pane_test's agents are: the pane's
      // tree and the card count alike.
      agents: ended ? 12 : 10,
      done: ended ? 12 : 6,
      failed: ended ? 0 : 1,
      phases: [
        WorkflowPhase(title: 'Map', started: 2, done: 2),
        WorkflowPhase(
          title: 'Review',
          started: 7,
          done: ended ? 7 : 3,
          failed: ended ? 0 : 1,
        ),
        if (ended) WorkflowPhase(title: 'Verify', started: 3, done: 3),
      ],
      // What its script plans and it hasn't reached yet (ADR 0141).
      planned: ended ? null : [WorkflowPhase(title: 'Verify')],
      running: ended ? null : ['review:ui', 'review:perf', 'review:api'],
      runningPhases: ended ? null : [1, 1, 1],
      runningCount: ended ? 0 : 3,
      tokens: Int64(ended ? 96500 : 61200),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Item call, {
  Tokens tokens = Tokens.dark,
  double width = 640,
  double height = 140,
}) async {
  viewport(tester, Size(width, height));
  await tester.pumpWidget(
    themed(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: WorkflowCard(call, ChatState('c', '/x'), still: true),
        ),
      ),
      tokens: tokens,
    ),
  );
}

void main() {
  setUpAll(loadFonts);
  setUp(() => Shine.stopAt = 0.3);
  tearDown(() => Shine.stopAt = null);

  test('each state in words', () {
    expect(
      workflowState(workflowCall('running').workflow),
      'Review 4/7, 3 running, 61.2k tokens, 4m 12s',
    );
    expect(
      workflowState(workflowCall('done').workflow),
      '12 agents, 96.5k tokens, 4m 12s', // its check says done
    );
    expect(
      workflowState(workflowCall('failed').workflow),
      startsWith('failed'),
    );
    expect(
      workflowState(workflowCall('stopped').workflow),
      startsWith('stopped'),
    );
    expect(
      workflowState(workflowCall('unknown').workflow),
      startsWith('ended'),
    );
    expect(
      workflowState(workflowCall('running', stalled: true).workflow),
      'no activity for 1h, Review 4/7, 3 running, 61.2k tokens',
    );
    expect(
      workflowState(Workflow(state: 'running', started: msAgo(Duration.zero))),
      'starting, 0s',
    );
    // A short line's choices: its count, then its tokens, give way.
    expect(workflowStates(workflowCall('running').workflow), [
      'Review 4/7, 3 running, 61.2k tokens, 4m 12s',
      'Review 4/7, 61.2k tokens, 4m 12s',
      'Review 4/7, 4m 12s',
    ]);
    expect(
      workflowEndWords(workflowCall('unknown').workflow, 'Claude'),
      'paused',
    );
    expect(
      workflowEndWords(workflowCall('failed').workflow, 'Claude'),
      'Error: the script threw',
    );
    // Without its word, the agent named is the chat's.
    expect(
      workflowEndWords(Workflow(state: 'unknown'), 'Kimi'),
      "Kimi didn't say how it ended",
    );
  });

  testWidgets('a followed run is a card; one not followed a plain call', (
    tester,
  ) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/x');
    final plain = workflowCall('')..clearWorkflow();
    final notYet = workflowCall('');
    for (final (it, card) in [
      (workflowCall('running'), true),
      (plain, false),
      (notYet, false),
    ]) {
      await tester.pumpWidget(
        themed(ItemView(it, chat, d, live: false, still: true)),
      );
      expect(find.byType(WorkflowCard), card ? findsOneWidget : findsNothing);
      expect(find.byType(ToolCallView), card ? findsNothing : findsOneWidget);
    }
    // A card joins no run of tool calls.
    final entries = transcriptEntries([
      Item(id: 'a', kind: ItemKind.ITEM_KIND_TOOL_CALL, title: 'Read'),
      workflowCall('running'),
      Item(id: 'b', kind: ItemKind.ITEM_KIND_TOOL_CALL, title: 'Read'),
    ]);
    expect(entries.length, 3);
    await closeView(tester, d);
  });

  testWidgets('its state, mark and chevron end the line; long text is cut', (
    tester,
  ) async {
    final call = workflowCall('running');
    call.workflow
      ..name = 'review-${'very-long-name-' * 6}'
      ..description = '長い説明 ' * 30
      ..running.add('🙂' * 40);
    await _pump(tester, call, width: 392);
    expectTextInside(tester, 392);
    final card = tester.getRect(find.byType(WorkflowCard));
    // The pane's button at its end; the chevron that opens it in place
    // at its start.
    final chevron = tester.getRect(find.byIcon(paneIcon));
    expect(chevron.right, greaterThan(card.right - 20));
    final fold = tester.getRect(find.byTooltip('Show its phases'));
    expect(fold.left, lessThan(card.left + 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it says each thing once: its phase only in its state', (
    tester,
  ) async {
    await _pump(tester, workflowCall('running'));
    expect(find.textContaining('Review 4/7'), findsOne);
    expect(find.textContaining('Map 2/2'), findsNothing);
    expect(find.textContaining('review:ui'), findsNothing);
    expect(find.textContaining('five angles'), findsNothing);
    // One line, as a subagent's row.
    expect(tester.getSize(find.byType(WorkflowCard)).height, 36);
  });

  test('opened, each phase with its mark, progress and who runs', () {
    final rows = workflowPhaseRows(workflowCall('running').workflow);
    expect(
      [for (final r in rows) (r.title, r.progress, r.state)],
      [
        ('Map', '2/2', 'done'),
        ('Review', '4/7', 'running'),
        ('Verify', 'planned', 'planned'),
      ],
    );
    expect(rows[1].running, ['review:ui', 'review:perf', 'review:api']);
    expect(rows[1].more, 0);
    // Ended, a phase still going stopped with it; none says who runs.
    final stopped = workflowCall('stopped').workflow
      ..phases.add(WorkflowPhase(title: 'Fix', started: 2, done: 1));
    expect(workflowPhaseRows(stopped).last.state, 'stopped');
    // One its list has and it never reached isn't done (ADR 0141), nor
    // where it is.
    final unreached = workflowCall('stopped').workflow
      ..phases.add(WorkflowPhase(title: 'Ship'))
      ..planned.add(WorkflowPhase(title: 'Tidy'));
    expect(
      [
        for (final r in workflowPhaseRows(unreached).skip(3))
          (r.title, r.progress, r.state),
      ],
      [('Ship', 'not reached', 'planned'), ('Tidy', 'not reached', 'planned')],
    );
    final going = Workflow(
      state: 'running',
      phases: [
        WorkflowPhase(title: 'Map', started: 2, done: 2),
        WorkflowPhase(title: 'Ship'),
      ],
    );
    expect(currentPhase(going)?.title, 'Map');
    // More run than the summary names; some in no phase.
    final many = Workflow(
      state: 'running',
      phases: [WorkflowPhase(title: 'Check', started: 9, done: 2, failed: 1)],
      running: ['check:a', 'check:b', 'loose'],
      runningPhases: [0, 0, -1],
      runningCount: 8,
    );
    final got = workflowPhaseRows(many);
    expect(
      [for (final r in got) (r.title, r.state, r.running.join(', '), r.more)],
      [
        ('Check', 'running', 'check:a, check:b', 4),
        ('', 'running', 'loose', 1),
      ],
    );
  });

  testWidgets('its chevron opens it in place and stays put; a click '
      'elsewhere opens its pane', (tester) async {
    final chat = ChatState('c', '/x');
    viewport(tester, const Size(640, 240));
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topCenter,
          child: WorkflowCard(workflowCall('running'), chat, still: true),
        ),
      ),
    );
    final chevron = find.byTooltip('Show its phases');
    final at = tester.getRect(chevron);
    expect(
      find.text('Review the diff from five angles, then verify'),
      findsNothing,
    );
    await tester.tap(chevron);
    await tester.pumpAndSettle();
    expect(chat.pane.value, isNull); // the chevron only opens it
    expect(
      find.text('Review the diff from five angles, then verify'),
      findsOne,
    );
    expect(find.text('review:ui, review:perf, review:api'), findsOne);
    expect(tester.getRect(find.byTooltip('Hide its phases')), at);
    // Built again (the chat's next update), it stays open.
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topCenter,
          child: WorkflowCard(workflowCall('running'), chat, still: true),
        ),
      ),
    );
    expect(find.byTooltip('Hide its phases'), findsOne);
    // A click on the card opens and closes it in place too, never the pane.
    await tester.tap(find.textContaining('Review 4/7, 3 running'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show its phases'), findsOne);
    expect(chat.pane.value, isNull);
    await tester.tap(find.textContaining('Review 4/7, 3 running'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide its phases'), findsOne);
    // Its pane is the button's at its end.
    await tester.tap(find.byTooltip('Open its agents'));
    expect(chat.pane.value, 'wf');
    await tester.tap(find.byTooltip('Hide its phases'));
    await tester.pumpAndSettle();
    expect(find.text('review:ui, review:perf, review:api'), findsNothing);
  });

  testWidgets('long labels are cut, never how many more run', (tester) async {
    final call = workflowCall('running');
    call.workflow
      ..phases[1].started = 12
      ..running.clear()
      ..running.addAll([for (var i = 0; i < 3; i++) 'review:${'long' * 14}'])
      ..runningCount = 8;
    Collapsible.opened.add(call.id);
    await _pump(tester, call, width: 392, height: 200);
    expectTextInside(tester, 392);
    final card = tester.getRect(find.byType(WorkflowCard));
    final more = tester.getRect(find.text(' +5'));
    expect(more.right, lessThanOrEqualTo(card.right - 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('its pane button opens its pane, which lights it', (
    tester,
  ) async {
    final chat = ChatState('c', '/x');
    await tester.pumpWidget(
      themed(WorkflowCard(workflowCall('running'), chat, still: true)),
    );
    final t = NushiTheme.of(tester.element(find.byType(WorkflowCard))).t;
    Color? fill() => tester
        .widget<Tap>(
          find.descendant(
            of: find.byType(WorkflowCard),
            matching: find.byType(Tap),
          ),
        )
        .fill;
    expect(fill(), t.subagentTint);
    await tester.tap(find.byTooltip('Open its agents'));
    await tester.pump();
    expect(chat.pane.value, 'wf');
    expect(fill(), t.accentSoft); // lit while its pane is open
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a narrow workflow card: the state on a line of its own '
        '($name)', (tester) async {
      await _pump(tester, workflowCall('running'), tokens: tokens, width: 392);
      expect(find.text('Map 2/2, Review 4/7'), findsNothing);
      await expectLater(
        find.byType(WorkflowCard),
        matchesGoldenFile('goldens/workflow_card_narrow_$name.png'),
      );
    });
    for (final state in ['running', 'done']) {
      testWidgets('a workflow card opened, $state ($name)', (tester) async {
        final call = workflowCall(state);
        Collapsible.opened.add(call.id);
        await _pump(tester, call, tokens: tokens, height: 200);
        await expectLater(
          find.byType(WorkflowCard),
          matchesGoldenFile('goldens/workflow_card_open_${state}_$name.png'),
        );
      });
    }
    for (final (state, stalled) in [
      ('running', false),
      ('running', true),
      ('done', false),
      ('failed', false),
      ('stopped', false),
      ('unknown', false),
    ]) {
      final label = stalled ? 'stalled' : state;
      testWidgets('a workflow card, $label ($name)', (tester) async {
        await _pump(
          tester,
          workflowCall(state, stalled: stalled),
          tokens: tokens,
        );
        await expectLater(
          find.byType(WorkflowCard),
          matchesGoldenFile('goldens/workflow_card_${label}_$name.png'),
        );
      });
    }
  }
}
