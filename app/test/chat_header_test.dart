import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

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
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Scaffold(
            body: SizedBox(
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
        ),
      );
      expect(tester.takeException(), isNull);
      // Narrower, the model folds first.
      expect(find.text(model), width > 600 ? findsOne : findsNothing);
      d.dispose();
    });
  }

  // At 720 wide, with the sidebar's 260, the header has 460: the least
  // needed parts fold, so ⋯ stays at its end (UX review, finding 6).
  testWidgets('the chat menu stays at the row’s end however narrow', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 300));
    final d = await FakeDaemon([]).connect(tester);
    const model = 'claude-opus-5-5[1m]';
    for (final pull in [false, true]) {
      for (final panel in [false, true]) {
        for (final (agent, failed, background) in [
          ('claude', false, 0),
          ('omp', true, 0),
          ('omp', false, 2), // "in background"
        ]) {
          final chat = ChatState('c', '/Users/me/repo')
            ..agent = agent
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
          for (var width = 320.0; width <= 1200; width += 10) {
            await tester.pumpWidget(
              MaterialApp(
                theme: const NushiTheme(Tokens.dark).toThemeData(),
                home: Scaffold(
                  body: Align(
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
              ),
            );
            final why = '$width wide, pull $pull, panel $panel';
            expect(tester.takeException(), isNull, reason: why);
            final menu = tester.getRect(find.byTooltip('Chat menu'));
            expect(menu.right, closeTo(width - 8, 1), reason: why);
          }
        }
      }
    }
    d.dispose();
  });

  testWidgets('at 460 the tabs are a menu, at 330 the terminal is in ⋯; '
      'wide, they are buttons', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..title = 'Fix the login redirect'
      ..pull = GitHubLink(number: 12, pull: true);
    ChatTab? picked;
    Future<void> pump(double width) => tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Align(
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
}
