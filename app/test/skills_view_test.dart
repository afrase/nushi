import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _home = '/Users/me';

ListSkillsResponse _skills() => ListSkillsResponse(
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

Future<(FakeDaemon, Daemon)> _view(
  WidgetTester tester,
  String folder, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      ListSkillsRequest() => _skills(),
      _ => null,
    };
  final d = await fake.connect(tester);
  await tester.binding.setSurfaceSize(const Size(1000, 860));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: SkillsView(daemon: d, folder: folder),
      ),
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
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(7));
    expect(tester.widget<Switch>(switches.at(2)).onChanged, isNull); // quiet
    expect(find.text('with its plugin'), findsOneWidget);
    expect(find.text('Only by /name'), findsOneWidget);
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetSkillOnRequest>().single;
    expect(
      (set.folder, set.source, set.name, set.on),
      ('$_home/switch', 'user', 'release-notes', false),
    );
    await tester.tap(switches.at(6)); // team, in this project
    await tester.pumpAndSettle();
    final plugin = fake.calls.whereType<SetPluginOnRequest>().single;
    expect((plugin.id, plugin.on), ('team@market', true));
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
    expect(find.text('No skills or plugins match.'), findsOneWidget);
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
