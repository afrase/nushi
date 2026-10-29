import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

// UX review, finding 16: while a turn runs, the Mac's box has Queue and
// Steer as buttons too (they were ⏎ and ⌘⏎ only), and a queued message
// can be sent now.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A box for a chat whose turn runs, with one message queued.
Future<(FakeDaemon, Daemon, ChatState)> _box(WidgetTester tester) async {
  final fake = FakeDaemon([])
    ..answer = (input) => input is UnqueueRequest
        ? UnqueueResponse(
            message: QueuedMessage(id: 'q1', text: 'Then docs'),
          )
        : null;
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true
    ..busy = true
    ..started = DateTime.now()
    ..queue = [QueuedMessage(id: 'q1', text: 'Then docs')];
  d.chats['c'] = chat;
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            key: const Key('box'),
            child: Container(
              width: 640,
              color: Tokens.dark.base,
              child: Padding(
                padding: const EdgeInsets.all(12),
                // As the chat's view, which builds it again as it changes.
                child: ListenableBuilder(
                  listenable: chat,
                  builder: (context, _) => Composer(chat: chat, daemon: d),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (fake, d, chat);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('written while a turn runs: Queue and Steer beside Stop', (
    tester,
  ) async {
    final (fake, d, _) = await _box(tester);
    expect(find.byTooltip('Queue (⏎)'), findsNothing); // nothing written
    await tester.enterText(find.byType(TextField), 'Also the README');
    await tester.pump();
    expect(find.byTooltip('Queue (⏎)'), findsOne);
    expect(find.byTooltip('Steer: stop and send now (⌘⏎)'), findsOne);
    expect(find.byTooltip('Stop (esc)'), findsOne);
    await expectLater(
      find.byKey(const Key('box')),
      matchesGoldenFile('goldens/composer_turn_dark.png'),
    );
    await tester.tap(find.byTooltip('Steer: stop and send now (⌘⏎)'));
    await tester.pump();
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect((sent.text, sent.now), ('Also the README', true));
    await tester.enterText(find.byType(TextField), 'And the tests');
    await tester.pump();
    await tester.tap(find.byTooltip('Queue (⏎)'));
    await tester.pump();
    final queued = fake.calls.whereType<SendPromptRequest>().last;
    expect(
      (queued.text, queued.queue, queued.now),
      ('And the tests', true, false),
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('a queued message sent now: out of the queue, then in place '
      'of the turn', (tester) async {
    final (fake, d, chat) = await _box(tester);
    await tester.tap(find.byTooltip('Send now: stop the turn and send it'));
    await tester.pump();
    expect(fake.calls.whereType<UnqueueRequest>().single.id, 'q1');
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect((sent.text, sent.now), ('Then docs', true));
    // No turn: nothing to send it in place of.
    chat.apply(EventsResponse(seq: Int64(1), status: ChatStatus()));
    await tester.pump();
    expect(find.byTooltip('Send now: stop the turn and send it'), findsNothing);
    d.dispose();
  }, variant: _mac);
}
