import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _gateway = 'mcp__example-mcp-gateway__invoke_tool';

/// A call titled [title], with the MCP server and tool Claude's harness
/// reads from a title of the form `mcp__<server>__<tool>`.
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
  mcpServer: title.startsWith('mcp__') ? title.split('__')[1] : null,
  mcpTool: title.startsWith('mcp__')
      ? title.split('__').skip(2).join('__')
      : null,
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

Widget _rows(List<Item> calls, {Tokens tokens = Tokens.dark}) => themed(
  Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [for (final c in calls) ToolCallView(c)],
    ),
  ),
  tokens: tokens,
);

void main() {
  setUpAll(loadFonts);

  test("an MCP call's title is its server, tool and the tool it runs", () {
    expect(mcpOf(_call('1')), ('example-mcp-gateway', 'invoke_tool'));
    expect(mcpOf(Item(mcpServer: 'a', mcpTool: 'b__c')), ('a', 'b__c'));
    expect(mcpOf(Item(mcpServer: 'a')), isNull);
    // A daemon below API 140 sends neither: the title is shown as it is.
    expect(mcpOf(Item(title: _gateway)), isNull);
    expect(toolTitle(Item(title: _gateway)), _gateway);
    expect(
      toolTitle(_call('1', input: _input)),
      'example-mcp-gateway · invoke_tool · jira_search',
    );
    expect(toolTitle(_call('2')), 'example-mcp-gateway · invoke_tool');
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
    // An input that wraps the call's arguments names the call's own tool,
    // which isn't another (Codex's).
    final codex = Item(
      title: 'mcp.github.search_issues',
      mcpServer: 'github',
      mcpTool: 'search_issues',
      input:
          '{\n  "server": "github",\n  "tool": "search_issues",\n'
          '  "arguments": {\n    "query": "is:open"\n  }\n}',
    );
    expect(toolTitle(codex), 'github · search_issues');
    expect(toolTitle(_call('3', title: 'Read notes.md')), 'Read notes.md');
  });

  testWidgets('the MCP title, its raw name on hover', (tester) async {
    await tester.pumpWidget(_rows([_call('1', input: _input)]));
    expect(
      find.text('example-mcp-gateway · invoke_tool · jira_search'),
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

  testWidgets('a command left running: "in the background" in words, '
      'only its state in a narrow row', (tester) async {
    final call = Item(
      id: 'bg',
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      title: 'npm run dev',
      toolKind: 'execute',
      status: 'completed',
      backgroundCommand: BackgroundCommand(id: 'b', state: 'running'),
    );
    viewport(tester, const Size(800, 200));
    await tester.pumpWidget(_rows([call]));
    expect(find.text('in the background: running'), findsOne);
    final title = find.textContaining('npm run dev', findRichText: true);
    final whole = tester.getSize(title.first).width;
    await render(tester, find.byType(MaterialApp), 'tool_note_wide');

    // The chat's column at its least beside open panes (panes_narrow_test).
    viewport(tester, const Size(290, 200));
    await tester.pumpWidget(_rows([call]));
    expect(tester.takeException(), isNull);
    expect(find.text('running'), findsOne);
    expect(find.textContaining('in the background'), findsNothing);
    await render(tester, find.byType(MaterialApp), 'tool_note_narrow');
    // The command keeps its room.
    expect(tester.getSize(title.first).width, whole);
  });

  testWidgets('golden, input only, raw output only, nothing, dark', (
    tester,
  ) async {
    viewport(tester, const Size(720, 460), ratio: 2);
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
