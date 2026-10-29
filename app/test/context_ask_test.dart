import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  testWidgets('what fills the context is asked, the card collapsed or not, '
      'once the chat can be asked', (tester) async {
    collapsedCards.value = {'Context'};
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: '/x')]);
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/x')
      ..apply(
        EventsResponse(status: ChatStatus(busy: true, canAskContext: true)),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: DetailsPanel(chat: chat, daemon: d, onChanges: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    int asked() => fake.calls.whereType<GetContextUsageRequest>().length;
    expect(asked(), 0, reason: 'busy: not yet');

    // The turn ends: asked a moment later, though the card is collapsed.
    chat.apply(EventsResponse(status: ChatStatus(canAskContext: true)));
    await tester.pump(const Duration(seconds: 2));
    expect(asked(), 1);
    expect(find.byIcon(Icons.refresh), findsNothing);
    await closeView(tester, d);
  });
}
