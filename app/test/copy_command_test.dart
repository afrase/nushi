import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/copy_command.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _agent(String id, String text, {String parent = ''}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
  text: text,
  parent: parent,
);

ChatState _chat() => ChatState('c', '/x')
  ..agent = 'claude'
  ..loaded = true
  ..items.addAll([
    _agent('a', 'First, **bold**'),
    Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'And?'),
    _agent('b', '# Second\n\n- a list\n\n```go\nx := 1\n```\n'),
    _agent('s', 'A subagent’s', parent: 'call'),
  ]);

/// The box of [chat], and what's copied, last first.
Future<(FakeDaemon, Daemon, List<String>)> _box(
  WidgetTester tester,
  ChatState chat,
) async {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.insert(0, (call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  final fake = FakeDaemon([]);
  final d = await fake.connect(tester);
  d.chats['c'] = chat;
  await tester.pumpWidget(themed(Composer(chat: chat, daemon: d)));
  await tester.pump();
  return (fake, d, copied);
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape); // the choices
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  test('what asks for a copy', () {
    expect(copyAsked('/copy'), 1);
    expect(copyAsked('/copy  2'), 2);
    expect(copyAsked('/copy 99999999999999999999999'), 0);
    expect(copyAsked('/copyright'), isNull);
    expect(copyAsked('/copy that file'), isNull);
    expect(copyAsked('please /copy'), isNull);
  });

  test('the agent’s messages from the latest, without a subagent’s', () {
    final chat = _chat();
    expect(agentMessage(chat, 1), startsWith('# Second'));
    expect(agentMessage(chat, 2), 'First, **bold**');
    expect(agentMessage(chat, 3), isNull);
    expect(agentMessage(chat, 0), isNull);
  });

  testWidgets('/copy puts the Markdown on the clipboard and tells the agent '
      'nothing', (tester) async {
    final (fake, d, copied) = await _box(tester, _chat());
    await _send(tester, '/copy');
    expect(copied.single, '# Second\n\n- a list\n\n```go\nx := 1\n```\n');
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);

    await _send(tester, '/copy 2');
    expect(copied.first, 'First, **bold**');
    d.dispose();
  }, variant: _mac);

  testWidgets('it’s offered with the agent’s commands, in place of its own', (
    tester,
  ) async {
    final chat = _chat()
      ..commands = [Command(name: 'copy'), Command(name: 'cost')];
    final (_, d, _) = await _box(tester, chat);
    await tester.enterText(find.byType(TextField), '/co');
    await tester.pump();
    expect(find.textContaining('/copy', findRichText: true), findsOneWidget);
    expect(find.textContaining('/cost', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Copy the agent’s last message', findRichText: true),
      findsOneWidget,
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('commands that come after `/` was typed are offered', (
    tester,
  ) async {
    final chat = _chat();
    final (_, d, _) = await _box(tester, chat);
    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();
    expect(find.textContaining('/compact', findRichText: true), findsNothing);
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        commands: ChatCommands(commands: [Command(name: 'compact')]),
      ),
    );
    await tester.pump();
    expect(find.textContaining('/compact', findRichText: true), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('with no message it says so; a turn running makes no '
      'difference', (tester) async {
    final (fake, d, copied) = await _box(
      tester,
      ChatState('c', '/x')
        ..agent = 'claude'
        ..loaded = true
        ..busy = true,
    );
    await _send(tester, '/copy');
    await tester.pump();
    expect(copied, isEmpty);
    expect(find.text('No agent message to copy'), findsOneWidget);
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    d.dispose();
  }, variant: _mac);
}
