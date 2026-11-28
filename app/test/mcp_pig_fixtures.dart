// PiG's MCP servers for the tests and renders of its MCP page: a fake
// daemon with them, the page, and the add form.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// PiG's servers in a folder it doesn't trust (API 157): two of yours,
/// one connected and one failed, and one of the project's it doesn't load.
List<McpServer> pigUntrusted() => [
  McpServer(
    name: 'search',
    scope: 'user',
    source: '/Users/me/.pig/agent/mcp.json',
    configJson:
        '{"command":"search-mcp","args":["--stdio"],'
        '"env":{"SEARCH_KEY":"••••"},"exposure":"direct"}',
    state: 'connected',
  ),
  McpServer(
    name: 'tracker',
    scope: 'user',
    source: '/Users/me/.pig/agent/mcp.json',
    configJson: '{"type":"http","url":"https://tracker.example.com/mcp"}',
    state: 'failed',
    detail: 'connect: connection refused',
  ),
  McpServer(
    name: 'lint',
    scope: 'project',
    source: '/Users/me/site/.pig/mcp.json',
    configJson: '{"command":"lint-mcp"}',
    untrusted: true, // the check leaves it without a state (API 157)
  ),
];

/// The same folder once PiG trusts it: the project's server is used.
List<McpServer> pigTrusted() => [
  for (final s in pigUntrusted())
    if (s.untrusted)
      (s.deepCopy()
        ..untrusted = false
        ..state = 'connected'
        ..detail = '')
    else
      s,
];

/// A fake daemon with PiG's MCP servers ([servers]) in a folder PiG
/// trusts or not ([trusted], the daemon's word; by default as the
/// servers say), and Claude's too when [claude].
Future<(FakeDaemon, Daemon)> pigDaemon(
  WidgetTester tester, {
  List<McpServer> Function() servers = pigUntrusted,
  bool? trusted,
  bool claude = false,
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      ListMcpServersRequest(agent: 'pig') => ListMcpServersResponse(
        servers: servers(),
        folderTrusted: trusted ?? !servers().any((s) => s.untrusted),
      ),
      ListMcpServersRequest() => ListMcpServersResponse(
        servers: [
          McpServer(
            name: 'github',
            scope: 'user',
            configJson: '{"type":"http","url":"https://api.example.com/mcp"}',
            state: 'connected',
          ),
        ],
      ),
      EditMcpServerRequest() => EditMcpServerResponse(),
      _ => null,
    };
  for (final a in fake.agents) {
    a.mcp = a.name == 'pig' || (claude && a.name == 'claude');
  }
  return (fake, await fake.connect(tester));
}

/// PiG's page on a fake daemon with [servers], settled.
Future<(FakeDaemon, Daemon)> pigPage(
  WidgetTester tester, {
  List<McpServer> Function() servers = pigUntrusted,
  bool? trusted,
  Size size = const Size(1000, 760),
  Tokens tokens = Tokens.dark,
}) async {
  final (fake, d) = await pigDaemon(tester, servers: servers, trusted: trusted);
  viewport(tester, size, ratio: 3);
  await tester.pumpWidget(
    themed(
      McpView(daemon: d, folder: '/Users/me/site'),
      tokens: tokens,
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

/// Opens the add form for PiG's servers.
Future<void> openPigForm(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => mcpForm(
                context,
                McpServers.of(d, '/Users/me/site', agent: 'pig'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// What a switch's tooltip ends with.
const restartWords = 'Chats pick up a change when they restart.';

/// What the Project group says, once, in a folder PiG doesn't trust.
const pigNotTrusted =
    'Folder not trusted: run pig here in a terminal and trust it, then '
    'Check again.';

/// Every tooltip's words on the page.
List<String> tooltips() => [
  for (final t in find.byType(Tooltip).evaluate())
    (t.widget as Tooltip).message ?? '',
];
