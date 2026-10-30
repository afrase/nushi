import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

Adapter _adapter(String package, String pinned, String installed) => Adapter(
  package: package,
  pinned: pinned,
  installed: installed,
  packages: 107,
  downloadBytes: Int64(8979854),
  diskBytes: Int64(73064448),
  folder: '/Users/me/Library/Application Support/Nushi/agents/claude',
);

/// Claude installed but not set up nor signed in, Codex set up with a
/// newer adapter pinned and a chat awake, Ante ready, oh-my-pi missing,
/// PiG ready.
final _found = [
  Agent(
    name: 'claude',
    title: 'Claude',
    path: '/opt/homebrew/bin/claude',
    version: '2.1.310',
    signedIn: 'no',
    adapter: _adapter('@agentclientprotocol/claude-agent-acp', '0.94.0', ''),
  ),
  Agent(
    name: 'codex',
    title: 'Codex',
    path: '/opt/homebrew/bin/codex',
    version: '0.163.0',
    ready: true,
    awake: 1,
    adapter: _adapter('@agentclientprotocol/codex-acp', '2.2.2', '2.2.1'),
  ),
  Agent(
    name: 'ante',
    title: 'Ante',
    path: '/Users/me/.ante/bin/ante',
    version: '0.2.14',
    ready: true,
  ),
  Agent(
    name: 'omp',
    title: 'oh-my-pi',
    problem: 'Not installed',
    page: 'https://github.com/can1357/oh-my-pi',
  ),
  Agent(
    name: 'pig',
    title: 'PiG',
    path: '/Users/me/.local/bin/pig',
    version: '0.5.3',
    ready: true,
  ),
];

Future<(FakeDaemon, Daemon)> _settings(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  String? agent,
  ShellEnvironment? environment,
  bool goAgent = false,
  Size size = const Size(1000, 760),
}) async {
  final fake = FakeDaemon([])
    ..agents = _found
    ..environment = environment;
  fake.settings.claudeGoAgent = goAgent;
  final d = await fake.connect(tester);
  await pumpSettings(
    tester,
    d,
    SettingsSection.agents,
    tokens: tokens,
    agent: agent,
    size: size,
  );
  return (fake, d);
}

/// Settings › Agents' switch for Claude's Go agent.
Finder get _goSwitch => find.descendant(
  of: find.ancestor(
    of: find.text("Use Nushi's Go agent"),
    matching: find.byType(SettingsRow),
  ),
  matching: find.byType(Switch),
);

void main() {
  setUpAll(loadFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
  });

  testWidgets('each agent as found, and what can be done', (tester) async {
    final (_, d) = await _settings(tester);
    expect(find.text('2.1.310 · /opt/homebrew/bin/claude'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);
    expect(find.text('Adapter 2.2.1'), findsOneWidget);
    expect(find.text('Update to 2.2.2'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(2)); // Ante, PiG
    expect(find.text('0.5.3 · /Users/me/.local/bin/pig'), findsOneWidget);
    expect(find.text('Not installed'), findsOneWidget);
    expect(find.text('Get it'), findsOneWidget);
    d.dispose();
  });

  testWidgets('Set up says what it downloads, then installs it', (
    tester,
  ) async {
    final (fake, d) = await _settings(tester);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Downloads @agentclientprotocol/claude-agent-acp 0.94.0 and the 106 '
        'packages it needs from npm, about 9 MB (73 MB on disk), into '
        '/Users/me/Library/Application Support/Nushi/agents/claude.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Set up').last);
    await tester.pumpAndSettle();
    expect(fake.setUp, ['claude']);
    expect(find.text('Set up Claude'), findsNothing); // the sheet closed
    d.dispose();
  });

  testWidgets('Update says its awake chat sleeps; Remove asks first', (
    tester,
  ) async {
    final (fake, d) = await _settings(tester);
    await tester.tap(find.text('Update to 2.2.2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Its awake chat sleeps.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text("Remove Codex's adapter?"), findsOneWidget);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(fake.removed, ['codex']);
    expect(fake.setUp, isEmpty);
    d.dispose();
  });

  testWidgets("Claude's Go agent: the switch sets it, and Claude then needs "
      'no set-up; off again, it does', (tester) async {
    final (fake, d) = await _settings(tester);
    expect(
      find.text('Runs Claude without Node. New and reopened chats use it.'),
      findsOneWidget,
    );
    // In line with Claude's name, under Claude's row.
    expect(
      tester.getRect(find.text("Use Nushi's Go agent")).left,
      tester.getRect(find.text('Claude')).left,
    );
    expect(
      tester.getRect(find.text("Use Nushi's Go agent")).top,
      greaterThan(tester.getRect(find.text('Not signed in')).bottom),
    );
    expect(
      tester.getRect(find.text("Use Nushi's Go agent")).bottom,
      lessThan(tester.getRect(find.text('Codex')).top),
    );
    expect(tester.widget<Switch>(_goSwitch).value, isFalse);
    expect(find.text('Set up'), findsOneWidget);
    final listed = fake.calls.whereType<ListAgentsRequest>().length;
    await tester.tap(_goSwitch);
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.claudeGoAgent, isTrue);
    expect(fake.setSettings.single.sleepAfterMinutes, 30); // the rest kept
    expect(fake.calls.whereType<ListAgentsRequest>().length, listed + 1);
    expect(tester.widget<Switch>(_goSwitch).value, isTrue);
    expect(find.text('Set up'), findsNothing);
    expect(find.text('Ready'), findsNWidgets(3)); // Claude, Ante, PiG
    await tester.tap(_goSwitch);
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.claudeGoAgent, isFalse);
    expect(find.text('Set up'), findsOneWidget);
    d.dispose();
  });

  testWidgets('no switch from a daemon without the setting', (tester) async {
    final fake = FakeDaemon([])..agents = _found;
    fake.settings.clearClaudeGoAgent();
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.agents);
    expect(find.text("Use Nushi's Go agent"), findsNothing);
    expect(find.text('Set up'), findsOneWidget);
    d.dispose();
  });

  testWidgets("the shell's environment: when it was read, and Reload", (
    tester,
  ) async {
    final (fake, d) = await _settings(
      tester,
      environment: ShellEnvironment(
        shell: '/opt/homebrew/bin/fish',
        readUnixMs: Int64(
          fixtureNow
              .subtract(const Duration(minutes: 3))
              .millisecondsSinceEpoch,
        ),
      ),
    );
    expect(
      find.text("Agents start with fish's environment, read 3m ago."),
      findsOneWidget,
    );
    expect(
      fake.calls.whereType<ListAgentsRequest>().last.refreshEnvironment,
      isTrue,
    );
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<ListAgentsRequest>().last;
    expect(asked.reloadEnvironment, isTrue);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // The shell didn't answer in time: said quietly, under the agents.
    testWidgets("the page, the shell's environment not read ($name)", (
      tester,
    ) async {
      final (_, d) = await _settings(
        tester,
        tokens: tokens,
        environment: ShellEnvironment(
          shell: '/opt/homebrew/bin/fish',
          readUnixMs: Int64(fixtureNow.millisecondsSinceEpoch),
          problem: 'fish took over 5s',
        ),
      );
      expect(
        find.text("Couldn't read your shell's environment: fish took over 5s."),
        findsOneWidget,
      );
      await expectLater(
        find.byType(SettingsView),
        matchesGoldenFile('goldens/agents_env_problem_$name.png'),
      );
      d.dispose();
    });

    // Claude's Go agent off (Set up, as today) and on (no adapter, nothing
    // to set up), in a wide window and a narrow one.
    for (final (size, sizeName) in [
      (const Size(1700, 900), 'wide'),
      (const Size(720, 760), 'narrow'),
    ]) {
      for (final on in [false, true]) {
        final state = on ? 'on' : 'off';
        testWidgets('the page, the Go agent $state, $sizeName ($name)', (
          tester,
        ) async {
          final (_, d) = await _settings(
            tester,
            tokens: tokens,
            goAgent: on,
            size: size,
          );
          final row = tester.getRect(find.byType(SettingsRow).first);
          expect(tester.getRect(_goSwitch).right, closeTo(row.right - 14, 1));
          expect(find.text('Set up'), on ? findsNothing : findsOneWidget);
          await expectLater(
            find.byType(SettingsView),
            matchesGoldenFile(
              'goldens/agents_go_${state}_${sizeName}_$name.png',
            ),
          );
          d.dispose();
        });
      }
    }

    // A chat that couldn't start Codex sent you here: its row stands out.
    testWidgets('the page, an agent marked ($name)', (tester) async {
      final (_, d) = await _settings(tester, tokens: tokens, agent: 'codex');
      await expectLater(
        find.byType(SettingsView),
        matchesGoldenFile('goldens/agents_marked_$name.png'),
      );
      d.dispose();
    });
  }
}
