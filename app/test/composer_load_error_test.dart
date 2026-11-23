// The Mac composer's line while a chat's load fails and tries again: in
// the whole window, wide and narrow, dark and light
// (`make renders TEST=test/composer_load_error_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final Chat _chat = chat('c', 'claude', 'Read the spec');

const _line =
    "Couldn't load the chat, trying again: The daemon took too long to "
    'answer.';

void main() {
  setUpAll(loadFonts);

  for (final width in [1700.0, 720.0]) {
    for (final dark in [true, if (rendering) false]) {
      final name = '${width.round()}_${dark ? 'dark' : 'light'}';
      testWidgets('the window at $name: a chat that fails to load says so '
          'over the box, on a fill of its own', (tester) async {
        viewport(
          tester,
          Size(width, 900),
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        sidebarHidden.value = true;
        final d =
            await (FakeDaemon([_chat])
                  ..answer = (input) => input is GetChatRequest
                      ? GetChatResponse(
                          chat: _chat,
                          items: [
                            Item(
                              id: 'a',
                              kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                              text: 'The spec asks for three retries.',
                            ),
                          ],
                        )
                      : null)
                .connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.chats['c']!
          ..loadError = 'The daemon took too long to answer.'
          ..notifyListeners();
        await tester.pumpAndSettle();

        final line = find.text(_line);
        expect(line, findsOneWidget);
        // A problem's card (Notice), above the box and as wide as it.
        final notice = find.ancestor(of: line, matching: find.byType(Notice));
        expect(notice, findsOneWidget);
        final box = find
            .descendant(
              of: find.byType(Composer),
              matching: find.byType(TextField),
            )
            .first;
        expect(
          tester.getBottomLeft(notice).dy,
          lessThan(tester.getTopLeft(box).dy),
        );
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'load_error_$name');
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
