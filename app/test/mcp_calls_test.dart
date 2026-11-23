import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  mcpCall(
    'a',
    'github',
    'search_issues',
    {'query': 'is:open label:bug', 'per_page': 5},
    codex: codex,
    text: 'Found 2 issues: #12 Cart empties on reload, #15 Menu overlaps.',
  ),
  agentSays('m1', 'Two open bugs. The report is ready.'),
  mcpCall('b', 'nushi', 'show', {'path': 'report.html'}, codex: codex),
  agentSays('m2', 'Starting the site.'),
  mcpCall('c', 'nushi', 'preview_start', {'name': 'web'}, codex: codex),
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
        showDetails.value = false;
        final c = chat('c', agent, 'Fix the tea shop');
        final items = _items(codex: agent == 'codex');
        final fake = FakeDaemon([c])
          ..answer = ((input) => switch (input) {
            GetChatRequest() => GetChatResponse(chat: c, items: items),
            _ => null,
          });
        final d = await openApp(
          tester,
          fake,
          size: Size(width, 900),
          brightness: brightness,
        );
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
      }, variant: onMac);
    }
  }

  // A daemon below API 140 says no call's server and tool: each MCP call
  // reads as its title, with no card of Nushi's own (ADR 0068's amendment),
  // until the daemon restarts into the app's.
  testWidgets('from an older daemon, MCP calls are plain calls', (
    tester,
  ) async {
    browserFakes();
    showDetails.value = false;
    final c = chat('c', 'codex', 'Fix the tea shop');
    final items = [
      mcpCall('a', 'github', 'search_issues', {}, codex: true, old: true),
      agentSays('m', 'And the report.'),
      mcpCall('b', 'nushi', 'show', {'path': 'r.html'}, old: true),
    ];
    final fake = FakeDaemon([c])
      ..answer = ((input) => switch (input) {
        GetChatRequest() => GetChatResponse(chat: c, items: items),
        _ => null,
      });
    final d = await openApp(tester, fake);
    expect(find.text(r'$ mcp.github.search_issues'), findsOneWidget);
    expect(find.text('mcp__nushi__show'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);
}
