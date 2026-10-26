import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a subagent line keeps its state at the end, by its mark', (
    tester,
  ) async {
    final run = (
      call: Item(
        id: 'a',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        agent: 'general-purpose',
        title: 'Verify the steps',
        status: 'completed',
        subagent: Subagent(state: 'done'),
      ),
      items: <Item>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: SubagentLine(run, ChatState('c', '/x'), still: true),
        ),
      ),
    );
    final state = tester.getRect(find.text('done'));
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
    // The state, its mark (a check) and the chevron end the line, not its
    // middle.
    expect(chevron.left - state.right, lessThan(40));
    final line = tester.getRect(find.byType(SubagentLine));
    expect(chevron.right, greaterThan(line.right - 20));
  });
}
