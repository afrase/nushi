import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// "Enter starts a new line" (ADR 0147) where Control is the command key:
// the keys that send, queue, stop and send or start a line, held keys,
// a locked box, and the box kept one row whatever its hint says.

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

/// Enter pressed with [holding] held.
Future<void> _enter(
  WidgetTester tester, [
  List<LogicalKeyboardKey> holding = const [],
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pump();
}

String _typed(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

List<SendPromptRequest> _sent(FakeDaemon fake) =>
    fake.calls.whereType<SendPromptRequest>().toList();

void main() {
  setUpAll(loadFonts);
  setUp(() => native.conventions = linuxConventions);

  testWidgets('Linux, on: Ctrl+Enter sends and queues, Ctrl+Shift+Enter '
      'stops and sends, Super+Enter starts a line; the hint says so', (
    tester,
  ) async {
    enterStartsLine.value = true;
    final (fake, d, _) = await _box(tester, busy: true);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      'Ctrl+Enter queues it, Ctrl+Shift+Enter stops Claude and sends',
    );
    await _write(tester, 'ab');
    expect(find.byTooltip('Queue Ctrl+Enter'), findsOne);
    expect(find.byTooltip('Stop and send Ctrl+Shift+Enter'), findsOne);
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    await _enter(tester);
    expect(_typed(tester), 'ab\n\n');
    await _enter(tester, [LogicalKeyboardKey.controlLeft]);
    await _write(tester, 'now');
    await _enter(tester, [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
    ]);
    await tester.pump();
    expect(
      [for (final s in _sent(fake)) (s.text, s.now)],
      [('ab', false), ('now', true)],
    );
    expect(_sent(fake).first.queue, isTrue);
    d.dispose();
  }, variant: _onLinux);

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

  testWidgets('locked, on: no Enter does a thing', (tester) async {
    enterStartsLine.value = true;
    final (fake, d, chat) = await _box(tester);
    await _write(tester, 'ab');
    chat.rewinding.value = true;
    await tester.pump();
    for (final held in [
      const <LogicalKeyboardKey>[],
      [LogicalKeyboardKey.controlLeft],
      [LogicalKeyboardKey.shiftLeft],
    ]) {
      await _enter(tester, held);
    }
    expect(_typed(tester), 'ab');
    expect(_sent(fake), isEmpty);
    chat.rewinding.value = false;
    d.dispose();
  }, variant: _onLinux);

  testWidgets('on: Ctrl+Enter held sends once; Enter held starts a line '
      'per repeat', (tester) async {
    enterStartsLine.value = true;
    final (fake, d, _) = await _box(tester);
    await _write(tester, 'a');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_typed(tester), 'a\n\n');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_sent(fake).length, 1);
    d.dispose();
  }, variant: _onLinux);
}
