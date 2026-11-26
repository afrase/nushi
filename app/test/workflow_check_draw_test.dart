import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status.dart';
import 'package:nushi/workflow_pane.dart';
import 'package:nushi/workflow_phases.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'workflow_card_test.dart' show workflowCall;
import 'workflow_pane_test.dart' show agents, workflowChat, workflowFake;

// A workflow's phase on its opened card, and an agent in its pane, that
// ends while it shows: the running dot turns into a check that draws
// itself, as a Worktrees row's does (worktree_marks_test.dart), and is
// whole at once with Reduce Motion. Made-up runs.

/// How far the check under [of] is drawn, null for none.
double? _drawn(WidgetTester tester, Finder of) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: of, matching: find.byType(CustomPaint)),
    )
    .map((p) => p.painter)
    .whereType<CheckPainter>()
    .firstOrNull
    ?.drawn;

/// The frames after a change that ended the work: drawing a moment in,
/// whole at once when [still] (Reduce Motion), whole once settled.
Future<void> _draws(
  WidgetTester tester,
  Finder of, {
  required bool still,
}) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    _drawn(tester, of),
    still ? 1 : inExclusiveRange(0, 1),
    reason: still ? 'Reduce Motion' : 'drawing',
  );
  await tester.pumpAndSettle();
  expect(_drawn(tester, of), 1);
}

/// A running run whose one phase, Map, has [done] of its 2 agents done.
Workflow _run(int done) => Workflow(
  runId: 'wf_5c1e',
  name: 'map-the-code',
  state: 'running',
  agents: 2,
  done: done,
  phases: [WorkflowPhase(title: 'Map', started: 2, done: done)],
  running: [if (done < 2) 'map:tests'],
  runningPhases: [if (done < 2) 0],
  runningCount: 2 - done,
);

void main() {
  setUpAll(loadFonts);

  for (final still in [false, true]) {
    final how = still ? ', whole at once with Reduce Motion' : '';
    testWidgets('a phase that ends on the opened card: its running dot turns '
        'into a check that draws itself$how', (tester) async {
      if (still) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      Future<void> show(Workflow w) =>
          tester.pumpWidget(themed(WorkflowPhases(w)));
      await show(_run(1));
      final phases = find.byType(WorkflowPhases);
      expect(find.byType(RunningDot), findsOne);
      expect(_drawn(tester, phases), isNull);
      await show(_run(2));
      expect(find.byType(RunningDot), findsNothing);
      await _draws(tester, phases, still: still);
    });

    testWidgets('an agent that ends in the Workflow pane: its running dot '
        'turns into a check that draws itself$how', (tester) async {
      if (still) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      var list = agents;
      final fake = workflowFake()
        ..on(
          (input) => input is GetWorkflowRequest
              ? GetWorkflowResponse(
                  workflow: workflowCall('running').workflow,
                  agents: list,
                )
              : null,
        );
      final chat = workflowChat();
      viewport(tester, const Size(420, 720));
      final d = await fake.connect(tester);
      await tester.pumpWidget(
        themed(WorkflowPane(chat: chat, daemon: d, id: 'wf', onClose: () {})),
      );
      await tester.pump();
      await tester.pump();
      final row = find
          .ancestor(of: find.text('review:ui'), matching: find.byType(Tap))
          .first;
      expect(
        find.descendant(of: row, matching: find.byType(RunningDot)),
        findsOne,
      );
      expect(_drawn(tester, row), isNull);
      // review:ui ends; the run's summary changes, so its agents are read
      // again.
      list = [
        for (final a in agents)
          if (a.label == 'review:ui')
            a.deepCopy()
              ..state = 'done'
              ..ended = msAgo(Duration.zero)
          else
            a,
      ];
      chat.apply(
        EventsResponse(
          chatId: 'c',
          seq: Int64(7),
          item: ItemEvent(item: workflowCall('running')..workflow.done = 7),
        ),
      );
      await tester.pump(WorkflowPane.refetch);
      await tester.pump();
      expect(
        find.descendant(of: row, matching: find.byType(RunningDot)),
        findsNothing,
      );
      await _draws(tester, row, still: still);
      await closeView(tester, d);
    });
  }
}
