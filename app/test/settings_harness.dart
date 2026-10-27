import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// Shows Settings at [section] on [d], alone in a window of [size] (no
/// sidebar), in [tokens]; "closed" once it closes. [agent] marks an
/// agent's row (Agents).
Future<void> pumpSettings(
  WidgetTester tester,
  Daemon d,
  SettingsSection section, {
  Tokens tokens = Tokens.dark,
  Size size = const Size(1000, 760),
  String? agent,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>['Menlo', 'SF Mono'],
      );
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  d.openSettings(section: section, agent: agent);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: d,
          builder: (context, _) =>
              d.settings == null ? const Text('closed') : SettingsView(d),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Chats for the sidebar beside Settings.
final List<Chat> settingsChats = [
  chat('a', 'claude', 'Fix the login redirect', age: 2),
  chat('b', 'codex', 'Bump the API version', age: 1),
  chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 3),
];

/// A daemon with something in every section of Settings: sleep after 30
/// minutes, copies kept 90 days, MCP servers, skills, a Jira site, a
/// GitHub host, a paired phone.
FakeDaemon settingsFake({List<TranscriptCopy>? copies}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final list =
      copies ??
      [
        TranscriptCopy(
          chatId: 'a',
          title: 'Fix the login redirect',
          agent: 'claude',
          bytes: Int64(4 << 20),
          lastWrittenMs: Int64(now - 2 * 3600 * 1000),
        ),
        TranscriptCopy(
          chatId: 'b',
          title: 'Bump the API version',
          agent: 'codex',
          bytes: Int64(1 << 20),
          lastWrittenMs: Int64(now - 26 * 3600 * 1000),
        ),
      ];
  remoteState.value = Remote(
    relay: 'wss://relay.example.com',
    state: 'off',
    devices: [
      Device(id: 'p1', name: 'Aaron’s iPhone', lastSeen: Int64(now - 3600000)),
    ],
  );
  final fake = FakeDaemon(settingsChats)
    ..settings = Settings(
      sleepAfterMinutes: 30,
      debugLog: false,
      keepTranscripts: true,
      transcriptDays: 90,
    )
    ..answer = (input) => switch (input) {
      ListTranscriptsRequest() => ListTranscriptsResponse(
        totalBytes: Int64(list.fold(0, (n, c) => n + c.bytes.toInt())),
        copies: list,
      ),
      ListMcpServersRequest() => ListMcpServersResponse(
        servers: [
          McpServer(
            name: 'github',
            scope: 'user',
            configJson: '{"type":"http","url":"https://api.example.com/mcp"}',
            state: 'connected',
          ),
          McpServer(
            name: 'web',
            scope: 'project',
            configJson: '{"command":"npx","args":["web-mcp"]}',
            state: 'connected',
            approved: true,
          ),
        ],
      ),
      ListSkillsRequest() => ListSkillsResponse(
        skills: [
          Skill(
            name: 'release-notes',
            description:
                'Writes release notes from the commits since the '
                'last tag.',
            source: 'user',
            path: '/Users/me/.claude/skills/release-notes',
            state: 'on',
            tokens: 26,
          ),
        ],
      ),
      ListJiraSitesRequest() => ListJiraSitesResponse(
        sites: [
          JiraSite(
            id: 'acme.atlassian.net',
            url: 'https://acme.atlassian.net',
            email: 'me@acme.com',
            name: 'Test User',
          ),
        ],
      ),
      CheckJiraSiteRequest() => CheckJiraSiteResponse(name: 'Test User'),
      ListGitHubHostsRequest() => ListGitHubHostsResponse(
        hosts: [
          GitHubHost(
            host: 'github.com',
            login: 'octo',
            name: 'Octo Cat',
            source: 'gh',
            kind: 'oauth',
            scopes: ['read:org', 'repo'],
          ),
        ],
      ),
      _ => null,
    };
  fake.agents.first
    ..mcp = true
    ..version = '2.1.310';
  return fake;
}

/// The whole app (sidebar and all) at [size] in [brightness], Settings
/// open at [section].
Future<Daemon> pumpSettingsApp(
  WidgetTester tester,
  FakeDaemon fake,
  SettingsSection section, {
  Size size = const Size(1700, 1000),
  Brightness brightness = Brightness.dark,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>['Menlo', 'SF Mono'],
      );
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  // A chat open: MCP servers and Skills show its folder.
  d.select('a');
  await tester.pumpAndSettle();
  d.openSettings(section: section);
  await tester.pumpAndSettle();
  return d;
}

/// Every row's control ends at its group's right edge, less the row's
/// padding; returns how many rows were checked.
int expectControlsAtEdge(WidgetTester tester) {
  var n = 0;
  for (final e in find.byType(SettingsRow).evaluate()) {
    final control = (e.widget as SettingsRow).control;
    if (control == null) continue;
    final group = find.ancestor(
      of: find.byWidget(e.widget),
      matching: find.byType(SettingsGroup),
    );
    final right = tester.getRect(find.byWidget(control)).right;
    expect(
      right,
      moreOrLessEquals(tester.getRect(group.first).right - 14, epsilon: 0.5),
      reason: (e.widget as SettingsRow).label,
    );
    n++;
  }
  return n;
}
