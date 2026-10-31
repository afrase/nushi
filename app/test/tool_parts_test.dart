import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _gateway = 'mcp__litellm-mcp-gateway__invoke_tool';

Item _call(
  String id, {
  String title = _gateway,
  String input = '',
  String rawOutput = '',
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  title: title,
  toolKind: 'other',
  status: 'completed',
  input: input,
  rawOutput: rawOutput,
  text: text,
);

const _input =
    '{\n  "tool": "jira_search",\n  "arguments": {\n'
    '    "jql": "project = ABC AND status = Open",\n'
    '    "fields": [\n      "summary",\n      "status"\n    ]\n  }\n}';

Widget _rows(List<Item> calls, {Tokens tokens = Tokens.dark}) => MaterialApp(
  theme: NushiTheme(tokens).toThemeData(),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [for (final c in calls) ToolCallView(c)],
      ),
    ),
  ),
);

void main() {
  setUpAll(loadFonts);
  tearDown(Collapsible.opened.clear);

  test("an MCP call's title is its server, tool and the tool it runs", () {
    expect(mcpName(_gateway), ('litellm-mcp-gateway', 'invoke_tool'));
    expect(mcpName('mcp__a__b__c'), ('a', 'b__c'));
    expect(mcpName('mcp__a__'), isNull);
    expect(mcpName('Read'), isNull);
    expect(
      toolTitle(_call('1', input: _input)),
      'litellm-mcp-gateway · invoke_tool · jira_search',
    );
    expect(toolTitle(_call('2')), 'litellm-mcp-gateway · invoke_tool');
    // tool before name; a nested "tool" isn't the call's; a cut input
    // still names it.
    expect(
      innerTool(
        '{\n  "name": "b",\n  "x": {\n    "tool": "c"\n  },\n  "tool": "a"\n}',
      ),
      'a',
    );
    expect(innerTool('{\n  "args": {\n    "tool": "c"\n  }\n}'), isNull);
    // A tool's own name argument isn't a tool; a gateway's name is.
    expect(innerTool('{\n  "name": "my-repo"\n}'), isNull);
    expect(
      innerTool('{\n  "name": "jira_get",\n  "arguments": {}\n}'),
      'jira_get',
    );
    expect(innerTool('{\n  "tool_name": "x\\"y",\n  "q": "abc\n…'), 'x"y');
    expect(toolTitle(_call('3', title: 'Read notes.md')), 'Read notes.md');
  });

  testWidgets('the MCP title, its raw name on hover', (tester) async {
    await tester.pumpWidget(_rows([_call('1', input: _input)]));
    expect(
      find.text('litellm-mcp-gateway · invoke_tool · jira_search'),
      findsOneWidget,
    );
    expect(find.byTooltip(_gateway), findsOneWidget);
  });

  testWidgets('a row with only input opens to it, folded', (tester) async {
    await tester.pumpWidget(_rows([_call('1', input: _input)]));
    expect(find.byType(Chevron), findsOneWidget);
    await tester.tap(find.byType(ToolCallView));
    await tester.pumpAndSettle();
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Output'), findsNothing);
    expect(find.text(_input), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pump();
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('a row with only raw output opens to it', (tester) async {
    await tester.pumpWidget(
      _rows([_call('1', title: 'search', rawOutput: 'ABC-1 Fix it')]),
    );
    await tester.tap(find.byType(ToolCallView));
    await tester.pumpAndSettle();
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('ABC-1 Fix it'), findsOneWidget);
    expect(find.text('Input'), findsNothing);
  });

  testWidgets("a row with nothing to show isn't expandable", (tester) async {
    await tester.pumpWidget(_rows([_call('1', text: ' \n')]));
    expect(find.byType(Chevron), findsNothing);
    await tester.tap(find.byType(ToolCallView));
    await tester.pumpAndSettle();
    expect(find.text('Output'), findsNothing);
    // The call's own text beside its input is its Output.
    await tester.pumpWidget(
      _rows([_call('2', input: _input, text: 'found 1')]),
    );
    await tester.tap(find.byType(ToolCallView));
    await tester.pumpAndSettle();
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
  });

  testWidgets('golden, input only, raw output only, nothing, dark', (
    tester,
  ) async {
    viewport(tester, const Size(720, 420), ratio: 2);
    Collapsible.opened.addAll(['1', '2', '3']);
    await tester.pumpWidget(
      _rows([
        _call('1', input: _input),
        _call(
          '2',
          title: 'mcp__jira__search',
          rawOutput:
              '{\n  "issues": [\n    {\n      "key": "ABC-1"\n    }\n  ]\n}',
        ),
        _call('3', title: 'mcp__jira__ping'),
      ]),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/tool_parts_dark.png'),
    );
  });
}
