import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp_servers.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'mcp_pig_fixtures.dart';

// PiG's add and edit sheets (the page's tests are mcp_pig_test.dart).
void main() {
  setUpAll(loadFonts);

  testWidgets('the form offers PiG’s scopes only, no SSE, and adds to the '
      'project’s .pig/mcp.json', (tester) async {
    final (fake, d) = await pigDaemon(tester);
    viewport(tester, const Size(720, 900), ratio: 3);
    await openPigForm(tester, d);
    expect(find.text('Add an MCP server for PiG'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Local'), findsNothing);
    expect(find.text('SSE'), findsNothing);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.textContaining('.pig/mcp.json'), findsOneWidget);
    expect(
      find.text(
        'In this folder’s .pig/mcp.json, shared with everyone on it. PiG '
        'loads it once you trust this folder.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), 'lint');
    await tester.enterText(find.byType(TextField).at(1), 'lint-mcp');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    final add = fake.calls.whereType<AddMcpServerRequest>().single;
    expect((add.agent, add.scope, add.name), ('pig', 'project', 'lint'));
    expect(add.configJson, '{"command":"lint-mcp"}');
    await closeView(tester, d);
  });

  testWidgets('in a folder PiG trusts the form promises no trust', (
    tester,
  ) async {
    final (_, d) = await pigDaemon(tester, servers: pigTrusted);
    viewport(tester, const Size(720, 900), ratio: 3);
    await McpServers.of(d, '/Users/me/site', agent: 'pig').refresh();
    await openPigForm(tester, d);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(
      find.text('In this folder’s .pig/mcp.json, shared with everyone on it.'),
      findsOneWidget,
    );
    expect(find.textContaining('trust'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('in a folder PiG doesn’t trust, by the daemon’s word, the '
      'form and the page say so before it has a project server', (
    tester,
  ) async {
    List<McpServer> yoursOnly() => [
      for (final s in pigUntrusted())
        if (s.scope == 'user') s,
    ];
    final (_, d) = await pigPage(tester, servers: yoursOnly, trusted: false);
    expect(find.text(pigNotTrusted), findsOneWidget);
    await closeView(tester, d);
    final (_, d2) = await pigDaemon(tester, servers: yoursOnly, trusted: false);
    viewport(tester, const Size(720, 900), ratio: 3);
    await McpServers.of(d2, '/Users/me/site', agent: 'pig').refresh();
    await openPigForm(tester, d2);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'In this folder’s .pig/mcp.json, shared with everyone on it. PiG '
        'loads it once you trust this folder.',
      ),
      findsOneWidget,
    );
    await closeView(tester, d2);
  });

  testWidgets('editing keeps PiG’s keys the form doesn’t show', (tester) async {
    final (fake, d) = await pigPage(tester);
    await tester.tap(find.byTooltip('More').first); // search's
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit…'));
    await tester.pumpAndSettle();
    expect(find.text('Edit PiG’s search'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final edit = fake.calls.whereType<EditMcpServerRequest>().single;
    expect((edit.agent, edit.scope, edit.name), ('pig', 'user', 'search'));
    expect(edit.configJson, contains('"exposure":"direct"'));
    await closeView(tester, d);
  });
}
