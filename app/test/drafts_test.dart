import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/drafts_mac.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone_drafts.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

// The owner: "Save what the user types into the input box. I have a large
// message, and if the app crashed or reset, it would suck to lose it."

const _wait = Duration(milliseconds: 500);

/// The app on a fake daemon with chats "c" and "d", keeping its drafts in
/// [dir], and chat "c"'s box.
Future<(FakeDaemon, Daemon, Drafts)> _app(
  WidgetTester tester,
  Directory dir,
) async {
  final fake = FakeDaemon([
    Chat(id: 'c', folder: '/x', agent: 'claude'),
    Chat(id: 'd', folder: '/x', agent: 'claude'),
  ]);
  final drafts = Drafts(DraftFiles(dir.path));
  final d = await fake.connect(tester, drafts: drafts);
  final chat = d.chats['c']!..loaded = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: Composer(chat: chat, daemon: d),
      ),
    ),
  );
  return (fake, d, drafts);
}

Future<void> _close(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(const SizedBox());
  d.dispose(); // its ping timer
  await tester.pump(const Duration(seconds: 4)); // and the ping's timeout
}

Directory _dir() {
  final dir = Directory.systemTemp.createTempSync('drafts');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  testWidgets('typed, then the app restarts: the draft is back', (
    tester,
  ) async {
    final dir = _dir();
    final json = File('${dir.path}/drafts.json');
    final (_, d, _) = await _app(tester, dir);
    final draft = d.chats['c']!.draft;
    await tester.enterText(find.byType(TextField), 'A long message @a.go');
    draft
      ..text.selection = const TextSelection(baseOffset: 2, extentOffset: 6)
      ..mentions.add('a.go')
      ..addReply((quote: 'the old line', text: 'why?', from: 'Copilot'))
      ..subagentBox('call-1').text = 'and the tests';
    draft.images.value = [
      ImageData(mimeType: 'image/png', data: Uint8List.fromList([1, 2, 3])),
    ];
    await tester.pump(_wait - const Duration(milliseconds: 100));
    expect(json.existsSync(), isFalse); // still typing
    await tester.pump(const Duration(milliseconds: 100));
    expect(json.existsSync(), isTrue);
    expect(json.statSync().modeString(), 'rw-------');
    final images = Directory('${dir.path}/drafts').listSync();
    expect(images, hasLength(1));
    expect((images.single as File).statSync().modeString(), 'rw-------');
    await _close(tester, d);

    // A new run, from what's on disk.
    final (_, d2, drafts2) = await _app(tester, dir);
    await drafts2.loaded;
    final back = d2.chats['c']!.draft;
    expect(back.text.text, 'A long message @a.go');
    expect(back.text.selection.baseOffset, 2);
    expect(back.text.selection.extentOffset, 6);
    expect(back.mentions, {'a.go'});
    expect(back.replies.value, [
      (quote: 'the old line', text: 'why?', from: 'Copilot'),
    ]);
    expect(back.subagentBox('call-1').text, 'and the tests');
    expect(back.images.value.single.data, [1, 2, 3]);
    expect(d2.chats['d']!.draft.isEmpty, isTrue);
    expect(find.text('A long message @a.go'), findsOneWidget);
    await _close(tester, d2);
  });

  testWidgets('a message over 1 MB is kept whole', (tester) async {
    final dir = _dir();
    final (_, d, drafts) = await _app(tester, dir);
    final big = 'x' * (1 << 20) + 'end';
    d.chats['d']!.draft.text.text = big;
    await drafts.flush();
    final kept = jsonDecode(
      File('${dir.path}/drafts.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(kept['d'], containsPair('text', big));
    await _close(tester, d);
  });

  testWidgets('sending clears it at once', (tester) async {
    final dir = _dir();
    final json = File('${dir.path}/drafts.json');
    final (fake, d, _) = await _app(tester, dir);
    await tester.enterText(find.byType(TextField), 'Ship it');
    await tester.pump(_wait);
    expect(json.existsSync(), isTrue);
    await tester.tap(find.byTooltip('Send (⏎)'));
    await tester.pump();
    expect(fake.calls.whereType<SendPromptRequest>().single.text, 'Ship it');
    expect(json.existsSync(), isFalse);
    await _close(tester, d);
  });

  testWidgets('archiving or deleting a chat removes its draft', (tester) async {
    final dir = _dir();
    final json = File('${dir.path}/drafts.json');
    final (fake, d, drafts) = await _app(tester, dir);
    d.chats['c']!.draft.text.text = 'for c';
    d.chats['d']!.draft.text.text = 'for d';
    await tester.pump(_wait);
    expect(drafts.ids, {'c', 'd'});
    fake.emit(
      EventsResponse(
        chatId: 'c',
        chat: Chat(id: 'c', folder: '/x', agent: 'claude', archived: true),
      ),
    );
    await tester.pump();
    expect(drafts.ids, {'d'});
    expect(json.readAsStringSync(), isNot(contains('for c')));
    fake.emit(EventsResponse(chatId: 'd', removed: true));
    await tester.pump();
    expect(drafts.ids, isEmpty);
    expect(json.existsSync(), isFalse);
    await _close(tester, d);
  });

  testWidgets("an empty draft isn't written", (tester) async {
    final dir = _dir();
    final (_, d, _) = await _app(tester, dir);
    await tester.enterText(find.byType(TextField), 'oops');
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump(_wait * 2);
    expect(File('${dir.path}/drafts.json').existsSync(), isFalse);
    expect(Directory('${dir.path}/drafts').existsSync(), isFalse);
    await _close(tester, d);
  });

  test("the phone's drafts come back from IndexedDB after a reload", () async {
    final platform = PhonePlatform();
    final drafts = Drafts(PhoneDrafts(platform));
    final chat = ChatState('c', '/x');
    drafts.attach(chat);
    chat.draft
      ..text.text = 'From the bus'
      ..addReply((quote: 'a line', text: 'fix this', from: ''));
    chat.draft.images.value = [
      ImageData(mimeType: 'image/png', data: Uint8List.fromList([1])),
    ];
    await drafts.flush();
    expect(platform.drafts, contains('From the bus'));

    // The page reloads: a new app on the same storage.
    final again = Drafts(PhoneDrafts(platform));
    final back = ChatState('c', '/x');
    again.attach(back);
    await again.loaded;
    expect(back.draft.text.text, 'From the bus');
    expect(back.draft.replies.value.single.text, 'fix this');
    expect(back.draft.images.value, isEmpty); // text and cards only

    await platform.clear(); // Forget this Mac
    expect(platform.drafts, isNull);
  });
}
