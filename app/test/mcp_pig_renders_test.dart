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
import 'mcp_pig_fixtures.dart';

// PiG's MCP page and its sheets at full size, to look at (`make renders
// TEST=test/mcp_pig_renders_test.dart`); its tests are mcp_pig_test.dart.
void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final tokens in [Tokens.dark, Tokens.light]) {
    for (final width in [1700.0, 720.0]) {
      final at = '${width.toInt()}_${tokens.brightness.name}';
      renderTest('PiG’s page, $at', (tester) async {
        final (_, d) = await pigPage(
          tester,
          size: Size(width, 900),
          tokens: tokens,
        );
        viewport(tester, Size(width, 900));
        await tester.pumpAndSettle();
        await render(tester, find.byType(MaterialApp), 'mcp_pig_page_$at');
        await closeView(tester, d);
      });
      renderTest('PiG’s add form, $at', (tester) async {
        final (_, d) = await pigDaemon(tester);
        viewport(tester, Size(width, 900));
        await _sheet(tester, d, tokens);
        await tester.tap(find.text('Project'));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await render(tester, find.byType(MaterialApp), 'mcp_pig_form_$at');
        await closeView(tester, d);
      });
      for (final (name, servers, trusted, claude) in _pages) {
        renderTest('PiG’s page, $name, $at', (tester) async {
          final (_, d) = await pigDaemon(
            tester,
            servers: servers,
            trusted: trusted,
            claude: claude,
          );
          viewport(tester, Size(width, claude ? 1100 : 900));
          await tester.pumpWidget(
            themed(
              McpView(daemon: d, folder: '/Users/me/site'),
              tokens: tokens,
              banner: false,
            ),
          );
          await tester.pumpAndSettle();
          await render(tester, find.byType(MaterialApp), 'mcp_pig_${name}_$at');
          await closeView(tester, d);
        });
      }
      for (final (name, server) in _edits) {
        renderTest('PiG’s edit sheet, $name, $at', (tester) async {
          final (_, d) = await pigDaemon(tester);
          viewport(tester, Size(width, 900));
          await _sheet(tester, d, tokens, server: server);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await render(tester, find.byType(MaterialApp), 'mcp_pig_${name}_$at');
          await closeView(tester, d);
        });
      }
    }
  }
}

/// Opens PiG's add sheet, or [server]'s edit sheet, over a plain window.
Future<void> _sheet(
  WidgetTester tester,
  Daemon d,
  Tokens tokens, {
  McpServer? server,
}) async {
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
                McpServers.of(d, '/Users/me/site', agent: 'pig'),
                server: server,
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

const _yours = '/Users/me/.pig/agent/mcp.json';
const _folders = '/Users/me/site/.pig/mcp.json';

/// The pages drawn beside the plain one: a name, PiG's servers, whether
/// PiG trusts the folder, and whether Claude's are on the page too.
final _pages = <(String, List<McpServer> Function(), bool?, bool)>[
  // One of yours the folder's file sets (held), on and off, beside live
  // ones; Claude's above, to see the switches and pills line up.
  ('held', _held, true, true),
  // A folder PiG doesn't trust, with no project server yet.
  ('untrusted0', () => [pigUntrusted().first], false, false),
  // Two project servers PiG doesn't load: the one line under the group.
  (
    'untrusted2',
    () => [
      ...pigUntrusted(),
      McpServer(
        name: 'docs',
        scope: 'project',
        source: _folders,
        configJson: '{"command":"docs-mcp"}',
        untrusted: true,
      ),
    ],
    false,
    false,
  ),
  // A failed server with a three-line error and two env names.
  (
    'failed3',
    () => [
      McpServer(
        name: 'indexer',
        scope: 'user',
        source: _yours,
        configJson:
            '{"command":"indexer-mcp",'
            '"env":{"INDEX_TOKEN":"••••","INDEX_ROOT":"••••"}}',
        state: 'failed',
        detail:
            'MCP connection closed\nindexer: config not found\nexit status 3',
      ),
    ],
    true,
    false,
  ),
];

List<McpServer> _held() => [
  McpServer(
    name: 'search',
    scope: 'user',
    source: _yours,
    configJson: '{"command":"search-mcp"}',
    state: 'disabled',
    off: true,
    held: 'Set by this folder’s .pig/mcp.json',
  ),
  McpServer(
    name: 'docs',
    scope: 'user',
    source: _yours,
    configJson: '{"command":"docs-mcp"}',
    state: 'connected',
    held: 'Set by this folder’s .pig/mcp.json',
  ),
  McpServer(
    name: 'tracker',
    scope: 'user',
    source: _yours,
    configJson: '{"type":"http","url":"https://tracker.example.com/mcp"}',
    state: 'connected',
  ),
  McpServer(
    name: 'notes',
    scope: 'user',
    source: _yours,
    configJson: '{"command":"notes-mcp"}',
    state: 'disabled',
    off: true,
  ),
  McpServer(
    name: 'lint',
    scope: 'project',
    source: _folders,
    configJson: '{"command":"lint-mcp"}',
    state: 'connected',
  ),
];

/// The edit sheets drawn: its title, and an OAuth server with hidden parts.
final _edits = <(String, McpServer)>[
  (
    'edit',
    McpServer(
      name: 'search',
      scope: 'user',
      source: _yours,
      configJson:
          '{"command":"search-mcp","args":["--stdio"],'
          '"env":{"SEARCH_KEY":"••••"},"exposure":"direct"}',
    ),
  ),
  (
    'oauth',
    McpServer(
      name: 'wiki',
      scope: 'user',
      source: _yours,
      configJson:
          '{"type":"http","url":"https://wiki.example.com/mcp",'
          '"oauth":{"authServerMetadataUrl":'
          '"https://login.example.com/••••/v2.0/meta","clientId":"nushi"}}',
    ),
  ),
];
