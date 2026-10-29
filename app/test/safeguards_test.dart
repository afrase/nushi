import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A response Claude's safeguards stopped, as the daemon keeps it: what
/// streamed of it, marked; Claude Code's notice; the reply it went on with.
final _items = [
  Item(
    id: 'msg_1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    status: 'stopped_by_safeguards',
    text: 'Here is the first part of an answer',
  ),
  Item(
    id: 'item-1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'agent_notice',
    text:
        "Opus 5.5's safeguards stopped the response above · continuing "
        'once with that noted',
  ),
  Item(
    id: 'msg_2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Continued reply after the stop.',
  ),
  Item(
    id: 'item-2',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'agent_warning',
    text: 'Stop hook blocked: the tests fail',
  ),
];

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final width in [720.0, 1700.0]) {
      testWidgets('a response stopped by safeguards is folded above the '
          'notice (${width.round()}, $name)', (tester) async {
        viewport(tester, Size(width, 300));
        final chat = ChatState('c', '/Users/me/repo')..agent = 'claude';
        final d = await FakeDaemon([]).connect(tester);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (final it in _items)
                      ItemView(it, chat, d, live: false, still: false),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Stopped by safeguards'), findsOneWidget);
        expect(find.text('Here is the first part of an answer'), findsNothing);
        await tester.tap(find.text('Stopped by safeguards'));
        await tester.pumpAndSettle();
        expect(
          find.text('Here is the first part of an answer'),
          findsOneWidget,
        );
        // Notice lines, not messages: no bold label.
        expect(find.textContaining('**'), findsNothing);
        if (width == 720) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/safeguards_$name.png'),
          );
        }
        d.dispose();
      });
    }
  }
}
