import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_card.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Claude's servers and Ante's (API 80), by the agent asked about.
Future<(FakeDaemon, Daemon)> _daemon(WidgetTester tester) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      ListMcpServersRequest(agent: 'ante') => ListMcpServersResponse(
        servers: [
          McpServer(
            name: 'fs',
            scope: 'user',
            source: '/Users/me/.ante/settings.json',
            configJson:
                '{"command":"fs-mcp","args":["--root","/"],'
                '"env":{"TOKEN":"••••"},"enabled_tools":["read"]}',
            state: 'connected',
          ),
          McpServer(
            name: 'web',
            scope: 'user',
            configJson: '{"url":"https://example.com/mcp","args":[],"env":{}}',
            state: 'failed',
            detail: 'timed out connecting after 15s',
          ),
        ],
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
      _ => null,
    };
  for (final a in fake.agents) {
    a.mcp = a.name == 'claude' || a.name == 'ante';
  }
  return (fake, await fake.connect(tester));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the page lists Ante’s servers under Ante, without a switch, '
      'and says it has yours only', (tester) async {
    final (fake, d) = await _daemon(tester);
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: McpView(daemon: d, folder: '/Users/me/ante'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<ListMcpServersRequest>();
    expect(asked.map((r) => r.agent).toSet(), {'claude', 'ante'});
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Ante'), findsOneWidget);
    expect(find.text(McpView.anteAbout), findsOneWidget);
    for (final name in ['github', 'fs', 'web']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('TOKEN=••••'), findsOneWidget); // masked, as Claude's
    expect(find.text('timed out connecting after 15s'), findsOneWidget);
    // Claude's own server has its switch; Ante's have none.
    expect(find.byType(Switch), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ante')).dy,
      greaterThan(tester.getTopLeft(find.text('github')).dy),
    );
    await closeView(tester, d);
  });

  testWidgets('an Ante chat’s card shows its servers', (tester) async {
    final (fake, d) = await _daemon(tester);
    final chat = ChatState('c1', '/Users/me/ante-card')..agent = 'ante';
    await tester.binding.setSurfaceSize(const Size(340, 500));
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: PanelCards([mcpCard(chat, d)])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('its own config'), findsNothing);
    expect(find.text('fs'), findsOneWidget);
    expect(find.text('web'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Failed to connect'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(
      fake.calls.whereType<ListMcpServersRequest>().map((r) => r.agent).toSet(),
      {'ante'},
    );
    await closeView(tester, d);
  });

  testWidgets('the form adds Ante’s for you only, without SSE', (tester) async {
    final (fake, d) = await _daemon(tester);
    await tester.binding.setSurfaceSize(const Size(720, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => mcpForm(
              context,
              McpServers.of(d, '/Users/me/form', agent: 'ante'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add an MCP server for Ante'), findsOneWidget);
    expect(find.textContaining('reads no project’s MCP servers'), findsOne);
    expect(find.text('Project'), findsNothing); // no scope to pick
    expect(find.text('SSE'), findsNothing);
    await tester.tap(find.text('HTTP'));
    await tester.pumpAndSettle();
    expect(find.text('Ante sends headers from version 0.2.15 on.'), findsOne);
    await tester.tap(find.text('stdio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'git');
    await tester.enterText(find.byType(TextField).at(1), 'git-mcp');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    final add = fake.calls.whereType<AddMcpServerRequest>().single;
    expect((add.agent, add.scope, add.name), ('ante', 'user', 'git'));
    await closeView(tester, d);
  });

  for (final (name, width, tokens) in [
    ('wide_dark', 1700.0, Tokens.dark),
    ('narrow_light', 720.0, Tokens.light),
  ]) {
    testWidgets('golden, Claude’s and Ante’s, $name', (tester) async {
      final (_, d) = await _daemon(tester);
      await tester.binding.setSurfaceSize(Size(width, 960));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: McpView(daemon: d, folder: '/Users/me/$name'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(McpView),
        matchesGoldenFile('goldens/mcp_ante_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
