import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/settings_rows.dart' show SettingsGroup;

import 'fake_daemon.dart';
import 'harness.dart';
import 'mcp_pig_fixtures.dart';

// What PiG's MCP page takes from the agent's McpShape, not its name (the
// page's tests are mcp_pig_test.dart).
void main() {
  setUpAll(loadFonts);

  testWidgets('a project switch says “for everyone on it” by the shape’s '
      'shared file, not by approval', (tester) async {
    final (_, d) = await pigDaemon(tester, servers: pigTrusted);
    final pig = agentList.value['pig']!;
    agentList.value = {
      ...agentList.value,
      'pig': pig.deepCopy()
        ..mcpShape = (pig.mcpShape.deepCopy()..projectSwitchShared = false),
    };
    viewport(tester, const Size(1000, 760), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/site'), banner: false),
    );
    await tester.pumpAndSettle();
    expect(tooltips().where((t) => t.contains('everyone')), isEmpty);
    expect(tooltips(), contains('On in this project. $restartWords'));
    await closeView(tester, d);
  });

  testWidgets('without a shape (an older daemon) mcpUserOnly says it: '
      'yours only, else Claude’s', (tester) async {
    final (_, d) = await pigDaemon(tester);
    final list = McpServers.of(d, '/old-daemon', agent: 'pig');
    await tester.pumpAndSettle();
    expect(list.shape.scopes, ['user', 'project']);
    agentList.value = {'pig': Agent(name: 'pig', mcp: true)};
    expect(list.shape.scopes, ['user', 'project', 'local']);
    expect((list.shape.approval, list.shape.sse), (true, true));
    agentList.value = {'pig': Agent(name: 'pig', mcp: true, mcpUserOnly: true)};
    expect(list.shape.scopes, ['user']);
    expect((list.shape.offSwitch, list.userOnly), (false, true));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('the groups only the check fills come from the shape’s '
      'checked scopes, not from approval', (tester) async {
    final (_, d) = await pigDaemon(tester);
    final pig = agentList.value['pig']!;
    agentList.value = {
      ...agentList.value,
      'pig': pig.deepCopy()
        ..mcpShape = (pig.mcpShape.deepCopy()
          ..approval = true
          ..checkedScopes.clear()),
    };
    viewport(tester, const Size(1000, 760), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/site'), banner: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plugins'), findsNothing);
    expect(find.text('claude.ai'), findsNothing);
    agentList.value = {
      ...agentList.value,
      'pig': pig.deepCopy()
        ..mcpShape = (pig.mcpShape.deepCopy()..checkedScopes.add('plugin')),
    };
    await tester.pumpAndSettle();
    expect(find.text('Plugins'), findsOneWidget);
    expect(find.text('claude.ai'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('a scope only the check fills reads Checking… while its check '
      'runs, by the shape, not by the scope’s name', (tester) async {
    final (fake, d) = await pigDaemon(tester);
    final check = Completer<ListMcpServersResponse>();
    fake.on(
      (input) => switch (input) {
        ListMcpServersRequest(agent: 'pig', checkHealth: true) => check.future,
        _ => null,
      },
    );
    final pig = agentList.value['pig']!;
    agentList.value = {
      ...agentList.value,
      'pig': pig.deepCopy()
        ..mcpShape = (pig.mcpShape.deepCopy()
          ..scopes.add('plugin')
          ..checkedScopes.add('claudeai')),
    };
    viewport(tester, const Size(1000, 900), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/site'), banner: false),
    );
    await tester.pump();
    await tester.pump();
    String empty(String group) => tester
        .widget<Text>(
          find.descendant(
            of: find.ancestor(
              of: find.text(group),
              matching: find.byType(SettingsGroup),
            ),
            matching: find.byWidgetPredicate(
              (w) => w is Text && {'None', 'Checking…'}.contains(w.data),
            ),
          ),
        )
        .data!;
    expect(empty('claude.ai'), 'Checking…');
    expect(empty('Plugins'), 'None');
    check.complete(ListMcpServersResponse(servers: pigUntrusted()));
    await tester.pumpAndSettle();
    expect(empty('claude.ai'), 'None');
    await closeView(tester, d);
  });

  testWidgets('an agent gone from the list keeps the last shape seen, never '
      'Claude’s; one never seen has the narrowest', (tester) async {
    final (_, d) = await pigDaemon(tester);
    final list = McpServers.of(d, '/Users/me/site', agent: 'pig');
    expect(list.shape.scopes, ['user', 'project']);
    agentList.value = {
      for (final e in agentList.value.entries)
        if (e.key != 'pig') e.key: e.value,
    };
    expect(list.shape.scopes, ['user', 'project']);
    expect((list.shape.sse, list.shape.approval), (false, false));
    final never = McpServers.of(d, '/Users/me/site', agent: 'made-up');
    expect(never.shape.scopes, ['user']);
    expect((never.shape.offSwitch, never.shape.sse), (false, false));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  test('no MCP widget tests an agent’s name: what differs comes from '
      'the shape or the agent’s words', () {
    final named = RegExp("'(claude|ante|pig|pi|codex|omp|opencode)'");
    for (final f in Directory('lib').listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.startsWith('mcp') || !name.endsWith('.dart')) continue;
      expect(
        named.allMatches(f.readAsStringSync()).map((m) => m[0]),
        isEmpty,
        reason: name,
      );
    }
  });
}
