import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart' show Toggle;
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/mcp_widget.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Claude's servers and Ante's (API 80), by the agent asked about.
Future<(FakeDaemon, Daemon)> _daemon(
  WidgetTester tester, {
  int api = apiVersion,
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      PingRequest() => PingResponse(apiVersion: api),
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
    a
      ..mcp = a.name == 'claude' || a.name == 'ante'
      ..mcpUserOnly = a.name == 'ante';
  }
  return (fake, await fake.connect(tester));
}

/// Ante's one server, wanting a sign-in until it has had one.
Future<(FakeDaemon, Daemon)> _signIn(WidgetTester tester) async {
  var signedIn = false;
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      PingRequest() => PingResponse(apiVersion: apiVersion),
      ListMcpServersRequest(agent: 'ante') => ListMcpServersResponse(
        servers: [
          McpServer(
            name: 'example-gateway',
            scope: 'user',
            configJson: '{"url":"https://mcp.example.com/mcp"}',
            state: signedIn ? 'connected' : 'needs_auth',
          ),
        ],
      ),
      ListMcpServersRequest() => ListMcpServersResponse(),
      LoginMcpServerRequest() => () {
        signedIn = true;
        return LoginMcpServerResponse();
      }(),
      _ => null,
    };
  for (final a in fake.agents) {
    a
      ..mcp = a.name == 'claude' || a.name == 'ante'
      ..mcpUserOnly = a.name == 'ante';
  }
  return (fake, await fake.connect(tester));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the page lists Ante’s servers under Ante, without a switch, '
      'and says it has yours only', (tester) async {
    final (fake, d) = await _daemon(tester);
    viewport(tester, const Size(1000, 900), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/ante')),
    );
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<ListMcpServersRequest>();
    expect(asked.map((r) => r.agent).toSet(), {'claude', 'ante'});
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Ante'), findsOneWidget);
    expect(find.text(McpView.userOnlyAbout('Ante')), findsOneWidget);
    for (final name in ['github', 'fs', 'web']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('TOKEN=••••'), findsOneWidget); // masked, as Claude's
    expect(find.text('timed out connecting after 15s'), findsOneWidget);
    // Claude's own server has its switch; Ante's have none.
    expect(find.byType(Toggle), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ante')).dy,
      greaterThan(tester.getTopLeft(find.text('github')).dy),
    );
    await closeView(tester, d);
  });

  testWidgets('an Ante server that asks for a sign-in has Log in, and shows '
      'its real state once that is done', (tester) async {
    final (fake, d) = await _signIn(tester);
    viewport(tester, const Size(1000, 900), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/sign-in')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Needs login'), findsOneWidget);
    expect(find.text('Failed to connect'), findsNothing);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    final login = fake.calls.whereType<LoginMcpServerRequest>().single;
    expect((login.agent, login.name), ('ante', 'example-gateway'));
    expect(find.text('Needs login'), findsNothing);
    expect(find.text('Log in'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('an Ante server with a URL has Log out, as any agent’s; one '
      'run on a command has none', (tester) async {
    final (fake, d) = await _daemon(tester);
    viewport(tester, const Size(1000, 900), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/logout')),
    );
    await tester.pumpAndSettle();
    final more = find.byTooltip('More');
    await tester.tap(more.at(1)); // fs, a command
    await tester.pumpAndSettle();
    expect(find.text('Edit…'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(more.at(2)); // web, a URL
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    final out = fake.calls.whereType<LogoutMcpServerRequest>().single;
    expect((out.agent, out.name), ('ante', 'web'));
    await closeView(tester, d);
  });

  testWidgets('an Ante chat’s widget shows its servers', (tester) async {
    final (fake, d) = await _daemon(tester);
    final chat = ChatState('c1', '/Users/me/ante-card')..agent = 'ante';
    viewport(tester, const Size(340, 500), ratio: 3);
    await tester.pumpWidget(themed(PanelWidgets([mcpWidget(chat, d)])));
    await tester.pumpAndSettle();
    expect(find.textContaining('its own config'), findsNothing);
    expect(find.text('fs'), findsOneWidget);
    expect(find.text('web'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Failed to connect'), findsOneWidget);
    expect(find.byType(Toggle), findsNothing);
    expect(
      fake.calls.whereType<ListMcpServersRequest>().map((r) => r.agent).toSet(),
      {'ante'},
    );
    await closeView(tester, d);
  });

  testWidgets('the form adds Ante’s for you only, without SSE', (tester) async {
    final (fake, d) = await _daemon(tester);
    viewport(tester, const Size(720, 900), ratio: 3);
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
    expect(find.text('Headers'), findsOne); // no note of one agent's versions
    expect(find.textContaining('0.2.15'), findsNothing);
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
      viewport(tester, Size(width, 960), ratio: 3);
      await tester.pumpWidget(
        themed(
          McpView(daemon: d, folder: '/Users/me/$name'),
          tokens: tokens,
          banner: false,
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

  testWidgets('MCP says who can change the servers once the agents are known', (
    tester,
  ) async {
    final (_, d) = await _daemon(tester);
    agentList.value = {};
    final list = McpServers.of(d, '/late-agents', agent: 'ante');
    await tester.pumpAndSettle();
    var told = 0;
    list.addListener(() => told++);
    expect(list.userOnly, isTrue); // the narrowest shape until it's known
    agentList.value = {
      'ante': Agent(
        name: 'ante',
        mcpShape: McpShape(scopes: ['user', 'project']),
      ),
    };
    expect(told, 1);
    expect(list.userOnly, isFalse);
    await closeView(tester, d);
  });

  testWidgets('a list forgotten with the run state stops hearing the agents', (
    tester,
  ) async {
    final (_, d) = await _daemon(tester);
    final list = McpServers.of(d, '/forgotten', agent: 'ante');
    await tester.pumpAndSettle();
    var told = 0;
    list.addListener(() => told++);
    forgetRunState();
    told = 0; // agentList put back may have told it as it went
    agentList.value = {'ante': Agent(name: 'ante', mcpUserOnly: true)};
    expect(told, 0);
    expect(McpServers.of(d, '/forgotten', agent: 'ante'), isNot(same(list)));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('a change in one folder asks for the agent’s others again, '
      'the same lists', (tester) async {
    final (fake, d) = await _daemon(tester);
    final a = McpServers.of(d, '/changed/a', agent: 'claude');
    final shown = McpServers.of(d, '/changed/shown', agent: 'claude');
    final hidden = McpServers.of(d, '/changed/hidden', agent: 'claude');
    final ante = McpServers.of(d, '/changed/a', agent: 'ante');
    await tester.pumpAndSettle();
    var told = 0;
    void tell() => told++;
    shown.addListener(tell);
    addTearDown(() => shown.removeListener(tell));
    int asked(String folder, [String agent = 'claude']) => fake.calls
        .whereType<ListMcpServersRequest>()
        .where((r) => r.folder == folder && r.agent == agent)
        .length;
    final before = (asked('/changed/shown'), asked('/changed/hidden'));
    final anteBefore = asked('/changed/a', 'ante');
    a.changed();
    await tester.pumpAndSettle();
    // The shown list is asked for again at once (list, then check), the
    // hidden one only when next asked for; another agent's not at all.
    expect(asked('/changed/shown'), before.$1 + 2);
    expect(told, greaterThan(0));
    expect(asked('/changed/hidden'), before.$2);
    expect(McpServers.of(d, '/changed/hidden', agent: 'claude'), same(hidden));
    expect(McpServers.of(d, '/changed/shown', agent: 'claude'), same(shown));
    await tester.pumpAndSettle();
    expect(asked('/changed/hidden'), before.$2 + 2);
    expect(McpServers.of(d, '/changed/a', agent: 'ante'), same(ante));
    expect(asked('/changed/a', 'ante'), anteBefore);
    await closeView(tester, d);
  });

  // An Ante remote server's row menu to look at (`make renders`).
  for (final tokens in [Tokens.dark, if (rendering) Tokens.light]) {
    for (final width in [1700.0, 720.0]) {
      final name = 'mcp_ante_menu_${width.toInt()}_${tokens.brightness.name}';
      testWidgets('an Ante remote server’s menu, $name', (tester) async {
        final (_, d) = await _daemon(tester);
        viewport(tester, Size(width, 900));
        await tester.pumpWidget(
          themed(
            McpView(daemon: d, folder: '/Users/me/menu'),
            tokens: tokens,
            banner: false,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More').last); // web's
        await tester.pumpAndSettle();
        await render(tester, find.byType(MaterialApp), name);
        await closeView(tester, d);
      });
    }
  }

  // Ante's HTTP form to look at (`make renders`): URL and headers, no note
  // of one agent's versions under them.
  for (final tokens in [Tokens.dark, if (rendering) Tokens.light]) {
    for (final width in [1700.0, 720.0]) {
      final name = 'mcp_form_ante_${width.toInt()}_${tokens.brightness.name}';
      testWidgets('Ante’s HTTP form, $name', (tester) async {
        final (_, d) = await _daemon(tester);
        viewport(tester, Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => mcpForm(
                      context,
                      McpServers.of(d, '/Users/me/form', agent: 'ante'),
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
        await tester.tap(find.text('HTTP'));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.textContaining('0.2.15'), findsNothing);
        await render(tester, find.byType(MaterialApp), name);
        await closeView(tester, d);
      });
    }
  }
}
