import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/settings.dart';
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
  List<Chat> chats = const [],
  Size size = const Size(1000, 560),
  Tokens tokens = Tokens.dark,
  Object? Function(Object input)? more,
  Map<String, List<String>> groups = const {},
  Map<String, List<String>> collapsed = const {},
}) async {
  // As app.json had them at launch.
  jiraGroupOrder.value = groups;
  jiraCollapsed.value = collapsed;
  final fake = FakeDaemon(chats)
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
  forgetJiraView(); // it keeps what it had while the app runs
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(body: JiraView(d, now: DateTime(2026, 10, 25, 12))),
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

  testWidgets('my open issues by status; the keys pick, ⏎ the details, '
      'Esc back', (tester) async {
    final (_, d) = await openView(tester);
    // To Do before In Progress before Done, whatever Jira's order.
    final rows = [
      for (final k in ['ACME-9', 'ACME-12', 'ACME-3'])
        tester.getTopLeft(find.text(k)).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));
    expect(find.text('To Do  1'), findsOneWidget);
    expect(find.byType(JiraIssuePane), findsNothing); // a list, no details
    // Its close names Esc, as Settings' and GitHub's do (UX review, 22).
    expect(find.byTooltip('Close (esc)'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-12');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(JiraIssuePane), findsNothing);
    await tester.tap(find.text('Write the release notes'));
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-3');
    await tester.tap(find.byTooltip('The list (Esc)'));
    await tester.pumpAndSettle();
    expect(find.text('Write the release notes'), findsOneWidget);
    // ⌘⏎: the selected row's Start work, its folders.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Choose folder', findRichText: true),
      findsOneWidget,
    );
    await closeView(tester, d);
  });

  testWidgets('↓ keeps the selection in view; ⌘⏎ starts work on it, not '
      'on the row before', (tester) async {
    // 40 issues, in two cards: far more than the window shows.
    final many = [
      for (var i = 1; i <= 40; i++)
        issue(
          'ACME-$i',
          'Issue $i',
          i <= 20 ? 'To Do' : 'In Progress',
          i <= 20 ? 'new' : 'indeterminate',
        ),
    ];
    final (fake, d) = await openView(
      tester,
      chats: [chat('c1', 'claude', 'Elsewhere')],
      more: (input) => switch (input) {
        ListJiraIssuesRequest(list: 'mine') => ListJiraIssuesResponse(
          issues: many,
        ),
        FindJiraIssuesRequest(:final text) => FindJiraIssuesResponse(
          issues: [
            FoundJiraIssue(
              site: _site.id,
              issue: issue(text, 'Issue', 'To Do', 'new'),
              branch: text,
            ),
          ],
        ),
        _ => null,
      },
    );
    final view = tester.getRect(find.byType(JiraView));
    for (var i = 0; i < 39; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // The last, In Progress's 20th, on screen.
    final last = find.text('ACME-40');
    expect(last, findsOneWidget);
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(view.bottom));
    expect(tester.getRect(last).top, greaterThanOrEqualTo(view.top));
    // Scrolled back to the top: the selected row isn't built.
    await tester.drag(
      find.text('ACME-30'),
      const Offset(0, 3000),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('ACME-40', skipOffstage: false).evaluate().isEmpty ||
          tester.getRect(find.text('ACME-40', skipOffstage: false)).top >
              view.bottom,
      isTrue,
      reason: 'out of view',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('nushi', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(find.text('Chat on ACME-40 in nushi'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(fake.started, isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a row: its chats, its status, Start work', (tester) async {
    final (fake, d) = await openView(
      tester,
      chats: [
        chat('c1', 'claude', 'Passkeys', age: 5)
          ..jiraSite = _site.id
          ..jiraKey = 'ACME-12',
        chat('c2', 'codex', 'Passkeys again', age: 1)
          ..jiraSite = _site.id
          ..jiraKey = 'ACME-12',
      ],
      more: (input) => switch (input) {
        ListJiraTransitionsRequest() => ListJiraTransitionsResponse(
          transitions: [JiraTransition(id: '31', name: 'Done', to: 'Done')],
        ),
        FindJiraIssuesRequest(:final text) => FindJiraIssuesResponse(
          issues: [
            FoundJiraIssue(
              site: _site.id,
              issue: issue(text, 'Log in with a passkey', 'To Do', 'new'),
              branch: '$text-log-in-with-a-passkey',
            ),
          ],
        ),
        _ => null,
      },
    );
    // Its chats: a click opens the newest.
    await tester.tap(find.byTooltip('Open its newest chat (it has 2)'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'c2');
    expect(d.jiraOpen, isFalse);
    d.showJira(open: true);
    await tester.pumpAndSettle();
    // Its status, from the row.
    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Done'),
      ),
    );
    await tester.pumpAndSettle();
    final moved = fake.calls.whereType<TransitionJiraIssueRequest>().single;
    expect((moved.key, moved.transition), ('ACME-12', '31'));
    // Start work (the selected row's): a folder, then the New chat
    // dialog with the issue.
    await tester.tap(find.byTooltip('Start work (⌘⏎)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('nushi', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(find.text('Chat on ACME-9 in nushi'), findsOneWidget);
    expect(find.text('ACME-9-log-in-with-a-passkey'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final s = fake.started.single;
    expect(
      (s.jiraKey, s.worktree, s.branch),
      ('ACME-9', true, 'ACME-9-log-in-with-a-passkey'),
    );
    await closeView(tester, d);
  });

  testWidgets('every site’s issues, each row naming its site', (tester) async {
    final other = JiraSite(id: 'other.atlassian.net', url: 'https://other');
    final (fake, d) = await openView(tester, sites: [_site, other]);
    await tester.tap(find.text(_site.id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All sites'));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<ListJiraIssuesRequest>().toList();
    expect(asked.reversed.take(2).map((r) => r.site).toSet(), {
      _site.id,
      other.id,
    });
    expect(find.text('Sprint'), findsNothing); // one site's lists
    expect(find.textContaining(other.id, findRichText: true), findsWidgets);
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

  testWidgets('the sprint list asks for its board first', (tester) async {
    final (fake, d) = await openView(
      tester,
      sites: [_site.deepCopy()..board = Int64.ZERO],
    );
    await tester.tap(find.text('Sprint'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the board…'), findsOneWidget);
    expect(
      fake.calls.whereType<ListJiraIssuesRequest>().where(
        (r) => r.list == 'sprint',
      ),
      isEmpty,
    );
    await closeView(tester, d);
  });

  testWidgets('a token the keychain wants an OK for', (tester) async {
    final (fake, d) = await openView(
      tester,
      sites: [_site.deepCopy()..needsOk = true],
    );
    await tester.tap(find.text('Allow…'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<AllowJiraTokenRequest>().single.site, _site.id);
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
    for (final (width, size) in [
      ('narrow', const Size(760, 560)),
      ('wide', const Size(1300, 560)),
    ]) {
      testWidgets('golden, $width, $name', (tester) async {
        final (_, d) = await openView(
          tester,
          tokens: tokens,
          size: size,
          chats: [
            for (final (id, agent) in [('c1', 'claude'), ('c2', 'codex')])
              chat(id, agent, 'Passkeys')
                ..jiraSite = _site.id
                ..jiraKey = 'ACME-12',
          ],
        );
        await expectLater(
          find.byType(JiraView),
          matchesGoldenFile('goldens/jira_view_${width}_$name.png'),
        );
        await tester.tap(find.text('Log in with a passkey'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(JiraView),
          matchesGoldenFile('goldens/jira_details_${width}_$name.png'),
        );
        await closeView(tester, d);
      });
    }
  }
}
