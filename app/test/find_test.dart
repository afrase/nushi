import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// UX review, finding 23: ⌘F in a transcript and in Changes.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _msg(String id, ItemKind kind, String text) =>
    Item(id: id, kind: kind, text: text);

/// The app on chat c, its transcript four messages, two naming the relay;
/// its Changes two files, one with Sub in it.
Future<Daemon> _app(WidgetTester tester) async {
  viewport(tester, const Size(1700, 700), brightness: Brightness.dark);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  paneWidths.value = {};
  showDetails.value = false;
  const user = ItemKind.ITEM_KIND_USER_MESSAGE;
  const agent = ItemKind.ITEM_KIND_AGENT_MESSAGE;
  final c = chat('c', 'claude', 'Flaky relay');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          _msg('u1', user, 'Why does the relay test fail?'),
          _msg('a1', agent, 'It waits on a fixed sleep.'),
          _msg('u2', user, 'Use a fake clock.'),
          _msg('a2', agent, 'Done: the relay test uses the fake clock now.'),
        ],
      ),
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: 'fix',
        defaultBase: 'main',
      ),
      GetDiffRequest() => GetDiffResponse(
        files: [
          FileChange(path: 'sub.go', newText: 'func Sub() {}\n', added: 1),
          FileChange(path: 'add.go', newText: 'func Add() {}\n', added: 1),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> _cmdF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

List<int> _marks(WidgetTester tester) => [
  for (final h in tester.widgetList<Hit>(find.byType(Hit))) h.mark,
];

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the chat: the entries that have it marked, ⏎ and ⇧⏎ '
      'through them, Esc closes', (tester) async {
    final d = await _app(tester);
    final chat = d.chats['c']!;
    await _cmdF(tester);
    expect(find.byType(FindBar), findsOne);
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      'relay',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOne);
    expect(_marks(tester).where((m) => m > 0).toList(), [2, 1]);
    expect(chat.find.current, 'u1');
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/find_chat_dark.png'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOne);
    expect(chat.find.current, 'a2');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(chat.find.current, 'u1');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
    expect(_marks(tester).where((m) => m > 0), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('⌘F in Changes: the files with the text, how many', (
    tester,
  ) async {
    final d = await _app(tester);
    d.chats['c']!.tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    await _cmdF(tester);
    expect(find.byType(FilesFilterField), findsOne);
    await tester.enterText(
      find.descendant(
        of: find.byType(FilesFilterField),
        matching: find.byType(EditableText),
      ),
      'sub(',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOne);
    expect(find.textContaining('add.go', findRichText: true), findsNothing);
    expect(find.textContaining('sub.go', findRichText: true), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FilesFilterField), findsNothing);
    expect(find.textContaining('add.go', findRichText: true), findsWidgets);
    d.dispose();
  }, variant: _mac);
}
