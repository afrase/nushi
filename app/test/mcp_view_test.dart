import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_card.dart';
import 'package:nushi/panel_cards.dart';
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
  await tester.binding.setSurfaceSize(const Size(1000, 640));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: McpView(daemon: d, folder: folder),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a switch turns a user server on for the project; a plugin’s '
      'server and a connector say only /mcp can', (tester) async {
    final (fake, d) = await _view(tester, '/Users/me/switch');
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('in this project'), findsNWidgets(4));
    expect(find.text('Off only with /mcp in a terminal'), findsNWidgets(2));
    await tester.tap(find.byType(Switch).at(1)); // github, notes, web, db
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetMcpServerOnRequest>().single;
    expect(
      (set.folder, set.scope, set.name, set.on),
      ('/Users/me/switch', 'user', 'notes', true),
    );
    await closeView(tester, d);
  });

  testWidgets('the card: a switch a server, and after a change "Applies '
      'when the chat restarts" with Reload', (tester) async {
    final (fake, d) = await _daemon(tester);
    final chat = ChatState('c1', '/Users/me/card')
      ..agent = 'claude'
      ..mcpChanged = true;
    await tester.binding.setSurfaceSize(const Size(340, 500));
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: PanelCards([mcpCard(chat, d)])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('/mcp only'), findsNWidgets(2));
    expect(find.text('Applies when the chat restarts'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<ReloadChatRequest>().single.chatId, 'c1');
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
