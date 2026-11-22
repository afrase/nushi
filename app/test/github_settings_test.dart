import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

List<GitHubBucket> _budget() {
  // "resets in 42m": the page reads the clock.
  final reset = Int64(
    fixtureNow
        .add(const Duration(minutes: 42, seconds: 30))
        .millisecondsSinceEpoch,
  );
  return [
    GitHubBucket(name: 'core', limit: 5000, remaining: 4980, resetMs: reset),
    GitHubBucket(name: 'graphql', limit: 5000, remaining: 4875, resetMs: reset),
    GitHubBucket(name: 'search', limit: 30, remaining: 30, resetMs: reset),
  ];
}

List<GitHubHost> _hosts() => [
  GitHubHost(
    host: 'github.com',
    login: 'octo',
    name: 'Octo Cat',
    source: 'gh',
    kind: 'oauth',
    scopes: ['gist', 'read:org', 'repo', 'workflow'],
    budget: _budget(),
  ),
  GitHubHost(
    host: 'git.corp.example',
    source: 'token',
    pasted: true,
    needsOk: true,
    problem: 'this build of Nushi needs your OK to read the GitHub token',
  ),
];

Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester, {
  List<GitHubHost>? hosts,
  Tokens tokens = Tokens.dark,
  String tokenKept = '',
  Size size = const Size(1000, 760),
}) async {
  final fake = FakeDaemon([]);
  var list = hosts ?? _hosts();
  fake.answer = (input) => switch (input) {
    ListGitHubHostsRequest() => ListGitHubHostsResponse(hosts: list),
    AddGitHubTokenRequest(:final token) when token != 'ghp_good' =>
      throw ConnectException(
        Code.failedPrecondition,
        'GitHub refused the token: wrong, revoked or expired',
      ),
    AddGitHubTokenRequest(:final host) => () {
      list = [
        ...list,
        GitHubHost(host: host, login: 'octo', source: 'token', pasted: true),
      ];
      return AddGitHubTokenResponse();
    }(),
    RemoveGitHubTokenRequest(:final host) => () {
      list = [...list.where((h) => h.host != host)];
      return RemoveGitHubTokenResponse(tokenKept: tokenKept);
    }(),
    _ => null,
  };
  final d = await fake.connect(tester);
  await pumpSettings(
    tester,
    d,
    SettingsSection.github,
    tokens: tokens,
    size: size,
  );
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  test('the budget line', () {
    final now = DateTime(2026, 10, 26, 12);
    final h = GitHubHost(
      budget: [
        GitHubBucket(name: 'core', limit: 5000, remaining: 10),
        GitHubBucket(
          name: 'graphql',
          limit: 5000,
          remaining: 4000,
          resetMs: Int64(
            now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
          ),
        ),
      ],
    );
    expect(
      budgetLine(h, now),
      'Left this hour: REST 10 of 5000 · GraphQL 4000 of 5000 '
      '(GraphQL resets in 5m)',
    );
    expect(budgetLine(GitHubHost(), now), '');
  });

  testWidgets('each host with who its token is, where it is from, and '
      'its budget', (tester) async {
    final (fake, d) = await _open(tester);
    expect(find.text('github.com'), findsOneWidget);
    // Who and from where in the row, its state in a pill.
    expect(find.text("octo (Octo Cat) · from gh's login"), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-state-github.com')),
        matching: find.text('Signed in'),
      ),
      findsOne,
    );
    // What's left this hour is on the row, which people check; the
    // jargon is behind ⋯: the token's kind and scopes.
    expect(find.textContaining('GraphQL 4875 of 5000'), findsOneWidget);
    expect(find.textContaining('OAuth'), findsNothing);
    expect(find.textContaining('needs your OK'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-more-github.com')));
    await tester.pumpAndSettle();
    expect(
      find.text('OAuth token · scopes gist, read:org, repo, workflow'),
      findsOneWidget,
    );
    // gh's login can't be removed here; a pasted token can.
    expect(find.text('Remove token…'), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // the menu shuts
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow…'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<AllowGitHubTokenRequest>().single.host,
      'git.corp.example',
    );
    await tester.tap(
      find.byKey(const ValueKey('account-more-git.corp.example')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove token…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Remove').last);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<RemoveGitHubTokenRequest>().single.host,
      'git.corp.example',
    );
    d.dispose();
  });

  Future<void> removePasted(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('account-more-git.corp.example')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove token…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Remove').last);
    await tester.pumpAndSettle();
  }

  for (final width in [1700.0, 720.0]) {
    testWidgets('a token the keychain kept is said, plainly, with its '
        'item, ${width.toInt()} wide', (tester) async {
      final (_, d) = await _open(
        tester,
        tokenKept: 'Nushi: GitHub token for git.corp.example',
        size: Size(width, 760),
      );
      await removePasted(tester);
      // The list reloads as on any removal, and the note says where the
      // token is left.
      expect(find.text('git.corp.example'), findsNothing);
      final note = find.text(
        'Removed. Its token is still in your keychain as '
        '“Nushi: GitHub token for git.corp.example”: delete it there.',
      );
      expect(note, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('token-kept')),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(MaterialApp),
        'github_settings_token_kept_${width.toInt()}',
      );
      // It stays 30 s, not the 4 s of a passing note, or until dismissed.
      await tester.pump(const Duration(seconds: 10));
      expect(note, findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(note, findsNothing);
      d.dispose();
    });
  }

  testWidgets('a token the keychain deleted, or an older daemon, says '
      'nothing more', (tester) async {
    final (_, d) = await _open(tester);
    await removePasted(tester);
    expect(find.text('git.corp.example'), findsNothing);
    expect(find.byKey(const ValueKey('token-kept')), findsNothing);
    expect(find.textContaining('still in your'), findsNothing);
    d.dispose();
  });

  testWidgets('hosts not listed while the daemon was gone are listed once '
      'it is back', (tester) async {
    var fail = true;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        ListGitHubHostsRequest() when fail => throw ConnectException(
          Code.unavailable,
          'daemon unavailable: connection lost',
        ),
        ListGitHubHostsRequest() => ListGitHubHostsResponse(hosts: _hosts()),
        _ => null,
      };
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.github);
    expect(find.text('daemon unavailable: connection lost'), findsOneWidget);
    fail = false;
    await fake.restart(tester);
    expect(find.text('github.com'), findsOneWidget);
    expect(find.text('daemon unavailable: connection lost'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('adding a token checks it with GitHub', (tester) async {
    final (fake, d) = await _open(tester, hosts: []);
    // No host yet: the form is open.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'git.corp.example');
    await tester.enterText(fields.at(1), 'bad');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GitHub refused'), findsOneWidget);
    await tester.enterText(fields.at(1), 'ghp_good');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final add = fake.calls.whereType<AddGitHubTokenRequest>().last;
    expect(add.host, 'git.corp.example');
    expect(find.text('git.corp.example'), findsOneWidget);
    expect(find.text('Add a token'), findsOneWidget);
    d.dispose();
  });

  testWidgets('a token added in Settings is a host the GitHub views know '
      'at once; a removed one is not', (tester) async {
    final (fake, d) = await _open(tester, hosts: [_hosts().first]);
    final items = GitHubItems.of(d);
    expect(items.knows('git.corp.example'), isFalse);
    await tester.pumpAndSettle();
    expect(items.knows('github.com'), isTrue);
    expect(items.knows('git.corp.example'), isFalse);
    await tester.tap(find.text('Add a token'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'git.corp.example');
    await tester.enterText(fields.at(1), 'ghp_good');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(items.knows('git.corp.example'), isTrue);
    await tester.tap(
      find.byKey(const ValueKey('account-more-git.corp.example')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove token…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Remove').last);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<RemoveGitHubTokenRequest>(), hasLength(1));
    expect(items.knows('git.corp.example'), isFalse);
    d.dispose();
  });

  testWidgets('hosts asked for while a listing runs are listed again '
      'after it', (tester) async {
    final first = Completer<ListGitHubHostsResponse>();
    var asked = 0;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        ListGitHubHostsRequest() when ++asked == 1 => first.future,
        ListGitHubHostsRequest() => ListGitHubHostsResponse(hosts: _hosts()),
        _ => null,
      };
    final d = await fake.connect(tester);
    final hosts = GitHubHosts.of(d);
    final a = hosts.load();
    // A token added since the first was sent: the second waits, then
    // lists again; a third meanwhile shares the second.
    final b = hosts.load();
    final c = hosts.load();
    first.complete(ListGitHubHostsResponse(hosts: [_hosts().first]));
    await tester.runAsync(() => Future.wait([a, b, c]));
    expect(asked, 2);
    expect(hosts.known, {'github.com', 'git.corp.example'});
    d.dispose();
  });

  testWidgets('a host listed with another login changes who I am there', (
    tester,
  ) async {
    // Replacing github.com's token with another account's, while Nushi
    // runs: its pull requests' review dialog asks who I am.
    final fake = FakeDaemon([]);
    var login = 'octo';
    fake.answer = (input) => switch (input) {
      ListGitHubHostsRequest() => ListGitHubHostsResponse(
        hosts: [GitHubHost(host: 'github.com', login: login, pasted: true)],
      ),
      _ => null,
    };
    final d = await fake.connect(tester);
    expect(await githubLogin(d, 'github.com'), 'octo');
    login = 'other';
    await pumpSettings(tester, d, SettingsSection.github);
    expect(find.textContaining('other'), findsOneWidget);
    expect(await githubLogin(d, 'github.com'), 'other');
    d.dispose();
  });
}
