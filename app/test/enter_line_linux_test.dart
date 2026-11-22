import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// "Enter starts a new line" (ADR 0147) where Control is the command key,
// and the composer's box keeps one row whatever its hint says.

final _onLinux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The composer of a chat [width] wide, idle or with a turn running.
Future<(FakeDaemon, Daemon, ChatState)> _box(
  WidgetTester tester, {
  bool busy = false,
  double width = 640,
}) async {
  final fake = FakeDaemon([]);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  if (busy) {
    chat
      ..busy = true
      ..started = clock();
  }
  d.chats['c'] = chat;
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          child: ListenableBuilder(
            listenable: chat,
            builder: (context, _) => Composer(chat: chat, daemon: d),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (fake, d, chat);
}

Future<void> _write(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);
  setUp(() => native.conventions = linuxConventions);

  testWidgets('a long busy hint keeps the box one row: typed in, it is as '
      'tall as when idle', (tester) async {
    enterStartsLine.value = true;
    Future<double> height({required bool busy}) async {
      final (_, d, _) = await _box(tester, busy: busy, width: 440);
      await _write(tester, 'Also the README');
      final h = tester.getSize(find.byType(TextField)).height;
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      return h;
    }

    expect(await height(busy: true), await height(busy: false));
  }, variant: _onLinux);
}
