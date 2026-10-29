import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

import 'fake_daemon.dart';

void main() {
  testWidgets('the card shows what runs, by file, and waits for a word', (
    tester,
  ) async {
    final ask = TrustAsk('/src/repo', 'Start a chat', [
      FolderRun(
        file: '/src/repo/.mcp.json',
        what: 'MCP server echo',
        command: 'echo hi',
      ),
      FolderRun(
        file: '/src/.mcp.json',
        what: 'MCP server up',
        command: 'up --x',
      ),
      FolderRun(
        file: '/src/repo/.mcp.json',
        what: 'MCP server web',
        command: 'https://e.com',
      ),
    ], 'claude');
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: TrustCard(ask)),
      ),
    );
    expect(find.text('.mcp.json'), findsOneWidget); // in the folder: relative
    expect(find.text('/src/.mcp.json'), findsOneWidget); // above it: whole
    expect(find.textContaining('echo hi', findRichText: true), findsOneWidget);
    expect(find.textContaining('up --x', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Start anyway'));
    expect(await ask.answer.future, isTrue);
  });

  // UX review, finding 20: going elsewhere while the card asks is a no,
  // and the app says so, where the start just didn't happen before.
  testWidgets("leaving the card unanswered says what didn't start; × "
      'dismisses it', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 600);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await loadFonts();
    final fake = FakeDaemon([chat('a', 'claude', 'Other')])
      ..answer = (input) => input is CheckFolderRequest
          ? CheckFolderResponse(
              runs: [FolderRun(file: '/Users/me/site/.mcp.json', what: 'x')],
            )
          : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    final start = d.startChat('/Users/me/site', 'claude');
    await tester.pumpAndSettle();
    expect(find.byType(TrustCard), findsOne);
    d.select('a'); // walked away
    await tester.pumpAndSettle();
    await start;
    expect(fake.started, isEmpty);
    expect(
      find.text("Didn't start Claude in site: its code wasn't approved."),
      findsOne,
    );
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/trust_left_dark.png'),
    );
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeBar), findsNothing);
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  test('what each unanswered card says', () {
    for (final (action, said) in [
      ('Start a chat', "Didn't start Codex in site"),
      ('Open the session', "Didn't open the session in site"),
      ('Move the chat', "Didn't move the chat to site"),
    ]) {
      expect(
        TrustAsk('/Users/me/site', action, [], 'codex').left,
        "$said: its code wasn't approved.",
      );
    }
  });
}
