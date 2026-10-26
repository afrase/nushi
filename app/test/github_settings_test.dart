import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

List<GitHubBucket> _budget() {
  // "resets in 42m" whenever it runs: the page reads the clock.
  final reset = Int64(
    DateTime.now()
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
      return AddGitHubTokenResponse(login: 'octo');
    }(),
    _ => null,
  };
  final d = await fake.connect(tester);
  await tester.binding.setSurfaceSize(const Size(640, 640));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showSettings(context, d.client, github: true),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

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
    expect(find.text('Signed in as octo (Octo Cat)'), findsOneWidget);
    expect(
      find.text(
        "From gh's login · OAuth token · scopes gist, read:org, repo, workflow",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('GraphQL 4875 of 5000'), findsOneWidget);
    expect(find.textContaining('needs your OK'), findsOneWidget);
    // gh's login can't be removed here; a pasted token can.
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Allow…'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<AllowGitHubTokenRequest>().single.host,
      'git.corp.example',
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Remove').last);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<RemoveGitHubTokenRequest>().single.host,
      'git.corp.example',
    );
    d.dispose();
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

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d) = await _open(tester, tokens: tokens);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/github_settings_$name.png'),
      );
      d.dispose();
    });
  }
}
