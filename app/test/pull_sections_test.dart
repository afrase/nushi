import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets("Activity: a review's findings and threads point at To do; its "
      "resolved threads one line; a bot's numbers muted", (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    await tester.tap(find.text('Activity 4'));
    await tester.pumpAndSettle();
    githubFindings.value = true;
    await tester.pumpAndSettle();
    expect(find.text('2 findings to address · in To do'), findsOneWidget);
    expect(find.text('2 unresolved threads · in To do'), findsOneWidget);
    expect(find.text('Requested changes'), findsOneWidget);
    // The review's last line, its numbers, apart and muted.
    expect(find.text(r'claude-opus · $2.61 · 10m 31s'), findsOneWidget);
    expect(
      find.textContaining('nit, .presence reads better here · afrase: Done.'),
      findsOneWidget,
    );
    expect(find.text('Markdown · posts to GitHub as afrase'), findsOneWidget);
    await tester.tap(find.text('2 unresolved threads · in To do'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('To do')).top, lessThan(100));
    d.dispose();
  }, variant: _mac);

  testWidgets('Checks: what they came to, Re-run failed, the passed in two '
      'columns', (tester) async {
    final (d, fake) = await openPullTab(
      tester,
      fixturePull()
        ..checks.addAll([
          for (var i = 0; i < 10; i++) check('lint $i', id: 100 + i),
        ]),
      more: (input) => input is RerunGitHubChecksRequest
          ? RerunGitHubChecksResponse(runs: 1)
          : null,
    );
    await tester.tap(find.text('Checks · 3 failing'));
    await tester.pumpAndSettle();
    expect(find.text('Passed · 18'), findsOneWidget);
    expect(find.text('Show 6 more'), findsOneWidget);
    // Two columns: the second check beside the first.
    final a = tester.getRect(find.text('CI / rspec (admin 1/8)'));
    final b = tester.getRect(find.text('CI / rspec (admin 2/8)'));
    expect((b.top - a.top).abs(), lessThan(1));
    expect(b.left, greaterThan(a.right));
    await tester.tap(find.text('Re-run failed'));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<RerunGitHubChecksRequest>().single;
    expect(asked.jobs.map((j) => j.toInt()), [31, 32, 33]);
    expect(
      find.text('Re-running the failed jobs of 1 workflow run'),
      findsOneWidget,
    );
    expect(checkTook(GitHubCheck()), '');
    expect(
      checkTook(
        GitHubCheck(startedMs: Int64(1000), completedMs: Int64(253000)),
      ),
      '4m 12s',
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('Files: those with review threads not resolved first', (
    tester,
  ) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    await tester.tap(find.text('Files 12'));
    await tester.pumpAndSettle();
    expect(find.text('With unresolved threads · 2'), findsOneWidget);
    final records = tester.getRect(find.text('notes_controller.rb'));
    final spec = tester.getRect(find.text('page_spec.rb'));
    final helper = tester.getRect(find.text('search_helper.rb'));
    expect(records.top, lessThan(helper.top));
    expect(spec.top, lessThan(helper.top));
    d.dispose();
  }, variant: _mac);

  testWidgets("Checks: an open failed check's log stays with its check when "
      'the checks change, and a failed fetch is tried again', (tester) async {
    var refuse = true;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetGitHubJobLogRequest() when refuse => throw StateError('down'),
        GetGitHubJobLogRequest(:final job) => GetGitHubJobLogResponse(
          tail: 'LOG OF JOB $job',
        ),
        _ => null,
      };
    final d = await fake.connect(tester);
    GitHubPull pull(List<GitHubCheck> checks) => GitHubPull(
      item: GitHubItem(
        ref: GitHubRef(host: 'h', repo: 'o/r', number: 1),
      ),
      checks: checks,
    );
    Widget at(GitHubPull p) => MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GitHubChecks(daemon: d, pull: p),
        ),
      ),
    );
    GitHubCheck failed(int id, String name) =>
        GitHubCheck(id: Int64(id), name: name, state: 'failure', failed: true);
    await tester.pumpWidget(at(pull([failed(1, 'lint')])));
    await tester.tap(find.text('lint'));
    await tester.pumpAndSettle();
    expect(find.text('Bad state: down'), findsOneWidget);
    // Closed and opened again: asked again, and the error goes.
    refuse = false;
    await tester.tap(find.text('lint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lint'));
    await tester.pumpAndSettle();
    expect(find.text('Bad state: down'), findsNothing);
    expect(find.text('LOG OF JOB 1'), findsOneWidget);
    // A push: lint passes, test (another job) fails in lint's place.
    await tester.pumpWidget(
      at(
        pull([
          failed(2, 'test'),
          GitHubCheck(id: Int64(3), name: 'lint', state: 'success'),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LOG OF JOB 1'), findsNothing);
    await closeView(tester, d);
  });
}
