import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _text =
    'Wrote `docs/plan.md` and changed lib/main.dart:12 (see the '
    '[guide](https://x.dev/docs/guide.html)). There is no missing.md, '
    '`notes.txt` or v1.2.3, and Node.js stays a word.\n\n'
    '```\ndocs/plan.md\n```';

void main() {
  setUpAll(loadFonts);

  test('the paths a message names, as written, to the file', () {
    expect(namedFiles(_text), {
      'docs/plan.md': 'docs/plan.md',
      'notes.txt': 'notes.txt',
      'lib/main.dart:12': 'lib/main.dart',
      'missing.md': 'missing.md',
      'Node.js': 'Node.js',
    });
    expect(namedFiles('See /tmp/out.html, ./a.py and ~/b.md.'), {
      '/tmp/out.html': '/tmp/out.html',
      './a.py': './a.py',
    });
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final width in [720.0, 1700.0]) {
      testWidgets('the files a message names that are there open the preview '
          '(${width.round()}, $name)', (tester) async {
        viewport(tester, Size(width, 220));
        final fake = FakeDaemon([])
          ..answer = (input) => switch (input) {
            FindChatFilesRequest() => FindChatFilesResponse(
              found: ['docs/plan.md', 'lib/main.dart'],
            ),
            _ => null,
          };
        final d = await fake.connect(tester);
        final chat = ChatState('c', '/Users/me/repo')..agent = 'claude';
        final opened = <String>[];
        final item = Item(
          id: 'm',
          kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
          text: _text,
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Previews(
                open: opened.add,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ItemView(item, chat, d, live: false, still: false),
                      // The same message again: no second call.
                      Offstage(
                        child: ItemView(
                          item,
                          chat,
                          d,
                          live: false,
                          still: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final asks = fake.calls.whereType<FindChatFilesRequest>().toList();
        expect(asks, hasLength(1));
        expect(asks.single.paths.toSet(), {
          'docs/plan.md',
          'lib/main.dart',
          'missing.md',
          'notes.txt',
          'Node.js',
        });
        // Each a link in pieces, cut after its slashes.
        expect(find.byType(FileLink), findsNWidgets(4));
        await tester.tap(find.widgetWithText(FileLink, 'plan.md'));
        await tester.tap(find.widgetWithText(FileLink, 'lib/'));
        expect(opened, ['docs/plan.md', 'lib/main.dart']);

        // Underlined, all of it, while the pointer is over a piece.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getCenter(find.widgetWithText(FileLink, 'plan.md')),
        );
        await tester.pumpAndSettle();
        Text text(String s) => tester.widget<Text>(
          find.descendant(
            of: find.widgetWithText(FileLink, s),
            matching: find.byType(Text),
          ),
        );
        for (final piece in ['docs/', 'plan.md']) {
          expect(text(piece).style?.decoration, TextDecoration.underline);
        }
        for (final piece in ['lib/', 'main.dart:12']) {
          expect(
            text(piece).style?.decoration,
            isNot(TextDecoration.underline),
          );
        }
        if (width == 720) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/file_links_$name.png'),
          );
        }
        d.dispose();
      });
    }
  }

  for (final width in [720.0, 1700.0]) {
    testWidgets('a long path wraps between its folders, clear of the '
        'text after it (${width.round()})', (tester) async {
      const path =
          '/Users/me/Developer/a-long-project-name/work/out/'
          'export-records-0123456789-raw.json';
      viewport(tester, Size(width, 200));
      final fake = FakeDaemon([])
        ..answer = (input) => switch (input) {
          FindChatFilesRequest() => FindChatFilesResponse(found: [path]),
          _ => null,
        };
      final d = await fake.connect(tester);
      final chat = ChatState('c', '/Users/me/repo')..agent = 'claude';
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Scaffold(
            body: Previews(
              open: (_) {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 420,
                    child: ItemView(
                      Item(
                        id: 'm',
                        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                        text:
                            'The records:\n\n'
                            '- `$path`: the first export\n'
                            '- `$path` again, then more words after it\n',
                      ),
                      chat,
                      d,
                      live: false,
                      still: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FileLink), findsWidgets);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/file_links_long_${width.round()}.png'),
      );
      d.dispose();
    });
  }

  testWidgets('a message still streaming has no links and asks nothing', (
    tester,
  ) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/Users/me/repo');
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Previews(
            open: (_) {},
            child: ItemView(
              Item(
                id: 'm',
                kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                text: _text,
              ),
              chat,
              d,
              live: true,
              still: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(fake.calls.whereType<FindChatFilesRequest>(), isEmpty);
    expect(find.byType(FileLink), findsNothing);
    d.dispose();
  });
}
