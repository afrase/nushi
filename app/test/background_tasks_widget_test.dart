import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

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
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [for (final r in widget.rows) r.$2 as Widget],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a finished subagent stays, and opens again', (tester) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    expect(backgroundTasksWidget(chat, d), isNull); // none yet
    chat.items.add(_subagent('a', 'done'));
    await show(tester, chat, d);
    await tester.tap(find.textContaining('Task a'));
    expect(chat.pane.value, 'a');
    await closeView(tester, d);
  });

  testWidgets('a running task holds still as the pointer crosses it', (
    tester,
  ) async {
    final d = Daemon(transport: FakeDaemon([]));
    final chat = ChatState('c', '/x');
    chat.items.add(_subagent('a', 'running')..agentId = 'agent-a');
    await show(tester, chat, d);
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
}
