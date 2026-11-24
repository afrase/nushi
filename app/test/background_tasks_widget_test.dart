import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'workflow_card_test.dart' show workflowCall;

Item _subagent(String id, String state) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: 'Task $id',
  status: 'completed',
  subagent: Subagent(state: state),
);

void main() {
  Future<void> show(WidgetTester tester, ChatState chat, Daemon d) async {
    final widget = backgroundTasksWidget(chat, d)!;
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          child: Column(
            children: [for (final r in widget.rows) r.$2 as Widget],
          ),
        ),
      ),
    );
  }

  testWidgets('a finished subagent stays, folded under "1 finished", and '
      'opens again', (tester) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    expect(backgroundTasksWidget(chat, d), isNull); // none yet
    chat.items.add(_subagent('a', 'done'));
    await show(tester, chat, d);
    expect(find.textContaining('Task a'), findsNothing);
    await tester.tap(find.text('1 finished'));
    await tester.pump();
    await tester.tap(find.textContaining('Task a'));
    expect(chat.pane.value, 'a');
    await closeView(tester, d);
  });

  testWidgets('a running task shows its Stop, and holds still as the pointer '
      'crosses it', (tester) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    chat.items.add(_subagent('a', 'running')..agentId = 'agent-a');
    await show(tester, chat, d);
    expect(find.byTooltip('Stop'), findsOneWidget); // as Claude's rail
    Rect row() => tester.getRect(find.textContaining('Task a'));
    final before = row();
    final height = tester.getSize(find.byType(Tap).first).height;
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(before.center);
    await tester.pump();
    expect(find.byTooltip('Stop'), findsOneWidget);
    expect(row(), before);
    expect(tester.getSize(find.byType(Tap).first).height, height);
    await pointer.removePointer();
    await closeView(tester, d);
  });

  testWidgets('a subagent given more work later shows the time it worked, '
      'its waits left out', (tester) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    final long = msAgo(const Duration(minutes: 97, seconds: 20));
    chat.items.addAll([
      // Worked 3 minutes, waited, and has worked again for 20 seconds.
      _subagent('again', 'running')
        ..subagent = Subagent(
          state: 'running',
          started: long,
          worked: Int64(180000),
          workingSince: msAgo(const Duration(seconds: 20)),
        ),
      // Worked 5 minutes and waits for a message: nothing is added.
      _subagent('waits', 'running')
        ..subagent = Subagent(
          state: 'running',
          started: long,
          worked: Int64(300000),
        ),
      // A daemon that doesn't say how long it worked: from its start.
      _subagent('unknown', 'running')
        ..subagent = Subagent(
          state: 'running',
          started: msAgo(const Duration(minutes: 2)),
        ),
    ]);
    await show(tester, chat, d);
    expect(find.text('3m 20s'), findsOneWidget);
    expect(find.text('5m 00s'), findsOneWidget);
    expect(find.text('2m 00s'), findsOneWidget);
    expect(find.textContaining('97m'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('many finished wait behind their line, the latest first', (
    tester,
  ) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    chat.items.addAll([for (var i = 0; i < 6; i++) _subagent('$i', 'done')]);
    await show(tester, chat, d);
    expect(find.textContaining('Task'), findsNothing);
    await tester.tap(find.text('6 finished'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.textContaining('Task 5')).dy,
      lessThan(tester.getTopLeft(find.textContaining('Task 0')).dy),
    );
    await closeView(tester, d);
  });

  testWidgets('workflows: running ones first, a stalled one says "no '
      'activity", ended ones wait under "n finished"; a click opens the '
      'pane, Stop only while it runs', (tester) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/x');
    chat.items.addAll([
      workflowCall('done', id: 'w-done')..workflow.name = 'over',
      workflowCall('running', id: 'w-run')..workflow.name = 'busy',
      workflowCall('unknown', id: 'w-ended')..workflow.name = 'paused',
      workflowCall('running', stalled: true, id: 'w-quiet')
        ..workflow.name = 'quiet',
    ]);
    final widget = backgroundTasksWidget(chat, d)!;
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          child: Column(
            children: [
              widget.summary!,
              for (final r in widget.rows) r.$2 as Widget,
            ],
          ),
        ),
      ),
    );
    expect(find.text('2 running'), findsOne);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('busy'), lessThan(top('quiet')));
    expect(find.text('no activity'), findsOne);
    expect(find.text('over'), findsNothing);
    expect(find.text('paused'), findsNothing);
    expect(find.byTooltip('Stop'), findsNWidgets(2)); // both still run

    await tester.tap(find.text('2 finished'));
    await tester.pump();
    expect(top('quiet'), lessThan(top('2 finished')));
    expect(top('paused'), lessThan(top('over'))); // the latest first
    expect(find.text('ended'), findsOne);
    expect(find.byTooltip('Stop'), findsNWidgets(2)); // none on ended ones

    await tester.tap(find.text('over'));
    expect(chat.pane.value, 'w-done');
    await tester.tap(find.text('quiet'));
    expect(chat.pane.value, 'w-quiet');

    Finder stopIn(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Tap)).first,
      matching: find.byTooltip('Stop'),
    );
    expect(stopIn('over'), findsNothing);
    expect(stopIn('paused'), findsNothing);
    await tester.tap(stopIn('busy'));
    await tester.pump();
    final stop = fake.calls.whereType<StopTaskRequest>().single;
    expect((stop.chatId, stop.callId), ('c', 'w-run'));
    await closeView(tester, d);
  });
}
