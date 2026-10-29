import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

ReviewComment _comment(String id, int line, String quote, String text) =>
    ReviewComment(
      id: id,
      where: 'uncommitted',
      path: 'sub.go',
      old: false,
      start: line,
      end: line,
      quote: quote,
      text: text,
    );

/// The app at [width] on chat c in a repository with sub.go changed, two
/// review comments made in its Changes view and not sent.
Future<Daemon> _app(WidgetTester tester, double width) async {
  viewport(tester, Size(width, 640), brightness: Brightness.dark);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  paneWidths.value = {};
  showDetails.value = false;
  final fake = FakeDaemon([chat('c', 'claude', 'Subtract')])
    ..answer = (input) => switch (input) {
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: 'subtract',
        defaultBase: 'main',
      ),
      GetDiffRequest() => GetDiffResponse(
        files: [
          FileChange(
            path: 'sub.go',
            oldText: 'package sub\n',
            newText:
                'package sub\n\nfunc Sub(a, b int) int {\n'
                '\treturn a - b\n}\n',
            added: 4,
          ),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  setComments('c', [
    _comment('1', 4, '\treturn a - b', 'Check for overflow.'),
    _comment('2', 3, 'func Sub(a, b int) int {', 'Name it Subtract.'),
  ]);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Finder _inHeader(String text) =>
    find.descendant(of: find.byType(ChatHeader), matching: find.text(text));

void main() {
  setUpAll(loadFonts);

  // UX review, finding 7: review comments go as reply cards, as a pull
  // request's do, and unsent ones show outside the Changes tab.
  testWidgets('unsent comments show in the header and over the box; Send '
      'to agent makes them reply cards; one taken out of the box is unsent '
      'again', (tester) async {
    final d = await _app(tester, 1700);
    final chat = d.chats['c']!;
    expect(_inHeader('Changes 2'), findsOne);
    expect(find.text('2 review comments in Changes aren’t sent.'), findsOne);
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/review_unsent_1700_dark.png'),
    );

    await tester.tap(find.text('Send to agent'));
    await tester.pumpAndSettle();
    final cards = chat.draft.replies.value;
    expect(cards.map((r) => r.text), [
      'Check for overflow.',
      'Name it Subtract.',
    ]);
    expect(cards.first.quote, '`sub.go`, line 4:\n```go\n\treturn a - b\n```');
    expect(unsentComments('c'), isEmpty);
    expect(_inHeader('Changes'), findsOne);
    expect(find.textContaining('aren’t sent'), findsNothing);

    // The second card removed, unsent: it's back.
    chat.draft.replies.value = [cards.first];
    await tester.pump(const Duration(seconds: 3));
    expect(unsentComments('c').map((c) => c.id), ['2']);
    expect(find.text('1 review comment in Changes isn’t sent.'), findsOne);
    d.dispose();
  }, variant: _mac);

  testWidgets('a sent message takes its cards: they stay sent', (tester) async {
    final d = await _app(tester, 1700);
    final chat = d.chats['c']!;
    reviewToBox(chat);
    final message = chat.draft.replies.value;
    // The composer sends: the box empties, the message reaches the
    // transcript.
    chat.draft.replies.value = const [];
    chat.items.add(
      Item(
        id: 'u',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text:
            '<!-- reply 1 -->\n> ${message[0].quote.split('\n').join('\n> ')}'
            '\n\n${message[0].text}\n\n<!-- reply 2 -->\n> '
            '${message[1].quote.split('\n').join('\n> ')}\n\n'
            '${message[1].text}\n\nThanks.',
      ),
    );
    chat.notifyListeners();
    await tester.pump(const Duration(seconds: 3));
    expect(unsentComments('c'), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('Changes: Send to agent (n), and the cards waiting with the '
      'way back to the chat, 720 wide', (tester) async {
    final d = await _app(tester, 720);
    await tester.tap(_inHeader('Changes 2'));
    await tester.pumpAndSettle();
    expect(find.text('Send to agent (2)'), findsOne);
    await tester.tap(find.text('Send to agent (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Send to agent (2)'), findsNothing);
    expect(
      find.text(
        "2 waiting in the chat's box. They go with your next message.",
        findRichText: true,
      ),
      findsOne,
    );
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/review_changes_720_dark.png'),
    );
    await tester.tap(find.text('Go to chat'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.tab.value.name, 'chat');
    d.dispose();
  }, variant: _mac);
}
