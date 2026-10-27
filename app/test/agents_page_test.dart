import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
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
}) async {
  final fake = FakeDaemon([])
    ..agents = _found
    ..environment = environment;
  final d = await fake.connect(tester);
  await pumpSettings(
    tester,
    d,
    SettingsSection.agents,
    tokens: tokens,
    agent: agent,
  );
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    shellEnvironment.value = null; // as a test before left it
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

  testWidgets("the shell's environment: when it was read, and Reload", (
    tester,
  ) async {
    final (fake, d) = await _settings(
      tester,
      environment: ShellEnvironment(
        shell: '/opt/homebrew/bin/fish',
        readUnixMs: Int64(
          DateTime.now()
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
          readUnixMs: Int64(DateTime.now().millisecondsSinceEpoch),
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
