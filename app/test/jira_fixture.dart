import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The tests' Jira site.
final testSite = JiraSite(
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

/// The Jira view on a fake daemon with one site; what each list holds. In
/// the app's window with [window], else on its own.
Future<(FakeDaemon, Daemon)> openView(
  WidgetTester tester, {
  List<JiraSite>? sites,
  List<Chat> chats = const [],
  Size size = const Size(1000, 560),
  Tokens tokens = Tokens.dark,
  Object? Function(Object input)? more,
  Map<String, List<String>> groups = const {},
  Map<String, List<String>> collapsed = const {},
  bool window = false,
}) async {
  // As app.json had them at launch.
  jiraGroupOrder.value = groups;
  jiraCollapsed.value = collapsed;
  final fake = FakeDaemon(chats)
    ..answer = (input) =>
        more?.call(input) ??
        switch (input) {
          ListJiraSitesRequest() => ListJiraSitesResponse(
            sites: sites ?? [testSite],
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
  forgetJiraView(); // it keeps what it had while the app runs
  await tester.binding.setSurfaceSize(size);
  if (window) {
    // The window on the view, the sidebar hidden (it has its own goldens).
    viewport(
      tester,
      size,
      brightness: tokens == Tokens.dark ? Brightness.dark : Brightness.light,
    );
    sidebarHidden.value = true;
    d.go(const JiraPlace());
    await tester.pumpWidget(NushiApp(daemon: d));
  } else {
    clock = () => DateTime(2026, 10, 25, 12);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: NushiTheme(tokens).toThemeData(),
        home: Scaffold(body: JiraView(d)),
      ),
    );
  }
  await tester.pumpAndSettle();
  return (fake, d);
}

/// The issue the view shows.
String shown(WidgetTester tester) =>
    tester.widget<JiraIssuePane>(find.byType(JiraIssuePane)).issueKey;
