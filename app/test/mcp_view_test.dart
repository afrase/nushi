import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart' show Toggle;
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_actions.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/mcp_widget.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A folder's servers, one of each kind, one user server off.
List<McpServer> _servers() => [
  McpServer(
    name: 'github',
    scope: 'user',
    configJson: '{"type":"http","url":"https://api.example.com/mcp"}',
    state: 'connected',
  ),
  McpServer(
    name: 'notes',
    scope: 'user',
    configJson: '{"command":"notes-mcp","args":["--stdio"]}',
    state: 'disabled',
    off: true,
  ),
  McpServer(
    name: 'web',
    scope: 'project',
    configJson: '{"command":"npx","args":["web-mcp"]}',
    state: 'connected',
    approved: true,
  ),
  McpServer(
    name: 'db',
    scope: 'local',
    configJson: '{"command":"db-mcp","env":{"DB_URL":"••••"}}',
    state: 'connected',
  ),
  McpServer(
    name: 'plugin:docs:search',
    scope: 'plugin',
    configJson: '{"command":"docs-search"}',
    state: 'connected',
  ),
  McpServer(
    name: 'claude.ai Gmail',
    scope: 'claudeai',
    configJson: '{"type":"http","url":"https://gmail.example.com/mcp"}',
    state: 'needs_auth',
  ),
];

/// A fake daemon listing [_servers] for any folder.
Future<(FakeDaemon, Daemon)> _daemon(WidgetTester tester) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      ListMcpServersRequest() => ListMcpServersResponse(servers: _servers()),
      _ => null,
    };
  fake.agents.first.mcp = true; // Claude's MCP config is the one shown
  return (fake, await fake.connect(tester));
}

Future<(FakeDaemon, Daemon)> _view(
  WidgetTester tester,
  String folder, {
  Tokens tokens = Tokens.dark,
}) async {
  final (fake, d) = await _daemon(tester);
  viewport(tester, const Size(1000, 720), ratio: 3);
  await tester.pumpWidget(
    themed(
      McpView(daemon: d, folder: folder),
      tokens: tokens,
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a server only the agent turns off names that agent, and its '
      'command only where Nushi knows it', (tester) async {
    final (_, d) = await _daemon(tester);
    final plugin = McpServer(name: 'p', scope: 'plugin', state: 'connected');
    for (final (agent, note, tip) in [
      (
        'claude',
        'Off only with /mcp in a terminal',
        'Claude only lets you turn this off with /mcp in a terminal, or '
            'with its whole plugin.',
      ),
      (
        'codex',
        'Off only in a terminal',
        'Codex only lets you turn this off in a terminal, or with its '
            'whole plugin.',
      ),
    ]) {
      await tester.pumpWidget(
        themed(
          McpSwitch(McpServers.of(d, '/Users/me/w', agent: agent), plugin),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(note), findsOneWidget);
      expect(find.byTooltip(tip), findsOneWidget);
    }
    await closeView(tester, d);
  });

  testWidgets('the Plugins scope says how to add them in the agent’s words, '
      'as Skills does', (tester) async {
    final (_, d) = await _view(tester, '/Users/me/plugins');
    expect(
      find.textContaining('Add them with /plugin in Claude.'),
      findsOneWidget,
    );
    expect(find.textContaining('Claude Code'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('the page lists the agents the daemon says have MCP: Reading… '
      'until it has listed them, a line when none has', (tester) async {
    final (fake, d) = await _daemon(tester);
    final agents = agentList.value;
    agentList.value = {};
    viewport(tester, const Size(1000, 640), ratio: 3);
    await tester.pumpWidget(themed(McpView(daemon: d, folder: '/Users/me/m')));
    await tester.pumpAndSettle();
    expect(find.text('Reading…'), findsOneWidget);
    expect(fake.calls.whereType<ListMcpServersRequest>(), isEmpty);
    agentList.value = {
      for (final a in agents.values) a.name: a.deepCopy()..mcp = false,
    };
    await tester.pumpAndSettle();
    expect(find.text('No agent’s MCP servers are shown here'), findsOneWidget);
    expect(fake.calls.whereType<ListMcpServersRequest>(), isEmpty);
    agentList.value = agents;
    await tester.pumpAndSettle();
    expect(find.text('github'), findsOneWidget);
    expect(
      fake.calls.whereType<ListMcpServersRequest>().map((r) => r.agent).toSet(),
      {'claude'},
    );
    await closeView(tester, d);
  });

  testWidgets('a switch turns a user server on for the project; a plugin’s '
      'server and a connector say only /mcp can', (tester) async {
    final (fake, d) = await _view(tester, '/Users/me/switch');
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('in this project'), findsNWidgets(4));
    expect(find.text('Off only with /mcp in a terminal'), findsNWidgets(2));
    await tester.tap(find.byType(Toggle).at(1)); // github, notes, web, db
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetMcpServerOnRequest>().single;
    expect(
      (set.folder, set.scope, set.name, set.on),
      ('/Users/me/switch', 'user', 'notes', true),
    );
    await closeView(tester, d);
  });

  testWidgets('the widget: a switch a server, and after a change "Applies '
      'when the chat restarts" with Reload', (tester) async {
    final (fake, d) = await _daemon(tester);
    final chat = ChatState('c1', '/Users/me/card')
      ..agent = 'claude'
      ..mcpChanged = true;
    viewport(tester, const Size(340, 500), ratio: 3);
    await tester.pumpWidget(themed(PanelWidgets([mcpWidget(chat, d)])));
    await tester.pumpAndSettle();
    expect(find.byType(Toggle), findsNWidgets(4));
    expect(find.text('/mcp only'), findsNWidgets(2));
    expect(find.text('Applies when the chat restarts'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<ReloadChatRequest>().single.chatId, 'c1');
    await closeView(tester, d);
  });

  testWidgets('a check cut short by a lost daemon leaves the servers not '
      'checked; Try again asks again; once the daemon is back the list '
      'refreshes and the error goes', (tester) async {
    var down = false; // the daemon gone: pings fail
    var checks = 0;
    final fake = FakeDaemon([])
      ..answer = (input) {
        final gone = ConnectException(
          Code.unavailable,
          'daemon unavailable: connection lost',
        );
        if (input is PingRequest && down) throw gone;
        if (input is! ListMcpServersRequest) return null;
        if (!input.checkHealth) {
          return ListMcpServersResponse(
            servers: [for (final s in _servers()) s.deepCopy()..clearState()],
          );
        }
        if (checks++ < 2) throw gone; // the first check and Try again's
        return ListMcpServersResponse(servers: _servers());
      };
    fake.agents.first.mcp = true;
    final d = await fake.connect(tester);
    final chat = ChatState('c1', '/Users/me/lost')..agent = 'claude';
    viewport(tester, const Size(340, 500), ratio: 3);
    await tester.pumpWidget(themed(PanelWidgets([mcpWidget(chat, d)])));
    await tester.pumpAndSettle();
    expect(find.text('daemon unavailable: connection lost'), findsOneWidget);
    expect(find.text('Checking…'), findsNothing);
    expect(find.text('Not checked'), findsNWidgets(5)); // and one off

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Try again'), findsOneWidget);

    // The daemon restarts: gone for a ping, then back.
    down = true;
    await tester.pump(const Duration(seconds: 2));
    expect(d.connected, isFalse);
    expect(checks, 2); // nothing asked while it's away
    down = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(d.connected, isTrue);
    expect(checks, 3);
    expect(find.text('daemon unavailable: connection lost'), findsNothing);
    expect(find.text('Connected'), findsNWidgets(4));
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, an off server, $name', (tester) async {
      final (_, d) = await _view(tester, '/Users/me/$name', tokens: tokens);
      await expectLater(
        find.byType(McpView),
        matchesGoldenFile('goldens/mcp_view_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
