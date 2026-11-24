import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_bar.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/pull_polls.dart';

import 'github_fixture.dart' as gh;
import 'harness.dart';
import 'jira_fixture.dart' as jira;

/// The window to the back (focus elsewhere), put back in front after the
/// test.
void _toBack(WidgetTester tester) {
  addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
}

void _toFront(WidgetTester tester) =>
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  testWidgets('a view poll asks each wait while seen; in the back or '
      'covered, never; back in front, once', (tester) async {
    var asks = 0;
    var covered = false;
    final poll = viewPoll(
      () => const Duration(minutes: 1),
      () => asks++,
      hidden: () => covered,
    );
    await tester.pump(const Duration(minutes: 2));
    expect(asks, 2);
    _toBack(tester);
    await tester.pump(const Duration(minutes: 10));
    expect(asks, 2);
    _toFront(tester);
    await tester.pump();
    expect(asks, 3); // the one catch-up
    await tester.pump(const Duration(seconds: 59));
    expect(asks, 3); // its wait starts afresh
    await tester.pump(const Duration(seconds: 1));
    expect(asks, 4);
    // Covered: nothing, and nothing to catch up when it's back in front.
    covered = true;
    await tester.pump(const Duration(minutes: 3));
    _toBack(tester);
    await tester.pump(const Duration(minutes: 3));
    _toFront(tester);
    await tester.pump();
    expect(asks, 4);
    // In the back for less than a wait: nothing missed, nothing asked.
    covered = false;
    _toBack(tester);
    await tester.pump(const Duration(seconds: 30));
    _toFront(tester);
    await tester.pump();
    expect(asks, 4);
    poll.cancel();
  });

  testWidgets('the Jira list and its issue ask nothing while the window is '
      'in the back, once each on return; the list not under its issue', (
    tester,
  ) async {
    final (fake, d) = await jira.openView(tester);
    int lists() => fake.calls.whereType<ListJiraIssuesRequest>().length;
    int issues() => fake.calls
        .whereType<GetJiraIssueRequest>()
        .where((r) => !r.cached)
        .length;
    final listed = lists();
    _toBack(tester);
    await tester.pump(jiraPoll * 5);
    expect(lists(), listed);
    _toFront(tester);
    await tester.pumpAndSettle();
    expect(lists(), listed + 1);
    // An issue over the list: only the issue polls.
    await tester.tap(find.text('Log in with a passkey'));
    await tester.pumpAndSettle();
    expect(find.byType(JiraIssuePane), findsOneWidget);
    final read = issues();
    await tester.pump(jiraPoll * 3);
    await tester.pumpAndSettle();
    expect(lists(), listed + 1);
    expect(issues(), read + 3);
    _toBack(tester);
    await tester.pump(issuePoll * 3);
    expect(issues(), read + 3);
    _toFront(tester);
    await tester.pumpAndSettle();
    expect(issues(), read + 4);
    expect(lists(), listed + 1);
    await closeView(tester, d);
  });

  testWidgets('the GitHub inbox asks nothing in the back, once on return, '
      'and not under a pull request, whose page asks only in front', (
    tester,
  ) async {
    final (fake, d) = await gh.openView(tester);
    int inboxes() => fake.calls
        .whereType<ListGitHubInboxRequest>()
        .where((r) => !r.cached)
        .length;
    int pulls() => fake.calls.whereType<GetGitHubPullRequest>().length;
    final asked = inboxes();
    _toBack(tester);
    await tester.pump(githubPoll * 5);
    expect(inboxes(), asked);
    _toFront(tester);
    await tester.pumpAndSettle();
    expect(inboxes(), asked + 1);
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    await tester.pump(pullWidgetPoll * 2);
    await tester.pumpAndSettle();
    expect(inboxes(), asked + 1);
    expect(pulls(), 3); // opened, then each minute
    _toBack(tester);
    await tester.pump(pullWidgetPoll * 5);
    expect(pulls(), 3);
    _toFront(tester);
    await tester.pumpAndSettle();
    expect(pulls(), 4);
    expect(inboxes(), asked + 1);
    await closeView(tester, d);
  });

  testWidgets('a failed quiet poll keeps what shows and says when it is '
      'from: the Jira list, its issue, the GitHub inbox', (tester) async {
    var failing = false;
    Never fail() => throw Exception('no network');
    final (_, d) = await jira.openView(
      tester,
      more: (input) =>
          failing && input is ListJiraIssuesRequest && !input.cached
          ? fail()
          : failing && input is GetJiraIssueRequest && !input.cached
          ? fail()
          : null,
    );
    expect(find.textContaining("Couldn't refresh"), findsNothing);
    failing = true;
    await tester.pump(jiraPoll * 3);
    await tester.pumpAndSettle();
    expect(find.text('Log in with a passkey'), findsOneWidget);
    expect(find.text("Couldn't refresh · as of just now"), findsOneWidget);
    failing = false;
    await tester.pump(jiraPoll);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsNothing);
    // The issue: its line over it.
    await tester.tap(find.text('Log in with a passkey'));
    await tester.pumpAndSettle();
    failing = true;
    await tester.pump(issuePoll * 2);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't refresh · as of just now"), findsOneWidget);
    await closeView(tester, d);

    final (_, g) = await gh.openView(
      tester,
      more: (input) =>
          failing && input is ListGitHubInboxRequest && !input.cached
          ? fail()
          : null,
    );
    expect(find.text('Add Sub and Neg'), findsOneWidget);
    await tester.pump(githubPoll);
    await tester.pumpAndSettle();
    expect(find.text('Add Sub and Neg'), findsOneWidget);
    expect(find.textContaining("Couldn't refresh · as of"), findsOneWidget);
    await closeView(tester, g);
  });

  testWidgets("a failed quiet poll after a switch to a list that never came "
      "says nothing of the last one's time: the GitHub inbox, Jira's list", (
    tester,
  ) async {
    var failing = false;
    Never fail() => throw Exception('no network');
    final (_, g) = await gh.openView(
      tester,
      more: (input) =>
          failing && input is ListGitHubInboxRequest ? fail() : null,
    );
    expect(find.text('Add Sub and Neg'), findsOneWidget);
    failing = true;
    tester.widget<GitHubBar>(find.byType(GitHubBar)).onDays(30);
    await tester.pumpAndSettle();
    await tester.pump(githubPoll);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsNothing);
    await closeView(tester, g);

    failing = false;
    final other = jira.testSite.deepCopy()
      ..id = 'other.atlassian.net'
      ..url = 'https://other.atlassian.net';
    final (_, d) = await jira.openView(
      tester,
      sites: [jira.testSite, other],
      more: (input) =>
          failing && input is ListJiraIssuesRequest ? fail() : null,
    );
    failing = true;
    tester.widget<JiraBar>(find.byType(JiraBar)).onSite(other.id);
    await tester.pumpAndSettle();
    await tester.pump(jiraPoll);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsNothing);
    await closeView(tester, d);
  });
}
