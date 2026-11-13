import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Esc in the chat stops its turn (chat_view.dart); an Esc that closes the
// box's choices is that and nothing more, since stopping a long turn by
// mistake costs real work.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The app on chat c, its turn running, the box focused; claude's
/// /compact among its commands.
Future<(Daemon, FakeDaemon)> _app(WidgetTester tester) async {
  viewport(tester, const Size(1400, 800));
  final c = chat('c', 'claude', 'Fix the login redirect');
  final status = ChatStatus(
    busy: true,
    started: Int64(clock().millisecondsSinceEpoch),
  );
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest(chatId: 'c') => GetChatResponse(chat: c, status: status),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  fake.emit(EventsResponse(chatId: 'c', seq: Int64(9), status: status));
  await tester.pump();
  d.chats['c']!.commands = [Command(name: 'compact', description: 'Compact')];
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return (d, fake);
}

int _stops(FakeDaemon fake) => fake.calls.whereType<CancelTurnRequest>().length;

void main() {
  setUpAll(loadFonts);

  testWidgets('Esc stops the turn', (tester) async {
    final (d, fake) = await _app(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final stop = fake.calls.whereType<CancelTurnRequest>().single;
    expect((stop.chatId, stop.takeBack), ('c', true));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('an Esc that closes the box’s choices doesn’t stop the turn; '
      'the next does', (tester) async {
    final (d, fake) = await _app(tester);
    await tester.enterText(find.byType(TextField), '/comp');
    await tester.pump();
    expect(find.textContaining('/compact', findRichText: true), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining('/compact', findRichText: true), findsNothing);
    expect(_stops(fake), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_stops(fake), 1);
    await closeView(tester, d);
  }, variant: _mac);
}
