import 'dart:async';

import 'package:fixnum/fixnum.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents_page.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// Codex's adapter, pinned at 2.2.2, with [installed] set up.
Adapter _codexAdapter(String installed) => Adapter(
  package: '@agentclientprotocol/codex-acp',
  pinned: '2.2.2',
  installed: installed,
  packages: 107,
  downloadBytes: Int64(2337235),
  diskBytes: Int64(18599936),
  folder: '/Users/me/Library/Application Support/Nushi/agents/codex',
);

/// Claude ready (through the Go agent: nothing to set up) but not signed
/// in, Codex set up with a newer adapter pinned and a chat awake (and the
/// switch for its Go agent), Ante
/// ready, oh-my-pi missing, PiG ready.
final _found = [
  Agent(
    name: 'claude',
    title: 'Claude',
    path: '/opt/homebrew/bin/claude',
    version: '2.1.310',
    signedIn: 'no',
    ready: true,
  ),
  Agent(
    name: 'codex',
    title: 'Codex',
    path: '/opt/homebrew/bin/codex',
    version: '0.163.0',
    ready: true,
    awake: 1,
    adapter: _codexAdapter('2.2.1'),
    goAgentSwitch: true,
  ),
  Agent(
    name: 'ante',
    title: 'Ante',
    path: '/Users/me/.ante/bin/ante',
    version: '0.2.14',
    ready: true,
  ),
  Agent(name: 'omp', title: 'oh-my-pi', problem: 'Not installed'),
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
  bool codexSetUp = true,
  bool? goAgent = false, // null: a daemon without go_agents (API 142)
  Size size = const Size(1000, 760),
  void Function(FakeDaemon)? daemon, // more of the daemon, before it connects
}) async {
  final fake = FakeDaemon([])
    ..agents = [
      for (final a in _found)
        if (a.name == 'codex' && !codexSetUp)
          a.deepCopy()
            ..adapter = _codexAdapter('')
            ..ready = false
            ..awake = 0
        else
          a,
    ]
    ..environment = environment;
  if (goAgent != null) fake.settings.goAgents['codex'] = goAgent;
  daemon?.call(fake);
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

/// The switch's words for Codex, as Settings › Agents has them.
const _goLabel = 'Run Codex without Node';
const _goDescription =
    "New: Nushi's built-in agent instead of its adapter. "
    'Chats use it from their next start.';

/// Settings › Agents' switch for Codex's Go agent.
Finder get _goSwitch => find.descendant(
  of: find.ancestor(
    of: find.text(_goLabel),
    matching: find.byType(SettingsRow),
  ),
  matching: find.byType(SettingsSwitch),
);

void main() {
  setUpAll(loadFonts);

  testWidgets('each agent as found, and what can be done', (tester) async {
    final (_, d) = await _settings(tester);
    expect(find.text('2.1.310 · /opt/homebrew/bin/claude'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Set up'), findsNothing); // Claude needs none
    expect(find.text('Adapter 2.2.1'), findsOneWidget);
    expect(find.text('Update to 2.2.2'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(3)); // Claude, Ante, PiG
    expect(find.text('0.5.3 · /Users/me/.local/bin/pig'), findsOneWidget);
    expect(find.text('Not installed'), findsOneWidget);
    d.dispose();
  });

  testWidgets('Set up says what it downloads, then installs it', (
    tester,
  ) async {
    final (fake, d) = await _settings(tester, codexSetUp: false);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Downloads @agentclientprotocol/codex-acp 2.2.2 and the 106 '
        'packages it needs from npm, about 2 MB (19 MB on disk), into '
        '/Users/me/Library/Application Support/Nushi/agents/codex.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Set up').last);
    await tester.pumpAndSettle();
    expect(fake.setUp, ['codex']);
    expect(find.text('Set up Codex'), findsNothing); // the sheet closed
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

  testWidgets('Remove keeps its place and width while it reads Removing…', (
    tester,
  ) async {
    final (fake, d) = await _settings(tester);
    final held = Completer<RemoveAgentResponse>();
    fake.on((input) => input is RemoveAgentRequest ? held.future : null);
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    final rest = tester.getRect(button('Remove'));
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pump();
    expect(tester.getRect(button('Removing…')), rest);
    held.complete(RemoveAgentResponse());
    await tester.pumpAndSettle();
    expect(fake.removed, ['codex']);
    expect(tester.getRect(button('Remove')), rest);
    d.dispose();
  });

  testWidgets("Codex's Go agent: the switch sets it, and Codex then needs "
      'no adapter; off again, it does', (tester) async {
    final (fake, d) = await _settings(tester, codexSetUp: false);
    expect(find.text(_goDescription), findsOneWidget);
    // In line with Codex's name, under Codex's row, above Ante's.
    expect(
      tester.getRect(find.text(_goLabel)).left,
      tester.getRect(find.text('Codex')).left,
    );
    expect(
      tester.getRect(find.text(_goLabel)).top,
      greaterThan(tester.getRect(find.byType(AgentRow).at(1)).bottom - 1),
    );
    expect(
      tester.getRect(find.text(_goLabel)).bottom,
      lessThan(tester.getRect(find.text('Ante')).top),
    );
    expect(tester.widget<SettingsSwitch>(_goSwitch).value, isFalse);
    expect(find.text('Set up'), findsOneWidget);
    final at = tester.getRect(_goSwitch);
    final listed = fake.calls.whereType<ListAgentsRequest>().length;
    await tester.tap(_goSwitch);
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.goAgents['codex'], isTrue);
    expect(fake.setSettings.single.sleepAfterMinutes, 30); // the rest kept
    expect(fake.calls.whereType<ListAgentsRequest>().length, listed + 1);
    expect(tester.widget<SettingsSwitch>(_goSwitch).value, isTrue);
    expect(tester.getRect(_goSwitch), at); // the switch stays put
    // Its words stay too, as Codex is now listed with no adapter.
    expect(find.text(_goDescription), findsOneWidget);
    expect(find.text('Set up'), findsNothing);
    expect(find.text('Ready'), findsNWidgets(4)); // Claude, Codex, Ante, PiG
    await tester.tap(_goSwitch);
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.goAgents['codex'], isFalse);
    expect(find.text('Set up'), findsOneWidget);
    d.dispose();
  });

  testWidgets('no switch from a daemon without go_agents', (tester) async {
    // A daemon before API 142 keeps only Codex's, by its old field.
    final (_, d) = await _settings(
      tester,
      goAgent: null,
      daemon: (fake) => fake.settings.codexGoAgent = false,
    );
    expect(find.text(_goLabel), findsNothing);
    expect(find.text('Adapter 2.2.1'), findsOneWidget);
    d.dispose();
  });

  testWidgets('each agent with the switch has its own, in its words', (
    tester,
  ) async {
    final (fake, d) = await _settings(
      tester,
      daemon: (fake) => fake
        ..agents = [
          for (final a in fake.agents)
            if (a.name == 'pig') a.deepCopy()..goAgentSwitch = true else a,
        ]
        ..settings.goAgents['pig'] = false,
    );
    expect(find.text(_goLabel), findsOneWidget);
    expect(find.text('Run PiG without Node'), findsOneWidget);
    expect(find.text(_goDescription), findsNWidgets(2)); // Codex's and PiG's
    final pig = find.descendant(
      of: find.ancestor(
        of: find.text('Run PiG without Node'),
        matching: find.byType(SettingsRow),
      ),
      matching: find.byType(SettingsSwitch),
    );
    await tester.tap(pig);
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.goAgents, {'codex': false, 'pig': true});
    expect(tester.widget<SettingsSwitch>(pig).value, isTrue);
    expect(tester.widget<SettingsSwitch>(_goSwitch).value, isFalse);
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

    // Claude through the Go agent, with no Set up in its row, beside
    // Codex's adapter to update, in a wide window and a narrow one.
    for (final (size, sizeName) in [
      (const Size(1700, 900), 'wide'),
      (const Size(720, 760), 'narrow'),
    ]) {
      testWidgets('the page, $sizeName ($name)', (tester) async {
        final (_, d) = await _settings(tester, tokens: tokens, size: size);
        final claude = tester.getRect(find.byType(AgentRow).first);
        // Ready is a pill now, as every state in Settings: its edge at
        // the row's, where the actions end.
        final ready = tester.getRect(
          find.widgetWithText(NotePill, 'Ready').first,
        );
        expect(ready.right, closeTo(claude.right - 14, 1));
        expect(ready.top, lessThan(claude.center.dy)); // Claude's own row
        expect(find.text('Set up'), findsNothing);
        expect(
          tester.getRect(find.text('Update to 2.2.2')).right,
          lessThanOrEqualTo(claude.right - 14 + 0.5),
        );
        expect(tester.getRect(_goSwitch).right, closeTo(claude.right - 14, 1));
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(SettingsView),
          'agents_${sizeName}_$name',
        );
        await expectLater(
          find.byType(SettingsView),
          matchesGoldenFile('goldens/agents_${sizeName}_$name.png'),
        );
        d.dispose();
      });
    }

    // Codex's Go agent on: no adapter or Set up under Codex, its switch
    // on, at the row's edge, in a wide window and a narrow one. Rendered
    // to look at, not kept as goldens.
    for (final (size, sizeName) in [
      (const Size(1700, 900), 'wide'),
      (const Size(720, 760), 'narrow'),
    ]) {
      if (!lightCopy(tokens.brightness)) {
        testWidgets('the page, the Go agent on, $sizeName ($name)', (
          tester,
        ) async {
          final (_, d) = await _settings(
            tester,
            tokens: tokens,
            goAgent: true,
            size: size,
          );
          final row = tester.getRect(find.byType(SettingsRow).first);
          expect(tester.getRect(_goSwitch).right, closeTo(row.right - 14, 1));
          expect(tester.widget<SettingsSwitch>(_goSwitch).value, isTrue);
          expect(find.text('Update to 2.2.2'), findsNothing);
          expectTextInside(tester, size.width);
          await render(
            tester,
            find.byType(SettingsView),
            'agents_go_on_${sizeName}_$name',
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
