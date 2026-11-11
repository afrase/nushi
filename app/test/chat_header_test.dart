import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  // A long title and a Codex model id fit a narrow window, cut short.
  for (final width in [560.0, 760.0, 1200.0]) {
    testWidgets('the header doesn’t overflow, $width wide', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      const model = 'accounts/fireworks/models/deepseek-v4p1-flash';
      final chat = ChatState('c', '/Users/me/repo')
        ..agent = 'codex'
        ..title = 'A title long enough to want all of the room it can get'
        ..config = [
          ConfigOption(
            id: 'model',
            category: 'model',
            current: model,
            values: [ConfigValue(value: model, name: model)],
          ),
        ];
      await tester.pumpWidget(
        themed(
          SizedBox(
            width: width,
            child: ChatHeader(
              chat,
              d,
              tab: ChatTab.chat,
              onTab: (_) {},
              panel: true,
              onPanel: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Narrower, the model folds first.
      expect(find.text(model), width > 600 ? findsOne : findsNothing);
      d.dispose();
    });
  }

  testWidgets('a model the agent doesn’t list shows by its id, as in the '
      'pickers', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..title = 'Fix the login'
      ..config = [
        ConfigOption(
          id: 'model',
          category: 'model',
          current: 'claude-test-preview',
          values: [ConfigValue(value: 'opus', name: 'Opus 5.5')],
        ),
      ];
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 1200,
          child: ChatHeader(
            chat,
            d,
            tab: ChatTab.chat,
            onTab: (_) {},
            panel: true,
            onPanel: () {},
          ),
        ),
      ),
    );
    expect(find.text('claude-test-preview'), findsOne);
    d.dispose();
  });

  // At 720 wide, with the sidebar's 260, the header has 460: the least
  // needed parts fold, so ⋯ stays at its end (UX review, finding 6).
  testWidgets('the chat menu stays at the row’s end however narrow', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 300));
    // A linked pull request has every badge its chip can show.
    final fake = FakeDaemon([])
      ..answer = (i) => i is GetGitHubStatesRequest
          ? GetGitHubStatesResponse(
              items: [
                for (final l in i.items)
                  GitHubItem(
                    id: l.id,
                    pull: l.pull,
                    state: 'open',
                    checks: l.pull ? 'failure' : '',
                    review: l.pull ? 'changes_requested' : '',
                    unresolved: l.pull ? 12 : 0,
                  ),
              ],
            )
          : null;
    final d = await fake.connect(tester);
    const model = 'claude-opus-5-5[1m]';
    final issue = GitHubLink(id: 'I_1', repo: 'o/r', number: 4321);
    final pullItem = GitHubLink(
      id: 'PR_1',
      repo: 'o/r',
      number: 12345,
      pull: true,
    );
    for (final pull in [false, true]) {
      for (final panel in [false, true]) {
        for (final (agent, failed, background, jira, github) in [
          ('claude', false, 0, '', null),
          ('omp', true, 0, '', null),
          ('omp', false, 2, '', null), // "in background"
          ('claude', false, 0, 'PLATFORM-12345', null),
          // The chat's issue, or its pull request with its badges.
          ('claude', false, 0, '', pull ? pullItem : issue),
        ]) {
          final chat = ChatState('c', '/Users/me/repo')
            ..agent = agent
            ..jiraKey = jira
            ..github = github
            ..background = background
            ..title = 'Fix the login redirect after the session expires'
            ..reopenFailed =
                failed // "couldn't start", the longest word
            ..pull = pull ? GitHubLink(number: 12, pull: true) : null
            ..config = [
              ConfigOption(
                id: 'model',
                category: 'model',
                current: model,
                values: [ConfigValue(value: model, name: model)],
              ),
            ];
          // A Jira key and a GitHub chip never fold: everything else
          // folded, a long key fits from about 380, an issue's chip from
          // 350, a pull request's with its badges from 430.
          final least = switch ((jira, github)) {
            (_, final GitHubLink l) => l.pull ? 430.0 : 350.0,
            ('', _) => 320.0,
            _ => 400.0,
          };
          for (var width = least; width <= 1200; width += 10) {
            await tester.pumpWidget(
              themed(
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: ChatHeader(
                      chat,
                      d,
                      tab: ChatTab.chat,
                      onTab: (_) {},
                      panel: false,
                      onPanel: panel ? () {} : null,
                    ),
                  ),
                ),
              ),
            );
            // The chip's states land.
            if (github != null) await tester.pump();
            final why =
                '$width wide, pull $pull, panel $panel, jira $jira, '
                'github ${github?.number}';
            expect(tester.takeException(), isNull, reason: why);
            final menu = tester.getRect(find.byTooltip('Chat menu'));
            expect(menu.right, width - ChatHeader.end, reason: why);
          }
        }
      }
    }
    d.dispose();
  });

  // A chat on a pull request, its chip's badges loaded, in the chat areas
  // a laptop leaves (the sidebar and details open) and a wide window.
  for (final width in [460.0, 700.0, 1400.0]) {
    testWidgets('a pull request’s chip fits the header, $width wide', (
      tester,
    ) async {
      viewport(tester, Size(width, 100));
      final fake = FakeDaemon([])
        ..answer = (i) => i is GetGitHubStatesRequest
            ? GetGitHubStatesResponse(
                items: [
                  GitHubItem(
                    id: 'PR_1',
                    pull: true,
                    state: 'open',
                    checks: 'failure',
                    review: 'changes_requested',
                    unresolved: 12,
                  ),
                ],
              )
            : null;
      final d = await fake.connect(tester);
      final chat = ChatState('c', '/Users/me/repo')
        ..agent = 'claude'
        ..title = 'Fix the login redirect after the session expires'
        ..github = GitHubLink(
          id: 'PR_1',
          repo: 'o/r',
          number: 12345,
          pull: true,
        )
        ..pull = GitHubLink(number: 12345, pull: true);
      await tester.pumpWidget(
        themed(
          ChatHeader(
            chat,
            d,
            tab: ChatTab.chat,
            onTab: (_) {},
            panel: true,
            onPanel: () {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.forum_outlined), findsOne);
      expectTextInside(tester, width);
      final menu = tester.getRect(find.byTooltip('Chat menu'));
      expect(menu.right, width - ChatHeader.end);
      await render(tester, find.byType(ChatHeader), 'header_pull_$width');
      d.dispose();
    });
  }

  testWidgets('at 460 the tabs are a menu, at 330 the terminal is in ⋯; '
      'wide, they are buttons', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..title = 'Fix the login redirect'
      ..pull = GitHubLink(number: 12, pull: true);
    ChatTab? picked;
    Future<void> pump(double width) => tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ChatHeader(
              chat,
              d,
              tab: ChatTab.chat,
              onTab: (t) => picked = t,
              panel: false,
              onPanel: null,
            ),
          ),
        ),
      ),
    );
    await pump(1200);
    expect(find.text('Pull request'), findsOne);
    expect(find.byTooltip('Show terminal  ⌃`'), findsOne);
    await pump(460);
    expect(find.text('Pull request'), findsNothing);
    await tester.tap(find.byType(MenuField));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pull request', findRichText: true));
    await tester.pumpAndSettle();
    expect(picked, ChatTab.pull);
    await pump(330);
    expect(find.byTooltip('Show terminal  ⌃`'), findsNothing);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Show terminal', findRichText: true), findsOne);
    expect(find.text('Rename', findRichText: true), findsOne);
    d.dispose();
  });

  testWidgets('folded into a menu, only the open tab is checked', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..title = 'Fix the login redirect'
      ..pull = GitHubLink(number: 12, pull: true);
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 460,
            child: ChatHeader(
              chat,
              d,
              tab: ChatTab.changes,
              onTab: (_) {},
              panel: false,
              onPanel: null,
            ),
          ),
        ),
      ),
    );
    final menu = tester.widget<MenuField>(find.byType(MenuField));
    expect(
      [
        for (final e in menu.entries)
          if (e.checked) e.label,
      ],
      ['Changes'],
    );
    d.dispose();
  });
}
