import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

final _site = JiraSite(
  id: 'acme.atlassian.net',
  url: 'https://acme.atlassian.net',
  name: 'Test User',
  board: Int64(1),
  boardName: 'ACME board',
  searches: [JiraSearch(name: 'Bugs', jql: 'type = Bug')],
);

JiraIssue issue(String key, String summary, String status, String cat) =>
    JiraIssue(
      key: key,
      summary: summary,
      type: 'Task',
      status: status,
      statusCategory: cat,
      assignee: 'Test User',
      priority: 'Medium',
    );

/// The Jira view on a fake daemon with one site; what each list holds.
Future<(FakeDaemon, Daemon)> openView(
  WidgetTester tester, {
  List<JiraSite>? sites,
  Tokens tokens = Tokens.dark,
  Object? Function(Object input)? more,
}) async {
  final fake = FakeDaemon([])
    ..answer = (input) =>
        more?.call(input) ??
        switch (input) {
          ListJiraSitesRequest() => ListJiraSitesResponse(
            sites: sites ?? [_site],
          ),
          ListJiraIssuesRequest(list: 'mine') => ListJiraIssuesResponse(
            issues: [
              issue(
                'ACME-12',
                'Log in with a passkey',
                'In Progress',
                'indeterminate',
              ),
              issue(
                'ACME-9',
                'The sidebar flickers when a chat starts',
                'To Do',
                'new',
              ),
              issue('ACME-3', 'Write the release notes', 'Done', 'done'),
            ],
          ),
          ListJiraIssuesRequest(list: 'sprint') => ListJiraIssuesResponse(
            sprint: 'Sprint 4',
            issues: [
              issue(
                'ACME-12',
                'Log in with a passkey',
                'In Progress',
                'indeterminate',
              ),
            ],
          ),
          ListJiraIssuesRequest() => ListJiraIssuesResponse(
            issues: [issue('ACME-1', 'Found by JQL', 'To Do', 'new')],
          ),
          GetJiraIssueRequest(:final key) => GetJiraIssueResponse(
            issue: issue(
              key,
              'Log in with a passkey',
              'In Progress',
              'indeterminate',
            )..description = 'Let people sign in with a **passkey**.',
          ),
          GetJiraJqlRequest() => GetJiraJqlResponse(
            fields: [
              JiraJqlField(
                name: 'status',
                display: 'Status',
                operators: ['=', 'in'],
              ),
            ],
          ),
          _ => null,
        };
  final d = await fake.connect(tester);
  await tester.binding.setSurfaceSize(const Size(1000, 560));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(body: JiraView(d)),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

/// The issue the view shows.
String shown(WidgetTester tester) =>
    tester.widget<JiraIssuePane>(find.byType(JiraIssuePane)).issueKey;

/// Ends the view (its poll) and the daemon.
Future<void> closeView(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('my open issues, picked with the keys', (tester) async {
    final (_, d) = await openView(tester);
    // The row, and the issue beside it.
    expect(find.text('Log in with a passkey'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-9');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-12');
    await closeView(tester, d);
  });

  testWidgets('the sprint, a saved search, JQL', (tester) async {
    final (fake, d) = await openView(tester);
    await tester.tap(find.text('Sprint'));
    await tester.pumpAndSettle();
    expect(find.text('ACME board · Sprint 4'), findsOneWidget);
    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<ListJiraIssuesRequest>().last.jql,
      'type = Bug',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'project = ACME');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<ListJiraIssuesRequest>().last.jql,
      'project = ACME',
    );
    expect(find.text('Found by JQL'), findsOneWidget);
    await tester.tap(find.text('Save…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ACME');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = fake.calls.whereType<SetJiraSearchesRequest>().single;
    expect(saved.searches.map((s) => '${s.name}: ${s.jql}'), [
      'Bugs: type = Bug',
      'ACME: project = ACME',
    ]);
    await closeView(tester, d);
  });

  testWidgets('a list that fails says why', (tester) async {
    final (_, d) = await openView(
      tester,
      more: (input) => input is ListJiraIssuesRequest
          ? throw Exception('Jira asks to wait 30s before more requests')
          : null,
    );
    expect(find.textContaining('Jira asks to wait'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('no site yet', (tester) async {
    final (_, d) = await openView(tester, sites: []);
    expect(
      find.textContaining('Settings › Jira', findRichText: true),
      findsOneWidget,
    );
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d) = await openView(tester, tokens: tokens);
      await expectLater(
        find.byType(JiraView),
        matchesGoldenFile('goldens/jira_view_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
