import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'jira_view_test.dart' show closeView, issue, openView;

/// Five minutes before the view's now.
final _kept = Int64(DateTime(2026, 10, 25, 11, 55).millisecondsSinceEpoch);

void main() {
  setUpAll(loadFonts);

  testWidgets('what the list showed last, until Jira answers', (tester) async {
    final fresh = Completer<ListJiraIssuesResponse>();
    final (_, d) = await openView(
      tester,
      more: (input) => switch (input) {
        ListJiraIssuesRequest(cached: true) => ListJiraIssuesResponse(
          issues: [issue('ACME-7', 'As it was', 'To Do', 'new')],
          atMs: _kept,
        ),
        ListJiraIssuesRequest(list: 'mine') => fresh.future,
        _ => null,
      },
    );
    expect(find.text('ACME-7'), findsOneWidget);
    expect(find.text('Updated 5m ago · refreshing'), findsOneWidget);
    fresh.complete(
      ListJiraIssuesResponse(
        issues: [issue('ACME-8', 'As it is', 'To Do', 'new')],
        atMs: Int64(DateTime(2026, 10, 25, 12).millisecondsSinceEpoch),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACME-7'), findsNothing);
    expect(find.text('ACME-8'), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('what was kept stays when Jira fails, saying so', (tester) async {
    final (_, d) = await openView(
      tester,
      more: (input) => switch (input) {
        ListJiraIssuesRequest(cached: true) => ListJiraIssuesResponse(
          issues: [issue('ACME-7', 'As it was', 'To Do', 'new')],
          atMs: _kept,
        ),
        ListJiraIssuesRequest() => Future<Object>.delayed(
          const Duration(milliseconds: 10),
          () => throw Exception("can't reach acme.atlassian.net"),
        ),
        _ => null,
      },
    );
    expect(find.text('ACME-7'), findsOneWidget);
    expect(find.text('Updated 5m ago'), findsOneWidget);
    expect(find.textContaining("can't reach"), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('rows that are coming, with nothing kept', (tester) async {
    final fresh = Completer<ListJiraIssuesResponse>();
    final (_, d) = await openView(
      tester,
      more: (input) => switch (input) {
        ListJiraIssuesRequest(cached: true) => ListJiraIssuesResponse(),
        ListJiraIssuesRequest(list: 'mine') => fresh.future,
        _ => null,
      },
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(RowsLoading), findsOneWidget);
    expect(find.text('Nothing here'), findsNothing);
    fresh.complete(
      ListJiraIssuesResponse(
        issues: [issue('ACME-8', 'As it is', 'To Do', 'new')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RowsLoading), findsNothing);
    expect(find.text('ACME-8'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('the keychain wanting an OK is said once, by its banner', (
    tester,
  ) async {
    final (_, d) = await openView(
      tester,
      sites: [
        JiraSite(id: 'acme.atlassian.net', url: 'https://acme.atlassian.net')
          ..needsOk = true,
      ],
      more: (input) => input is ListJiraIssuesRequest && !input.cached
          ? throw Exception(
              'This build of Nushi needs your OK to read the Jira token '
              'from the keychain',
            )
          : null,
    );
    expect(find.textContaining('needs your OK'), findsOneWidget);
    expect(find.text('Allow…'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('a daemon that must restart to reach the keychain says so '
      'once, and offers no Allow', (tester) async {
    const why =
        "Nushi's daemon can't reach your keychain: it was started from a "
        'build of Nushi that has been replaced or removed since, or outside '
        'your login session. Restart the daemon';
    final (_, d) = await openView(
      tester,
      sites: [
        JiraSite(id: 'acme.atlassian.net', url: 'https://acme.atlassian.net')
          ..needsRestart = true
          ..problem = why,
      ],
      more: (input) => input is ListJiraIssuesRequest && !input.cached
          ? throw Exception(why)
          : null,
    );
    expect(find.textContaining("can't reach your keychain"), findsOneWidget);
    expect(
      find.textContaining('Restarting stops running turns'),
      findsOneWidget,
    );
    expect(find.text('Allow…'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('an issue as it showed last, until Jira answers', (tester) async {
    final fresh = Completer<GetJiraIssueResponse>();
    final (_, d) = await openView(
      tester,
      more: (input) => switch (input) {
        GetJiraIssueRequest(cached: true, :final key) => GetJiraIssueResponse(
          issue: issue(key, 'Kept summary', 'To Do', 'new'),
          atMs: _kept,
        ),
        GetJiraIssueRequest() => fresh.future,
        _ => null,
      },
    );
    await tester.tap(find.text('ACME-9'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Kept summary'), findsOneWidget);
    expect(find.text('Updated 5m ago · refreshing'), findsOneWidget);
    fresh.complete(
      GetJiraIssueResponse(
        issue: issue('ACME-9', 'Fresh summary', 'To Do', 'new'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fresh summary'), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
    await closeView(tester, d);
  });
}
