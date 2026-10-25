import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

final _now = DateTime(2026, 10, 25, 12);
Int64 _ago(Duration d) => Int64(_now.subtract(d).millisecondsSinceEpoch);

// A red 8×8 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEklEQVR4nGP4z8CAFTEMLQkA'
  'jkg/wfZGjoUAAAAASUVORK5CYII=',
);

JiraIssue _issue() => JiraIssue(
  key: 'ACME-12',
  summary: 'Log in with a passkey',
  type: 'Story',
  status: 'In Progress',
  statusCategory: 'indeterminate',
  priority: 'High',
  assignee: 'Test User',
  reporter: 'Ann Lee',
  created: _ago(const Duration(days: 3)),
  updated: _ago(const Duration(hours: 2)),
  labels: ['auth'],
  url: 'https://acme.atlassian.net/browse/ACME-12',
  description:
      '## What\n\nLet people sign in with a **passkey**.\n\n'
      '![screen.png](jira-attachment:10000)\n\n'
      '![beacon](https://tracker.example/p.png)',
  acceptanceCriteria: '- A passkey signs in\n- Passwords still work',
  parent: JiraIssueRef(key: 'ACME-1', summary: 'Accounts', status: 'To Do'),
  subtasks: [JiraIssueRef(key: 'ACME-13', summary: 'The API', status: 'Done')],
  links: [
    JiraLink(
      relation: 'is blocked by',
      issue: JiraIssueRef(key: 'ACME-9', summary: 'Sessions', status: 'To Do'),
    ),
  ],
  attachments: [
    JiraAttachment(id: '10000', name: 'screen.png', mimeType: 'image/png'),
    JiraAttachment(
      id: '10001',
      name: 'notes.pdf',
      mimeType: 'application/pdf',
      size: Int64(20480),
    ),
  ],
  remoteLinks: [
    JiraRemoteLink(title: 'PR #31', url: 'https://github.com/acme/app/pull/31'),
  ],
  comments: [
    JiraComment(
      author: 'Ann Lee',
      body: 'Can we do **Safari** first?',
      created: _ago(const Duration(hours: 5)),
    ),
    JiraComment(
      id: 'k1',
      author: 'Test User',
      body: 'Safari works; Chrome next.',
      created: _ago(const Duration(minutes: 30)),
    ),
  ],
);

Future<(FakeDaemon, Daemon, List<String>)> _open(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final opened = <String>[];
  final fake =
      FakeDaemon([
          chat('c1', 'claude', 'Passkeys: the API')
            ..jiraSite = 'acme.atlassian.net'
            ..jiraKey = 'ACME-12',
        ])
        ..answer = (input) => switch (input) {
          GetJiraIssueRequest() => GetJiraIssueResponse(
            issue: _issue(),
            agentWrites: [
              JiraWrite(
                kind: 'move',
                to: 'In Progress',
                chat: 'c1',
                agent: 'claude',
                at: _ago(const Duration(hours: 1)),
              ),
              JiraWrite(
                kind: 'comment',
                comment: 'k1',
                chat: 'c1',
                agent: 'claude',
              ),
            ],
          ),
          GetJiraAttachmentRequest(:final id) => GetJiraAttachmentResponse(
            data: id == '10000' ? _png : [],
            mimeType: 'image/png',
          ),
          FindJiraIssuesRequest(:final text, :final site)
              when text == 'ACME-12' && site == 'acme.atlassian.net' =>
            FindJiraIssuesResponse(
              issues: [
                FoundJiraIssue(
                  site: 'acme.atlassian.net',
                  issue: JiraIssue(
                    key: 'ACME-12',
                    summary: 'Log in with a passkey',
                  ),
                  branch: 'ACME-12-log-in-with-a-passkey',
                ),
              ],
            ),
          ListJiraTransitionsRequest() => ListJiraTransitionsResponse(
            transitions: [
              JiraTransition(id: '21', name: 'In Progress', to: 'In Progress'),
              JiraTransition(
                id: '31',
                name: 'Done',
                to: 'Done',
                fields: [
                  JiraField(
                    id: 'resolution',
                    name: 'Resolution',
                    type: 'resolution',
                    required: true,
                    options: [JiraOption(id: '1', name: 'Fixed')],
                  ),
                ],
              ),
            ],
          ),
          _ => null,
        };
  final d = await fake.connect(tester);
  await tester.binding.setSurfaceSize(const Size(700, 1100));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: JiraIssuePane(
          daemon: d,
          site: 'acme.atlassian.net',
          issueKey: 'ACME-12',
          onOpen: opened.add,
          now: _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d, opened);
}

/// A row of the open menu.
Finder menuRow(String label) => find.ancestor(
  of: find.textContaining(label, findRichText: true),
  matching: find.byType(MenuItemButton),
);

Future<void> _close(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the issue whole; only its attachments load as images', (
    tester,
  ) async {
    final (fake, d, opened) = await _open(tester);
    expect(find.text('Log in with a passkey'), findsOneWidget);
    expect(
      find.text('Reported by Ann Lee · 3d ago · updated 2h ago · auth'),
      findsOneWidget,
    );
    expect(find.text('Acceptance criteria'), findsOneWidget);
    expect(find.text('[image: beacon]'), findsOneWidget);
    expect(
      fake.calls.whereType<GetJiraAttachmentRequest>().map((r) => r.id).toSet(),
      {'10000'},
    );
    expect(find.text('notes.pdf · 20 KB'), findsOneWidget);
    await tester.tap(find.text('ACME-13'));
    await tester.tap(find.text('ACME-1'));
    expect(opened, ['ACME-13', 'ACME-1']);
    await _close(tester, d);
  });

  testWidgets('a move that asks for a field', (tester) async {
    final (fake, d, _) = await _open(tester);
    await tester.tap(find.text('In Progress ▾'));
    await tester.pumpAndSettle();
    await tester.tap(menuRow('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Resolution *'), findsOneWidget);
    await tester.tap(find.text('Pick ▾'));
    await tester.pumpAndSettle();
    await tester.tap(menuRow('Fixed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();
    final move = fake.calls.whereType<TransitionJiraIssueRequest>().single;
    expect((move.key, move.transition), ('ACME-12', '31'));
    expect(move.values, {'resolution': '1'});
    await _close(tester, d);
  });

  testWidgets('a comment in Markdown', (tester) async {
    final (fake, d, _) = await _open(tester);
    await tester.enterText(find.byType(TextField), 'Yes, **Safari** first.');
    await tester.pump();
    // ⌘⏎ posts it, as the button does.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    final c = fake.calls.whereType<AddJiraCommentRequest>().single;
    expect((c.key, c.markdown), ('ACME-12', 'Yes, **Safari** first.'));
    await _close(tester, d);
  });

  testWidgets('a chat on the issue: the dialog has it picked, a worktree on '
      'its branch; the box is empty', (tester) async {
    final (fake, d, _) = await _open(tester);
    // The chat already on it is listed, and what its agent wrote.
    expect(find.text('Passkeys: the API'), findsOneWidget);
    expect(
      find.text('Test User · 30m ago · by Claude in “Passkeys: the API”'),
      findsOneWidget,
    );
    expect(
      find.text('To In Progress · 1h ago · by Claude in “Passkeys: the API”'),
      findsOneWidget,
    );
    expect(find.text('Ann Lee · 5h ago'), findsOneWidget);
    await tester.tap(find.text('Start a chat ▾'));
    await tester.pumpAndSettle();
    await tester.tap(menuRow('nushi'));
    await tester.pumpAndSettle();
    expect(find.text('Chat on ACME-12 in nushi'), findsOneWidget);
    expect(find.text('Log in with a passkey'), findsWidgets);
    expect(find.text('ACME-12-log-in-with-a-passkey'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final start = fake.started.single;
    expect(
      (
        start.folder,
        start.jiraSite,
        start.jiraKey,
        start.worktree,
        start.branch,
      ),
      (
        '/Users/me/nushi',
        'acme.atlassian.net',
        'ACME-12',
        true,
        'ACME-12-log-in-with-a-passkey',
      ),
    );
    expect(d.chats['c1']!.draft.text.text, isEmpty);
    await _close(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d, _) = await _open(tester, tokens: tokens);
      await expectLater(
        find.byType(JiraIssuePane),
        matchesGoldenFile('goldens/jira_issue_$name.png'),
      );
      await _close(tester, d);
    });
  }
}
