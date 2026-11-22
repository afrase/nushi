import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'spell_harness.dart';

// The boxes that send with Settings › General's "Enter starts a new line"
// on (ADR 0147): Enter starts a line, ⌘⏎ sends (and queues while a turn
// runs), ⇧⌘⏎ stops the turn and sends; the keys shown say so, and follow
// the setting as it changes. A menu over the box still takes Enter.

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

const List<LogicalKeyboardKey> _cmd = [LogicalKeyboardKey.metaLeft];
const List<LogicalKeyboardKey> _shiftCmd = [
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.metaLeft,
];

/// The composer of a chat, idle or with a turn running ([busy]), with
/// /plan among its commands.
Future<(FakeDaemon, Daemon, ChatState)> _box(
  WidgetTester tester, {
  bool busy = false,
}) async {
  final fake = FakeDaemon([]);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true
    ..commands = [Command(name: 'plan', description: 'Plan')];
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
          width: 640,
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

TextEditingController _text(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!;

Future<void> _write(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

List<SendPromptRequest> _sent(FakeDaemon fake) =>
    fake.calls.whereType<SendPromptRequest>().toList();

String _hint(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!.hintText!;

void main() {
  setUpAll(loadFonts);

  testWidgets('idle: Enter and ⇧⏎ start a line, Enter continues a list; '
      '⌘⏎ sends, as Send says', (tester) async {
    enterStartsLine.value = true;
    final (fake, d, _) = await _box(tester);
    await _write(tester, 'ab');
    expect(find.byTooltip('Send\u2002⌘⏎'), findsOne);
    await _enter(tester);
    await _enter(tester, [LogicalKeyboardKey.shiftLeft]);
    expect(_text(tester).text, 'ab\n\n');
    await _write(tester, '1. one');
    await _enter(tester);
    expect(_text(tester).text, '1. one\n2. ');
    expect(_sent(fake), isEmpty);
    await _write(tester, 'go');
    await _enter(tester, _cmd);
    await tester.pumpAndSettle();
    expect((_sent(fake).single.text, _sent(fake).single.now), ('go', false));
    // Off again, without a restart: Enter sends, as Send says.
    enterStartsLine.value = false;
    await _write(tester, 'again');
    expect(find.byTooltip('Send\u2002⏎'), findsOne);
    await _enter(tester);
    await tester.pumpAndSettle();
    expect(_sent(fake).last.text, 'again');
    d.dispose();
  }, variant: onMac);

  testWidgets('a turn running: ⌘⏎ queues, ⇧⌘⏎ stops and sends, Enter '
      'starts a line; the hint and the buttons say so', (tester) async {
    enterStartsLine.value = true;
    final (fake, d, _) = await _box(tester, busy: true);
    expect(_hint(tester), '⌘⏎ queues it, ⇧⌘⏎ stops Claude and sends');
    await _write(tester, 'next');
    expect(find.byTooltip('Queue\u2002⌘⏎'), findsOne);
    expect(find.byTooltip('Stop and send\u2002⇧⌘⏎'), findsOne);
    await _enter(tester);
    expect(_text(tester).text, 'next\n');
    await _write(tester, 'later');
    await _enter(tester, _cmd);
    await tester.pump();
    expect(
      (
        _sent(fake).single.text,
        _sent(fake).single.queue,
        _sent(fake).single.now,
      ),
      ('later', true, false),
    );
    await _write(tester, 'now');
    await _enter(tester, _shiftCmd);
    await tester.pump();
    expect((_sent(fake).last.text, _sent(fake).last.now), ('now', true));
    d.dispose();
  }, variant: onMac);

  testWidgets('a turn running, off: Enter queues, ⌘⏎ stops and sends, '
      '⇧⌘⏎ starts a line, as before; the keys shown change with the '
      'setting', (tester) async {
    final (fake, d, _) = await _box(tester, busy: true);
    expect(_hint(tester), '⏎ queues it, ⌘⏎ stops Claude and sends');
    await _write(tester, 'ab');
    expect(find.byTooltip('Queue\u2002⏎'), findsOne);
    expect(find.byTooltip('Stop and send\u2002⌘⏎'), findsOne);
    await _enter(tester, _shiftCmd);
    expect(_text(tester).text, 'ab\n');
    await _enter(tester);
    await tester.pump();
    expect((_sent(fake).single.queue, _sent(fake).single.now), (true, false));
    await _write(tester, 'now');
    await _enter(tester, _cmd);
    await tester.pump();
    expect((_sent(fake).last.text, _sent(fake).last.now), ('now', true));
    await _write(tester, 'x');
    enterStartsLine.value = true;
    await tester.pump();
    expect(find.byTooltip('Queue\u2002⌘⏎'), findsOne);
    expect(find.byTooltip('Stop and send\u2002⇧⌘⏎'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets('the commands’ list over the box still takes Enter', (
    tester,
  ) async {
    enterStartsLine.value = true;
    final (fake, d, _) = await _box(tester);
    await _write(tester, '/pl');
    expect(find.textContaining('/plan', findRichText: true), findsOne);
    await _enter(tester);
    expect(_text(tester).text, '/plan ');
    expect(_sent(fake), isEmpty);
    d.dispose();
  }, variant: onMac);

  for (final lines in [false, true]) {
    testWidgets('the commands’ list takes the keypad’s Enter too '
        '(Enter starts a new line: $lines)', (tester) async {
      enterStartsLine.value = lines;
      final (fake, d, _) = await _box(tester);
      await _write(tester, '/pl');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();
      expect(_text(tester).text, '/plan ');
      expect(_sent(fake), isEmpty);
      d.dispose();
    }, variant: onMac);
  }

  spellTest('the spelling menu over the box still takes Enter', (tester) async {
    enterStartsLine.value = true;
    final (_, chat) = await spellBox(
      tester,
      FakeSpeller(
        {'chekc'},
        fixes: {
          'chekc': ['check'],
        },
      ),
    );
    await typed(tester, 'please chekc this ');
    await chat.draft.text.spell!.menu.next();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chat.draft.text.text, 'please check this ');
    expect(chat.draft.text.spell!.menu.controller.isOpen, isFalse);
    expect(sentPrompts(), isEmpty);
  });

  testWidgets('a reply box: Enter starts a line, ⌘⏎ adds it, as its '
      'button says', (tester) async {
    enterStartsLine.value = true;
    final replies = <Reply>[];
    await tester.pumpWidget(
      themed(
        Center(
          child: ReplyBox(
            quote: 'a line',
            onReply: replies.add,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Add to the message\u2002⌘⏎'), findsOne);
    await _write(tester, 'ab');
    await _enter(tester);
    expect(_text(tester).text, 'ab\n');
    expect(replies, isEmpty);
    await _enter(tester, _cmd);
    expect(replies.single.text, 'ab');
  }, variant: onMac);

  testWidgets('a subagent’s box: Enter starts a line, ⌘⏎ sends', (
    tester,
  ) async {
    enterStartsLine.value = true;
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final c = ChatState('c', '/tmp')
      ..agent = 'claude'
      ..items.add(
        Item(
          id: 'a',
          kind: ItemKind.ITEM_KIND_TOOL_CALL,
          agent: 'Explore',
          agentId: 'ab59',
          title: 'Find the redirect',
          status: 'in_progress',
          subagent: Subagent(state: 'running'),
        ),
      );
    await tester.pumpWidget(
      themed(SubagentPane(chat: c, daemon: d, id: 'a', onClose: () {})),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await _write(tester, 'ab');
    await _enter(tester);
    expect(_text(tester).text, 'ab\n');
    expect(_sent(fake), isEmpty);
    await _enter(tester, _cmd);
    await tester.pump();
    expect(
      (_sent(fake).single.text, _sent(fake).single.toSubagent),
      ('ab', 'a'),
    );
    await closeView(tester, d);
  }, variant: onMac);
}
