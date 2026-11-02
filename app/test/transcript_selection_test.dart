import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

/// The app on [items] (each chat's, by id), the first chat shown.
Future<Daemon> _app(WidgetTester tester, Map<String, List<Item>> items) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final chats = {for (final id in items.keys) id: chat(id, 'claude', id)};
  final fake = FakeDaemon(chats.values.toList())
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: chats[input.chatId], items: items[input.chatId])
        : null;
  final d = await fake.connect(tester);
  d.select(items.keys.first);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// A drag from [from] to [to], as a mouse makes it.
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(Offset.lerp(from, to, .5)!);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
}

/// Where [word] starts and ends in the paragraph that has it.
(Offset, Offset) _ends(WidgetTester tester, String word) {
  final text = tester.renderObject<RenderParagraph>(
    find.textContaining(word, findRichText: true).last,
  );
  final i = text.text.toPlainText().indexOf(word);
  final box = text
      .getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + word.length),
      )
      .first
      .toRect();
  return (
    text.localToGlobal(box.centerLeft + const Offset(1, 0)),
    text.localToGlobal(box.centerRight - const Offset(1, 0)),
  );
}

/// What Reply quotes of the selection; it closes again.
Future<String> _quoted(WidgetTester tester) async {
  await tester.tap(find.text('Reply').last);
  await tester.pump();
  final quote = tester.widget<ReplyBox>(find.byType(ReplyBox)).quote;
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  return quote;
}

Item _agent(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

void main() {
  setUpAll(loadFonts);
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('a selection made as a chat fills in is what was dragged over', (
    tester,
  ) async {
    final d = await _app(tester, {
      'a': longChat('a'),
      'b': [...longChat('b'), _agent('z', 'The last words of the chat.')],
    });
    d.select('b');
    await tester.pump();
    await tester.pump();
    final (from, to) = _ends(tester, 'last words');
    await _drag(tester, from, to);
    expect(await _quoted(tester), 'last words');
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('selections one after another each quote only themselves, '
      'with a wide code block above them', (tester) async {
    final wide = 'wide ' * 80;
    final d = await _app(tester, {
      'a': [
        _agent('o', 'Old words.\n\n```\nblock start $wide\n```\n\nOld end.'),
        _agent('n', 'First pick and second pick.'),
      ],
    });
    for (final (word, times) in [
      ('block start', 1),
      ('First pick', 1),
      ('second pick', 2),
      ('Old words', 1),
    ]) {
      for (var i = 0; i < times; i++) {
        final (from, to) = _ends(tester, word);
        await _drag(tester, from, to);
        expect(await _quoted(tester), word);
      }
    }
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a drag starting left of an old code block leaves it out, '
      'wherever the block is', (tester) async {
    const block = 'Fenced:\n\n```\nprose one\nprose two\n```';
    final d = await _app(tester, {
      'a': [
        _agent('o', block),
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: block),
        _agent('n', 'First pick.'),
      ],
    });
    final (from, to) = _ends(tester, 'First pick');
    await _drag(tester, from - const Offset(8, 0), to);
    expect(await _quoted(tester), 'First pick');
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a selection keeps its lines', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final d = await _app(tester, {
      'a': [
        _agent(
          'o',
          'Para one.\n\nPara two.\n\n- item one\n- item two\n\n'
              '| Head | Other |\n|---|---|\n| left | right |\n\nLast words.',
        ),
      ],
    });
    await _drag(
      tester,
      _ends(tester, 'Para one').$1,
      _ends(tester, 'Last words').$2,
    );
    final quote = await _quoted(tester);
    expect(quote, startsWith('Para one.\n\nPara two.\n\n'));
    expect(quote, contains('• item one\n• item two'));
    expect(quote, contains('left\tright'));
    expect(quote, endsWith('\n\nLast words'));

    // ⌘C copies the same.
    await _drag(
      tester,
      _ends(tester, 'Para one').$1,
      _ends(tester, 'Para two').$2,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(copied, 'Para one.\n\nPara two');
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('no text in the transcript sits under a scroll of its own', (
    tester,
  ) async {
    final d = await _app(tester, {
      'a': [...longChat('a'), _agent('c', '```\ncode\n```')],
    });
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(SelectionArea),
      matching: find.byType(Scrollable),
    );
    for (final scroll in list.evaluate().skip(1)) {
      expect(
        SelectionContainer.maybeOf(scroll),
        isNull,
        reason: 'a nested scroll is a selection container of its own',
      );
    }
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a drag through a code block takes its text', (tester) async {
    final d = await _app(tester, {
      'a': [_agent('o', 'Words before.\n\n```\nthe code\n```\n\nWords after.')],
    });
    await _drag(tester, _ends(tester, 'before').$1, _ends(tester, 'after').$2);
    final quote = await _quoted(tester);
    expect(quote, contains('before'));
    expect(quote, contains('the code'));
    expect(quote, contains('after'));
    await closeView(tester, d);
  }, variant: mac);
}
