import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The shell's motion (the fluidity review's idea 10): the terminal slides
// up laid out at its own height.

const _asked = 'Where is the login redirect handled?';

final _items = [
  Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: _asked),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'It is handled in the redirect module.',
  ),
];

/// The app 1700 wide on a chat, the details shown or not, its terminals
/// one shell's.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  bool details = false,
}) async {
  viewport(tester, const Size(1700, 700));
  showDetails.value = details;
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListTerminalsRequest(:final chatId) => ListTerminalsResponse(
        terminals: [
          Terminal(id: 't1', chatId: chatId, folder: '/tmp', shell: 'zsh'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) => input is AttachTerminalRequest
        ? (StreamController<AttachTerminalResponse>()
                ..add(AttachTerminalResponse(data: utf8.encode(r'$ '))))
              .stream
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The chat's transcript's box, as laid out (a glide only moves its drawing).
Size _transcript(WidgetTester tester) => tester.getSize(
  find.byWidgetPredicate((w) => w is Transcript && w.items == null),
);

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('the terminal slides up laid out at its own height: its '
      'shell is sized once', (tester) async {
    final (d, fake) = await _app(tester);
    int resizes() => fake.calls.whereType<ResizeTerminalRequest>().length;
    final chatHeight = _transcript(tester).height;

    terminalChats.value = {'c'};
    await tester.pump();
    final panel = find.byType(TerminalPanel);
    final full = tester.getSize(panel).height;
    expect(full, 260);
    await tester.pump();
    final sized = resizes();
    await tester.pump(Motion.enter ~/ 2);
    // Half-way: the slot part open, the panel whole under the clip.
    final top = tester.getTopLeft(panel).dy;
    expect(top, inExclusiveRange(700 - 260 - 22, 700 - 22));
    expect(tester.getSize(panel).height, full);
    expect(
      _transcript(tester).height,
      inExclusiveRange(chatHeight - 260, chatHeight),
    );
    await tester.pumpAndSettle();
    expect(resizes(), sized);
    expect(_transcript(tester).height, chatHeight - 260);

    terminalChats.value = {};
    await tester.pump();
    expect(panel, findsOneWidget); // it goes down whole
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(resizes(), sized);
    expect(_transcript(tester).height, chatHeight);
    await closeView(tester, d);
  }, variant: _mac);
}
