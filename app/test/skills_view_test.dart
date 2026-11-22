import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/controls.dart' show Toggle;
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'fake_desktop.dart';
import 'harness.dart';

const _home = '/Users/me';

ListSkillsResponse _skills() => ListSkillsResponse(
  hasBuiltIn: true,
  hasPlugins: true,
  skills: [
    Skill(
      name: 'release-notes',
      description: 'Writes release notes from the commits since the last tag.',
      source: 'user',
      path: '$_home/.claude/skills/release-notes',
      state: 'on',
      tokens: 26,
    ),
    Skill(
      name: 'old-habits',
      description: 'Something I stopped using.',
      source: 'user',
      path: '$_home/.claude/skills/old-habits',
      state: 'off',
      tokens: 12,
    ),
    Skill(
      name: 'quiet',
      description: 'Turned off by the project.',
      source: 'user',
      path: '$_home/.claude/skills/quiet',
      state: 'off',
      setIn: '$_home/app/.claude/settings.local.json',
      tokens: 9,
    ),
    Skill(
      name: 'deploy',
      description: 'Deploys the app to staging. Use when asked to ship.',
      source: 'project',
      path: '$_home/app/.claude/skills/deploy',
      state: 'user-invocable-only',
      tokens: 21,
    ),
    Skill(
      name: 'demo:hello',
      description: 'Says hello when the user greets.',
      source: 'plugin',
      plugin: 'demo@market',
      path: '$_home/.claude/plugins/cache/market/demo/1.0.0/skills/hello',
      state: 'on',
      tokens: 20,
    ),
  ],
  plugins: [
    Plugin(
      id: 'demo@market',
      name: 'demo',
      version: '1.0.0',
      description: 'A demo plugin',
      scope: 'user',
      enabled: true,
      skills: 1,
      commands: 2,
      agents: 1,
      mcpServers: 1,
      switchScope: 'user',
      path: '$_home/.claude/plugins/cache/market/demo/1.0.0',
    ),
    Plugin(
      id: 'team@market',
      name: 'team',
      version: '0.3.0',
      scope: 'local',
      commands: 1,
      switchScope: 'local',
      path: '$_home/.claude/plugins/cache/market/team/0.3.0',
    ),
  ],
);

/// OpenCode's skills, as the daemon lists them (which is one file, which
/// its Trash refuses): a folder's, a lone file's, one in a group, one in a
/// group whose folder is named as a skills folder is, one of Claude's it
/// reads too, and a shared lone file.
ListSkillsResponse _opencode() => ListSkillsResponse(
  readsShared: true,
  skills: [
    for (final (name, source, path, oneFile, noTrash) in [
      ('mine', 'user', 'mine', false, false),
      ('loose', 'user', 'loose.md', true, true),
      ('nested', 'user', 'group/nested', false, true),
      ('deep', 'user', 'skills/deep', false, true),
      ('deploy', 'project', '$_home/app/.claude/skills/deploy', false, true),
      ('notes', 'shared', '$_home/app/.agents/skills/notes.md', true, true),
    ])
      Skill(
        name: name,
        source: source,
        path: source == 'user' ? '$_home/.config/opencode/skills/$path' : path,
        oneFile: oneFile,
        noTrash: noTrash,
        noLink: source == 'shared',
        state: 'on',
        tokens: 3,
        agents: [
          if (source == 'shared') SkillAgent(agent: 'opencode', state: 'on'),
        ],
      ),
  ],
);

Future<(FakeDaemon, Daemon)> _view(
  WidgetTester tester,
  String folder, {
  Tokens tokens = Tokens.dark,
  int api = apiVersion,
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      PingRequest() => PingResponse(apiVersion: api),
      ListSkillsRequest() => _skills(),
      _ => null,
    };
  final d = await fake.connect(tester);
  viewport(tester, const Size(1000, 860), ratio: 3);
  await tester.pumpWidget(
    themed(
      SkillsView(daemon: d, folder: folder),
      tokens: tokens,
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a skill’s switch, and one set elsewhere that can’t change '
      'here; a plugin’s skill goes with its plugin', (tester) async {
    final (fake, d) = await _view(tester, '$_home/switch');
    // release-notes, old-habits, quiet, deploy, built in, demo, team.
    final switches = find.byType(Toggle);
    expect(switches, findsNWidgets(7));
    expect(tester.widget<Toggle>(switches.at(2)).onChanged, isNull); // quiet
    expect(find.text('with its plugin'), findsOneWidget);
    expect(find.text('Only by /name'), findsOneWidget);
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetSkillOnRequest>().single;
    expect(
      (set.folder, set.source, set.name, set.on),
      ('$_home/switch', 'user', 'release-notes', false),
    );
    await tester.ensureVisible(switches.at(6)); // below the window
    await tester.pumpAndSettle();
    await tester.tap(switches.at(6)); // team, in this project
    await tester.pumpAndSettle();
    final plugin = fake.calls.whereType<SetPluginOnRequest>().single;
    expect((plugin.id, plugin.on), ('team@market', true));
    await closeView(tester, d);
  });

  testWidgets('a list that failed while the daemon was gone is asked for '
      'again once it is back', (tester) async {
    var fail = true;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        ListSkillsRequest() when fail => throw ConnectException(
          Code.unavailable,
          'daemon unavailable: connection lost',
        ),
        ListSkillsRequest() => _skills(),
        _ => null,
      };
    final d = await fake.connect(tester);
    viewport(tester, const Size(1000, 860), ratio: 3);
    await tester.pumpWidget(
      themed(SkillsView(daemon: d, folder: '/Users/me/lost')),
    );
    await tester.pumpAndSettle();
    expect(find.text('daemon unavailable: connection lost'), findsOneWidget);
    fail = false;
    await fake.restart(tester);
    expect(find.text('daemon unavailable: connection lost'), findsNothing);
    expect(find.byType(Toggle), findsNWidgets(7)); // as in the first test
    await closeView(tester, d);
  });

  testWidgets('search keeps the skills and plugins that match', (tester) async {
    final (_, d) = await _view(tester, '$_home/search');
    await tester.enterText(find.byType(TextField), 'HELLO');
    await tester.pumpAndSettle();
    expect(find.text('demo:hello'), findsOneWidget);
    expect(find.text('release-notes'), findsNothing);
    expect(find.text('team@market'), findsNothing);
    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pumpAndSettle();
    expect(find.text('No skills or plugins match'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('Delete… names the folder going to the Trash', (tester) async {
    final (fake, d) = await _view(tester, '$_home/delete');
    await tester.tap(find.byTooltip('More').at(3)); // deploy
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete deploy?'), findsOneWidget);
    expect(
      find.textContaining('to the Trash:\n$_home/app/.claude/skills/deploy'),
      findsOneWidget,
    );
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<TrashSkillRequest>().single.path,
      '$_home/app/.claude/skills/deploy',
    );
    await closeView(tester, d);
  });

  testWidgets('OpenCode: where it reads skills and keeps a switch; a skill '
      'the daemon says is one file opens as itself, and one it says its '
      'Trash refuses has no Delete…', (tester) async {
    final opened = fakeDesktop();
    final fake = FakeDaemon([])
      ..answer = (input) => input is ListSkillsRequest ? _opencode() : null;
    final d = await fake.connect(tester);
    d.skillsAgent = 'opencode';
    viewport(tester, const Size(1000, 860), ratio: 3);
    await tester.pumpWidget(
      themed(SkillsView(daemon: d, folder: '$_home/opencode')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'In every folder: skills in your OpenCode config folder, and '
        'Claude’s ~/.claude/skills.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'In this folder: .opencode/skills, .opencode/skill and Claude’s '
        '.claude/skills, here and in every folder above it.',
      ),
      findsOneWidget,
    );
    expect(find.text('in your OpenCode config'), findsNWidgets(5));
    expect(find.text('for OpenCode'), findsOneWidget);
    // Each skill's menu: what opens, and whether Delete… is there.
    for (final (at, open, file, deletable) in [
      (0, 'Open SKILL.md', '.config/opencode/skills/mine/SKILL.md', true),
      (1, 'Open loose.md', '.config/opencode/skills/loose.md', false),
      (
        2,
        'Open SKILL.md',
        '.config/opencode/skills/group/nested/SKILL.md',
        false,
      ),
      // In a group named skills: its path ends as one right in a skills
      // folder does.
      (
        3,
        'Open SKILL.md',
        '.config/opencode/skills/skills/deep/SKILL.md',
        false,
      ),
      (4, 'Open SKILL.md', 'app/.claude/skills/deploy/SKILL.md', false),
      (5, 'Open notes.md', 'app/.agents/skills/notes.md', false),
    ]) {
      await tester.tap(find.byTooltip('More').at(at));
      await tester.pumpAndSettle();
      expect(
        find.text('Delete…'),
        deletable ? findsOneWidget : findsNothing,
        reason: file,
      );
      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
      expect(opened.last, ['-t', '$_home/$file']);
    }
    await closeView(tester, d);
  });

  testWidgets('a skill folder named <name>.md, the name from its front '
      'matter, is a folder: its SKILL.md opens and Delete… is there', (
    tester,
  ) async {
    final opened = fakeDesktop();
    const path = '$_home/.codex/skills/x.md';
    final fake = FakeDaemon([])
      ..answer = (input) => input is ListSkillsRequest
          ? ListSkillsResponse(
              skills: [
                Skill(name: 'x', source: 'user', path: path, state: 'on'),
              ],
            )
          : null;
    final d = await fake.connect(tester);
    d.skillsAgent = 'codex';
    viewport(tester, const Size(1000, 860), ratio: 3);
    await tester.pumpWidget(
      themed(SkillsView(daemon: d, folder: '$_home/named')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Delete…'), findsOneWidget);
    await tester.tap(find.text('Open SKILL.md'));
    await tester.pumpAndSettle();
    expect(opened.last, ['-t', '$path/SKILL.md']);
    await closeView(tester, d);
  });

  testWidgets('opened with no chat, it shows the agent a new chat would '
      'start with, never asking for an empty one', (tester) async {
    final fake = FakeDaemon([chat('c', 'codex', 'Earlier')])
      ..answer = (input) => input is ListSkillsRequest ? _skills() : null;
    final d = await fake.connect(tester);
    expect(d.skillsAgent, isNull);
    viewport(tester, const Size(1000, 860), ratio: 3);
    await tester.pumpWidget(
      themed(SkillsView(daemon: d, folder: '$_home/default')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget); // the picker
    expect(
      fake.calls.whereType<ListSkillsRequest>().map((r) => r.agent).toSet(),
      {'codex'},
    );
    await closeView(tester, d);
  });

  testWidgets('before the daemon lists its agents: Reading…, then the list', (
    tester,
  ) async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is ListSkillsRequest ? _skills() : null;
    final d = await fake.connect(tester);
    final agents = agentList.value;
    agentList.value = {};
    viewport(tester, const Size(1000, 860), ratio: 3);
    await tester.pumpWidget(
      themed(SkillsView(daemon: d, folder: '$_home/early')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reading…'), findsOneWidget);
    expect(fake.calls.whereType<ListSkillsRequest>(), isEmpty);
    agentList.value = agents;
    await tester.pumpAndSettle();
    expect(find.text('release-notes'), findsOneWidget);
    expect(fake.calls.whereType<ListSkillsRequest>().single.agent, 'claude');
    await closeView(tester, d);
  });

  // Opened with no chat to go by, when the last chat was Codex's: to
  // look at (`make renders`).
  for (final tokens in [Tokens.dark, Tokens.light]) {
    for (final width in [1700.0, 720.0]) {
      final name =
          'skills_last_codex_${width.toInt()}_${tokens.brightness.name}';
      testWidgets('render: no chat, the last one Codex’s, $name', (
        tester,
      ) async {
        final fake = FakeDaemon([chat('c', 'codex', 'Earlier')])
          ..answer = (input) => switch (input) {
            ListSkillsRequest(agent: 'codex') => ListSkillsResponse(
              readsShared: true,
              skills: [
                Skill(
                  name: 'notes',
                  description: 'Keeps notes.',
                  source: 'user',
                  path: '$_home/.codex/skills/notes',
                  state: 'on',
                  tokens: 8,
                ),
              ],
            ),
            ListSkillsRequest() => _skills(),
            _ => null,
          };
        final d = await fake.connect(tester);
        viewport(tester, Size(width, 860));
        await tester.pumpWidget(
          themed(
            SkillsView(daemon: d, folder: '$_home/last'),
            tokens: tokens,
            banner: false,
          ),
        );
        await tester.pumpAndSettle();
        await render(tester, find.byType(MaterialApp), name);
        await closeView(tester, d);
      });
    }
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d) = await _view(tester, '$_home/$name', tokens: tokens);
      await expectLater(
        find.byType(SkillsView),
        matchesGoldenFile('goldens/skills_view_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
