// Every section of Settings over the whole app, at 1700, 900 and 720 wide,
// in both themes, to look at (not compared, not part of make test):
// NUSHI_RENDERS=<folder> flutter test test/screenshots/settings_shots.dart
// writes <section>-<width>-<theme>.png there, tall-<section>.png, each
// page whole in a tall window, and state-<what>-<width>-<theme>.png, the
// states the plain data doesn't show (no account, a menu open, Remote
// access on…). The data is settingsFake's, made up. GitHub's and Jira's
// pages are opened first, as a launch would, so the nav has its dots.
import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/usage_range.dart';

import '../fake_app_install.dart';
import '../fake_daemon.dart' show FakeDaemon, loadFonts;
import '../harness.dart';
import '../settings_harness.dart';
import '../spell_harness.dart' show FakeSpeller;
import '../usage_fixtures.dart';

const _sizes = [
  (Size(1700, 1000), '1700'),
  (Size(900, 760), '900'),
  (Size(720, 900), '720'),
];
const List<(Brightness, String)> _themes = [
  (Brightness.dark, 'dark'),
  (Brightness.light, 'light'),
];

/// Settings in the whole app at [s], GitHub's and Jira's pages seen first.
Future<Daemon> _open(
  WidgetTester tester,
  FakeDaemon fake,
  SettingsSection s,
  Size size,
  Brightness brightness,
) async {
  native.speller = FakeSpeller({});
  // One reply card's words changed, as the mocks show it.
  cardAsks.value = {
    'changes': 'Make the changes this review asks for here; commit.',
  };
  final d = await pumpSettingsApp(
    tester,
    fake,
    SettingsSection.github,
    size: size,
    brightness: brightness,
  );
  for (final next in [SettingsSection.jira, s]) {
    d.openSettings(section: next);
    await tester.pumpAndSettle();
  }
  return d;
}

/// [fake] answering [over] first, the rest as before.
FakeDaemon _with(FakeDaemon fake, Object? Function(Object input) over) =>
    fake..on(over);

/// The states the plain data doesn't show: each one's section, its fake,
/// and what's done before the shot (a menu opened).
final Map<
  String,
  (SettingsSection, FakeDaemon Function(), Future<void> Function(WidgetTester)?)
>
_states = {
  'github-none': (
    SettingsSection.github,
    () => _with(
      settingsFake(),
      (i) => i is ListGitHubHostsRequest ? ListGitHubHostsResponse() : null,
    ),
    null,
  ),
  'github-problems': (
    SettingsSection.github,
    () => _with(
      settingsFake(),
      (i) => i is ListGitHubHostsRequest
          ? ListGitHubHostsResponse(
              hosts: [
                GitHubHost(
                  host: 'github.com',
                  source: 'gh',
                  problem: 'GitHub turned the token down: it was revoked',
                ),
                GitHubHost(
                  host: 'git.corp.example',
                  pasted: true,
                  needsOk: true,
                ),
              ],
            )
          : null,
    ),
    null,
  ),
  'github-menu': (
    SettingsSection.github,
    settingsFake,
    (tester) => _tap(tester, const ValueKey('account-more-github.com')),
  ),
  'jira-menu': (
    SettingsSection.jira,
    settingsFake,
    (tester) => _tap(tester, const ValueKey('account-more-acme.atlassian.net')),
  ),
  'jira-refused': (
    SettingsSection.jira,
    () => _with(
      settingsFake(),
      (i) => i is CheckJiraSiteRequest
          ? throw ConnectException(
              Code.unauthenticated,
              'Jira turned the token down',
            )
          : null,
    ),
    null,
  ),
  'remote-on': (
    SettingsSection.remote,
    () {
      final fake = settingsFake();
      final on = Remote(
        relay: 'wss://relay.example.com',
        on: true,
        state: 'connected',
        key: List.filled(32, 9),
      );
      remoteState.value = on;
      return _with(
        fake,
        (i) => i is GetRemoteRequest ? GetRemoteResponse(remote: on) : null,
      );
    },
    null,
  ),
  'agents-env': (
    SettingsSection.agents,
    () => settingsFake()
      ..environment = ShellEnvironment(
        shell: '/opt/homebrew/bin/fish',
        readUnixMs: Int64(
          fixtureNow
              .subtract(const Duration(minutes: 3))
              .millisecondsSinceEpoch,
        ),
      ),
    null,
  ),
  'general-login': (SettingsSection.general, () => _login('enabled'), null),
  'general-login-waiting': (
    SettingsSection.general,
    () => _login('requiresApproval'),
    null,
  ),
  'appearance-yours': (SettingsSection.appearance, _yours, null),
  'usage-busy': (
    SettingsSection.usage,
    () => settingsFake()..usage = busyUsage(),
    null,
  ),
  'usage-quarter': (
    SettingsSection.usage,
    () {
      usageRange.value = UsageRange.quarter;
      return settingsFake()..usage = quarterUsage();
    },
    null,
  ),
  'usage-empty': (
    SettingsSection.usage,
    () => settingsFake()..usage = emptyUsage(),
    null,
  ),
  'usage-nocost': (
    SettingsSection.usage,
    () => settingsFake()..usage = noCostUsage(),
    null,
  ),
};

/// A packaged daemon and its login item in [status], as the Mac answers.
FakeDaemon _login(String status) {
  (native.install as FakeAppInstall).daemon = '/Applications/nushid';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('nushi/login');
  messenger.setMockMethodCallHandler(channel, (_) async => status);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return settingsFake();
}

/// A theme of the user's, in the test's own data folder.
FakeDaemon _yours() {
  final dir = themeFiles.dir..createSync(recursive: true);
  addTearDown(() async {
    await themeFiles.forget();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  File('${dir.path}/Harbor.json').writeAsStringSync(
    '{"name": "Harbor", "from": "nord", '
    '"dark": {"base": "#14202C"}, "light": {"accent": "#0B7A75"}}',
  );
  themeFiles.load();
  return settingsFake();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  for (final s in SettingsSection.values) {
    for (final (size, width) in _sizes) {
      for (final (brightness, theme) in _themes) {
        testWidgets('${s.name} $width $theme', (tester) async {
          final d = await _open(tester, settingsFake(), s, size, brightness);
          expect(tester.takeException(), isNull);
          await render(
            tester,
            find.byType(MaterialApp),
            '${s.name}-$width-$theme',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
    testWidgets('${s.name} whole', (tester) async {
      final d = await _open(
        tester,
        settingsFake(),
        s,
        const Size(1300, 2200),
        Brightness.dark,
      );
      await render(tester, find.byType(MaterialApp), 'tall-${s.name}');
      await closeView(tester, d);
    }, variant: onMac);
  }

  for (final MapEntry(key: name, value: (s, make, before)) in _states.entries) {
    for (final (size, width) in _sizes.take(2)) {
      for (final (brightness, theme) in _themes) {
        testWidgets('$name $width $theme', (tester) async {
          final d = await _open(tester, make(), s, size, brightness);
          await before?.call(tester);
          expect(tester.takeException(), isNull);
          await render(
            tester,
            find.byType(MaterialApp),
            'state-$name-$width-$theme',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }

  // Usage's pages whole, as tall as their content, at both widths.
  for (final name in ['usage-busy', 'usage-nocost']) {
    for (final (size, width) in _sizes.take(2)) {
      for (final (brightness, theme) in _themes) {
        testWidgets('$name whole $width $theme', (tester) async {
          final (s, make, _) = _states[name]!;
          final d = await _open(
            tester,
            make(),
            s,
            Size(size.width, 2300),
            brightness,
          );
          expect(tester.takeException(), isNull);
          await render(
            tester,
            find.byType(MaterialApp),
            'tall-$name-$width-$theme',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }

  for (final (size, width) in _sizes.take(2)) {
    for (final (brightness, theme) in _themes) {
      testWidgets('a reply card ask in its editor, $width $theme', (
        tester,
      ) async {
        final d = await _open(
          tester,
          settingsFake(),
          SettingsSection.github,
          size,
          brightness,
        );
        await _tap(tester, const ValueKey('card-ask-edit-thread'));
        await render(
          tester,
          find.byType(MaterialApp),
          'github-ask-editor-$width-$theme',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
