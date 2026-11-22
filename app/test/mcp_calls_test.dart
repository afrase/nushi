import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

// MCP calls in a Claude chat and a Codex chat: each reads as its server and
// tool, with its input, never as a command; Nushi's show and dev server
// calls as what they did. The daemon says which server and tool a call is
// for (Item.mcp_server, mcp_tool); the titles are each agent's own.

/// A call to [server]'s [tool], as the daemon sends a Codex or a Claude
/// chat's: the agent's own title and input, and the server and tool its
/// harness read (none from a daemon [old] below API 140, which sent
/// Codex's with its kind `execute`).
Item _mcp(
  String id,
  String server,
  String tool,
  Map<String, Object> args, {
  required bool codex,
  bool old = false,
  String status = 'completed',
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: codex && old ? 'execute' : 'other',
  title: codex ? 'mcp.$server.$tool' : 'mcp__${server}__$tool',
  mcpServer: old ? null : server,
  mcpTool: old ? null : tool,
  status: status,
  text: text,
  input: const JsonEncoder.withIndent(
    '  ',
  ).convert(codex ? {'server': server, 'tool': tool, 'arguments': args} : args),
);

/// The ask to start the dev server "web".
Item _ask({required bool codex}) => Item(
  id: 'ask',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  title: codex ? 'mcp.nushi.preview_start' : 'mcp__nushi__preview_start',
  mcpServer: 'nushi',
  mcpTool: 'preview_start',
  input: codex
      ? '{"server": "nushi", "tool": "preview_start", '
            '"arguments": {"name": "web"}}'
      : '{"name": "web"}',
  status: 'pending',
  serverCommand: 'PORT=5173 /opt/homebrew/bin/pnpm run dev',
  options: [
    Option(id: 'yes', name: 'Yes', kind: 'allow_once'),
    Option(id: 'no', name: 'No', kind: 'reject_once'),
  ],
);

/// A chat's transcript: an MCP call, a show and a dev server's start, and
/// the ask to start it again.
List<Item> _items({required bool codex}) => [
  userSays('u', 'Find the open bugs, then show the report and run the site.'),
  _mcp(
    'a',
    'github',
    'search_issues',
    {'query': 'is:open label:bug', 'per_page': 5},
    codex: codex,
    text: 'Found 2 issues: #12 Cart empties on reload, #15 Menu overlaps.',
  ),
  agentSays('m1', 'Two open bugs. The report is ready.'),
  _mcp('b', 'nushi', 'show', {'path': 'report.html'}, codex: codex),
  agentSays('m2', 'Starting the site.'),
  _mcp('c', 'nushi', 'preview_start', {'name': 'web'}, codex: codex),
  agentSays('m3', 'It stopped; starting it again.'),
  _ask(codex: codex),
];

void main() {
  setUpAll(loadFonts);

  for (final agent in ['claude', 'codex']) {
    for (final (width, brightness) in [
      (1700.0, Brightness.dark),
      (1700.0, Brightness.light),
      (720.0, Brightness.dark),
      (720.0, Brightness.light),
    ]) {
      testWidgets('a $agent chat’s MCP calls render, ${width.toInt()} '
          '${brightness.name}', (tester) async {
        browserFakes();
        viewport(tester, Size(width, 900), brightness: brightness);
        showDetails.value = false;
        final c = chat('c', agent, 'Fix the tea shop');
        final items = _items(codex: agent == 'codex');
        final fake = FakeDaemon([c])
          ..answer = ((input) => switch (input) {
            GetChatRequest() => GetChatResponse(chat: c, items: items),
            _ => null,
          });
        final d = await fake.connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        await tester.tap(find.text('github · search_issues'));
        await tester.pumpAndSettle();
        expect(find.textContaining(r'$ mcp'), findsNothing);
        expect(find.text('Input'), findsOneWidget);
        expect(find.textContaining('is:open label:bug'), findsOneWidget);
        // Its arguments alone, as the title says the server and tool.
        expect(find.textContaining('"server"'), findsNothing);
        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Start web'), findsOneWidget);
        expect(find.text('PORT=5173 /opt/homebrew/bin/pnpm run dev'), findsOne);
        await render(
          tester,
          find.byType(NushiApp),
          'mcp-calls-$agent-${width.toInt()}-${brightness.name}',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }

  // A daemon below API 140 says no call's server and tool: each MCP call
  // reads as its title, with no card of Nushi's own (ADR 0068's amendment),
  // until the daemon restarts into the app's.
  testWidgets('from an older daemon, MCP calls are plain calls', (
    tester,
  ) async {
    browserFakes();
    viewport(tester, const Size(1700, 900));
    showDetails.value = false;
    final c = chat('c', 'codex', 'Fix the tea shop');
    final items = [
      _mcp('a', 'github', 'search_issues', {}, codex: true, old: true),
      agentSays('m', 'And the report.'),
      _mcp('b', 'nushi', 'show', {'path': 'r.html'}, codex: false, old: true),
    ];
    final fake = FakeDaemon([c])
      ..answer = ((input) => switch (input) {
        GetChatRequest() => GetChatResponse(chat: c, items: items),
        _ => null,
      });
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(find.text(r'$ mcp.github.search_issues'), findsOneWidget);
    expect(find.text('mcp__nushi__show'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    await closeView(tester, d);
  }, variant: macOnly);
}
