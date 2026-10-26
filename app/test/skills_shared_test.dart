import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

const _home = '/Users/me';

/// The shared skills, as every agent's list has them.
List<Skill> _shared() => [
  Skill(
    name: 'release',
    description: 'Writes release notes from the commits since the last tag.',
    source: 'shared',
    path: '$_home/app/.agents/skills/release',
    tokens: 24,
    agents: [
      SkillAgent(agent: 'codex', state: 'on'),
      SkillAgent(agent: 'omp', state: 'off'),
      SkillAgent(agent: 'pig', state: 'untrusted'),
    ],
  ),
  Skill(
    name: 'review',
    description: 'Reviews a diff for bugs. Use when asked to review.',
    source: 'shared',
    path: '$_home/app/.agents/skills/review',
    tokens: 18,
    agents: [
      SkillAgent(
        agent: 'claude',
        state: 'on',
        via: '$_home/app/.claude/skills/review',
      ),
      SkillAgent(agent: 'codex', state: 'off'),
      SkillAgent(agent: 'ante', state: 'on'),
    ],
  ),
  Skill(
    name: 'everyday',
    description: 'Habits for every repository.',
    source: 'shared',
    path: '$_home/.agents/skills/everyday',
    everywhere: true,
    tokens: 9,
    agents: [SkillAgent(agent: 'codex', state: 'on')],
  ),
];

ListSkillsResponse _skills(String agent) => switch (agent) {
  'codex' => ListSkillsResponse(
    readsShared: true,
    skills: [
      Skill(
        name: 'mine',
        description: 'A skill of mine.',
        source: 'user',
        path: '$_home/.codex/skills/mine',
        state: 'on',
        tokens: 6,
      ),
      Skill(
        name: 'imagegen',
        description: 'Makes images.',
        source: 'system',
        path: '$_home/.codex/skills/.system/imagegen',
        state: 'on',
        tokens: 5,
      ),
      ..._shared(),
    ],
  ),
  'ante' => ListSkillsResponse(noSkills: 'Nushi doesn’t know where it is.'),
  _ => ListSkillsResponse(skills: _shared()),
};

Future<(FakeDaemon, Daemon)> _view(
  WidgetTester tester,
  String folder, {
  String agent = 'claude',
  Tokens tokens = Tokens.dark,
  Size size = const Size(1000, 700),
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) => switch (input) {
      ListSkillsRequest(:final agent) => _skills(agent),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.skillsAgent = agent;
  await tester.binding.setSurfaceSize(size);
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

Future<void> _close(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the agent picker lists the agents and reads the one picked; '
      'Claude is the default', (tester) async {
    final (fake, d) = await _view(tester, '$_home/pick');
    expect(fake.calls.whereType<ListSkillsRequest>().single.agent, 'claude');
    await tester.tap(find.byTooltip('Whose skills'));
    await tester.pumpAndSettle();
    for (final title in ['Codex', 'Ante', 'oh-my-pi', 'PiG']) {
      expect(find.text(title), findsWidgets);
    }
    await tester.tap(find.text('Codex').first); // the menu's, over the view
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<ListSkillsRequest>().last.agent, 'codex');
    expect(d.skillsAgent, 'codex');
    expect(find.text('Codex’s own'), findsOneWidget);
    expect(find.text('Built in'), findsNothing); // Claude's only
    await tester.tap(find.byTooltip('Whose skills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ante').last);
    await tester.pumpAndSettle();
    expect(find.text('Nushi doesn’t know where it is.'), findsOneWidget);
    await _close(tester, d);
  });

  testWidgets('Shared names the agents that load each skill, and the '
      'switch is the picked agent’s', (tester) async {
    final (fake, d) = await _view(tester, '$_home/shared', agent: 'codex');
    expect(find.text('Shared'), findsOneWidget);
    expect(
      find.textContaining(
        'Codex, oh-my-pi, PiG  ·  Off for oh-my-pi  ·  PiG loads it once '
        'the folder is trusted',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Claude (linked), Codex, Ante  ·  Off for Codex'),
      findsOneWidget,
    );
    expect(find.text('for Codex'), findsNWidgets(3));
    // mine, the shared release, review, everyday, then imagegen.
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(5));
    await tester.tap(switches.at(2)); // review, off for Codex
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetSkillOnRequest>().single;
    expect(
      (set.agent, set.source, set.name, set.on),
      ('codex', 'shared', 'review', true),
    );
    await _close(tester, d);
  });

  testWidgets('a folder PiG doesn’t trust: no switch, and says so', (
    tester,
  ) async {
    final (_, d) = await _view(tester, '$_home/pig', agent: 'pig');
    expect(find.text('Loads once the folder is trusted'), findsOneWidget);
    expect(find.text('Not read by PiG here'), findsNWidgets(2));
    expect(find.byType(Switch), findsNothing);
    await _close(tester, d);
  });

  testWidgets('Delete… of a shared skill names every agent that loses it, '
      'and the links that go with it', (tester) async {
    final (fake, d) = await _view(tester, '$_home/delete', agent: 'codex');
    await tester.tap(find.byTooltip('More').at(2)); // review
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete review?'), findsOneWidget);
    expect(
      find.textContaining('Claude, Codex and Ante lose it.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Claude’s link $_home/app/.claude/skills/review go too.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    final trash = fake.calls.whereType<TrashSkillRequest>().single;
    expect(
      (trash.agent, trash.path),
      ('codex', '$_home/app/.agents/skills/review'),
    );
    await _close(tester, d);
  });

  testWidgets('for Claude, a shared skill offers Link for Claude…, and New '
      'skill… asks where', (tester) async {
    final (fake, d) = await _view(tester, '$_home/link');
    expect(
      find.textContaining('Claude doesn’t read .agents/skills yet'),
      findsOneWidget,
    );
    expect(find.text('Not read by Claude'), findsNWidgets(2));
    await tester.tap(find.byTooltip('More').at(0)); // release
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link for Claude…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    final link = fake.calls.whereType<LinkSkillRequest>().single;
    expect(
      (link.agent, link.path),
      ('claude', '$_home/app/.agents/skills/release'),
    );
    await tester.tap(find.text('New skill…'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Claude doesn’t read .agents/skills yet: put it in .claude/skills '
        'instead, or link it there.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('In .agents/skills'));
    await tester.pumpAndSettle();
    expect(fake.started.single.agent, 'claude');
    await _close(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden of the Shared section, $name', (tester) async {
      final (_, d) = await _view(
        tester,
        '$_home/$name',
        agent: 'codex',
        tokens: tokens,
        size: const Size(1000, 640),
      );
      await expectLater(
        find.byType(SkillsView),
        matchesGoldenFile('goldens/skills_shared_$name.png'),
      );
      await _close(tester, d);
    });
  }
}
