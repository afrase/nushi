import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';

Item _subagent(String state) => Item(
  id: 'a',
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: 'Sleep then report the date',
  status: 'completed',
  subagent: Subagent(state: state),
);

void main() {
  Future<bool?> ask(WidgetTester tester, ChatState chat) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.light).toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await stopsBackground(
                context,
                chat,
                'Sleep the chat?',
                'Sleep',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('stopping an agent asks first while its subagent runs in the '
      'background', (tester) async {
    final chat = ChatState('c', '/x')..agent = 'claude';
    expect(await ask(tester, chat), isTrue); // none: no question

    chat.items.add(_subagent('running'));
    await ask(tester, chat);
    expect(find.text('Sleep the chat?'), findsOneWidget);
    expect(
      find.textContaining('general-purpose subagent is still running'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sleep the chat?'), findsNothing);

    chat.items[0] = _subagent('done');
    expect(await ask(tester, chat), isTrue);
  });

  testWidgets('a subagent stopped with its agent says so', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: SubagentLine((
            call: _subagent('stopped'),
            items: <Item>[],
          ), ChatState('c', '/x')),
        ),
      ),
    );
    expect(find.text('stopped'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
  });
}
