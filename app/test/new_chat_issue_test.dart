import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

const _acme = 'acme.atlassian.net';
const _other = 'other.atlassian.net';
const _link = 'https://$_acme/browse/ACME-12?focusedCommentId=1';

FoundJiraIssue _found(String site, String key, String summary) =>
    FoundJiraIssue(
      site: site,
      issue: JiraIssue(
        key: key,
        summary: summary,
        status: 'To Do',
        statusCategory: 'new',
      ),
      branch: '$key-${summary.toLowerCase().replaceAll(' ', '-')}',
    );

/// Two sites; what FindJiraIssues finds for each text.
Object? _jira(Object input) => switch (input) {
  ListJiraSitesRequest() => ListJiraSitesResponse(
    sites: [
      JiraSite(id: _acme, url: 'https://$_acme'),
      JiraSite(id: _other, url: 'https://$_other'),
    ],
  ),
  FindJiraIssuesRequest(:final text) => switch (text) {
    _link || 'ACME-12' => FindJiraIssuesResponse(
      issues: [_found(_acme, 'ACME-12', 'Log in with a passkey')],
    ),
    'https://elsewhere.example/browse/X-1' => FindJiraIssuesResponse(
      unknownSite: 'https://elsewhere.example',
    ),
    'login' || '' => FindJiraIssuesResponse(
      issues: [
        _found(_acme, 'ACME-12', 'Log in with a passkey'),
        _found(_other, 'OPS-3', 'Login page is slow'),
      ],
    ),
    _ => FindJiraIssuesResponse(),
  },
  _ => null,
};

Future<(FakeDaemon, Daemon)> _sidebar(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([chat('a', 'claude', 'Older', age: 5)])
    ..answer = _jira;
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(width: 260, child: Sidebar(daemon: d)),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
  return (fake, d);
}

/// The dialog for the chats' folder, /Users/me/nushi.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byTooltip('New chat here'));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Types [text] in the issue picker, and waits out its pause.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

List<FindJiraIssuesRequest> _finds(FakeDaemon fake) =>
    fake.calls.whereType<FindJiraIssuesRequest>().toList();

void main() {
  setUpAll(loadFonts);
  setUp(() {
    lastJiraSite.value = _other;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
  });

  testWidgets('⌘V with an issue’s link picks it: a worktree on its branch, '
      'the chat on it', (tester) async {
    final (fake, d) = await _sidebar(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? {
                  // As copied from a browser, with space around it.
                  'text': ' $_link\n',
                }
              : null,
        );
    await _open(tester);
    expect(find.text('Jira issue…'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('Log in with a passkey'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter); // picks it
    expect(find.text('Chat on ACME-12 in nushi'), findsOneWidget);
    expect(find.text('ACME-12-log-in-with-a-passkey'), findsOneWidget);
    expect(lastJiraSite.value, _acme);
    await _key(tester, LogicalKeyboardKey.enter); // starts Claude's
    final s = fake.started.single;
    expect(
      (s.folder, s.jiraSite, s.jiraKey, s.worktree, s.branch),
      (
        '/Users/me/nushi',
        _acme,
        'ACME-12',
        true,
        'ACME-12-log-in-with-a-passkey',
      ),
    );
    expect(d.chats.values.every((c) => c.draft.text.text.isEmpty), isTrue);
    d.dispose();
  });

  testWidgets('a key is looked for on the site used last; words on every '
      'site, each row naming its site', (tester) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.keyI);
    expect(_finds(fake).single.text, ''); // the issues looked at last
    await _type(tester, 'ACME-12');
    expect(
      (_finds(fake).last.text, _finds(fake).last.site),
      ('ACME-12', _other),
    );
    await _type(tester, 'login');
    expect(find.text(_other), findsOneWidget);
    expect(find.text('Login page is slow'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Chat on OPS-3 in nushi'), findsOneWidget);
    // Another, by a click; then none.
    await tester.tap(find.text('OPS-3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in with a passkey'));
    await tester.pumpAndSettle();
    expect(find.text('Chat on ACME-12 in nushi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.backspace);
    expect(find.text('New chat in nushi'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    final s = fake.started.single;
    expect((s.jiraKey, s.worktree, s.branch), ('', false, ''));
    d.dispose();
  });

  testWidgets('a link to a site not added says so; Esc goes back', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.keyI);
    await _type(tester, 'https://elsewhere.example/browse/X-1');
    expect(
      find.textContaining("elsewhere.example isn't added"),
      findsOneWidget,
    );
    await _type(tester, 'nothing like it');
    expect(find.text('No issues match.'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter); // nothing to pick
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('New chat in nushi'), findsOneWidget); // still open
    expect(fake.started, isEmpty);
    d.dispose();
  });

  testWidgets('W turns the worktree off; B changes the branch', (tester) async {
    final (fake, d) = await _sidebar(tester);
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.keyI);
    await _key(tester, LogicalKeyboardKey.enter); // the first looked at
    await _key(tester, LogicalKeyboardKey.keyB);
    await tester.enterText(find.byType(TextField), 'me/ACME-12-passkeys');
    await _key(tester, LogicalKeyboardKey.enter); // the field's, not a start
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fake.started, isEmpty);
    expect(find.text('me/ACME-12-passkeys'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(fake.started.last.branch, 'me/ACME-12-passkeys');

    await _open(tester);
    await _key(tester, LogicalKeyboardKey.keyI);
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.keyW);
    await _key(tester, LogicalKeyboardKey.enter);
    final s = fake.started.last;
    expect((s.jiraKey, s.worktree, s.branch), ('ACME-12', false, ''));
    d.dispose();
  });

  testWidgets('without a Jira site the dialog offers no issue', (tester) async {
    final (fake, d) = await _sidebar(tester);
    fake.answer = null;
    await _open(tester);
    expect(find.text('Jira issue…'), findsNothing);
    await _key(tester, LogicalKeyboardKey.keyI);
    expect(find.byType(TextField), findsNothing);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the dialog with an issue ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(700, 400);
      addTearDown(tester.view.reset);
      final (_, d) = await _sidebar(tester, tokens: tokens);
      await _open(tester);
      await _key(tester, LogicalKeyboardKey.keyI);
      await _type(tester, 'login');
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/issue_picker_$name.png'),
      );
      await _key(tester, LogicalKeyboardKey.enter);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/new_chat_issue_$name.png'),
      );
      d.dispose();
    });
  }
}
