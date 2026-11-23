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
Future<Daemon> _app(
  WidgetTester tester,
  Map<String, List<Item>> items, {
  List<String> files = const [],
}) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final chats = {for (final id in items.keys) id: chat(id, 'claude', id)};
  final fake = FakeDaemon(chats.values.toList())
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: chats[input.chatId],
        items: items[input.chatId],
      ),
      FindChatFilesRequest() => FindChatFilesResponse(found: files),
      _ => null,
    };
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

void main() {
  setUpAll(loadFonts);

  testWidgets('a selection made as a chat fills in is what was dragged over', (
    tester,
  ) async {
    final d = await _app(tester, {
      'a': longChat('a'),
      'b': [...longChat('b'), agentSays('z', 'The last words of the chat.')],
    });
    d.select('b');
    await tester.pump();
    await tester.pump();
    final (from, to) = _ends(tester, 'last words');
    await _drag(tester, from, to);
    expect(await _quoted(tester), 'last words');
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('selections one after another each quote only themselves, '
      'with a wide code block above them', (tester) async {
    final wide = 'wide ' * 80;
    final d = await _app(tester, {
      'a': [
        agentSays('o', 'Old words.\n\n```\nblock start $wide\n```\n\nOld end.'),
        agentSays('n', 'First pick and second pick.'),
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
  }, variant: onMac);

  testWidgets('a drag starting left of an old code block leaves it out, '
      'wherever the block is', (tester) async {
    const block = 'Fenced:\n\n```\nprose one\nprose two\n```';
    final d = await _app(tester, {
      'a': [
        agentSays('o', block),
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: block),
        agentSays('n', 'First pick.'),
      ],
    });
    final (from, to) = _ends(tester, 'First pick');
    await _drag(tester, from - const Offset(8, 0), to);
    expect(await _quoted(tester), 'First pick');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a selection keeps its lines', (tester) async {
    final copied = clipboardCopies(tester);
    final d = await _app(tester, {
      'a': [
        agentSays(
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
    await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
    expect(copied.lastOrNull, 'Para one.\n\nPara two');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('no text in the transcript sits under a scroll of its own', (
    tester,
  ) async {
    final d = await _app(tester, {
      'a': [...longChat('a'), agentSays('c', '```\ncode\n```')],
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
  }, variant: onMac);

  testWidgets('a drag through a code block takes its text', (tester) async {
    final d = await _app(tester, {
      'a': [
        agentSays('o', 'Words before.\n\n```\nthe code\n```\n\nWords after.'),
      ],
    });
    await _drag(tester, _ends(tester, 'before').$1, _ends(tester, 'after').$2);
    final quote = await _quoted(tester);
    expect(quote, contains('before'));
    expect(quote, contains('the code'));
    expect(quote, contains('after'));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file named in a line is quoted and copied in its place', (
    tester,
  ) async {
    final copied = clipboardCopies(tester);
    // Long enough to wrap: a link is cut after its slashes.
    final long = '${'folder/' * 40}deep.toml';
    // Each line, and the words a drag starts and ends on.
    final lines = [
      ('pin it in `mise.toml` like golangci-lint.', 'pin it', 'golangci'),
      ('`start.toml` pins the tools first.', 'start.toml', 'first.'),
      ('The tools are pinned in `last.toml`', 'The tools', 'last.toml'),
      ('Both `one.toml` and `two.toml` pin tools.', 'Both', 'pin tools.'),
      ('See `$long` for the deep one.', 'See', 'deep one.'),
    ];
    final d = await _app(
      tester,
      {
        'a': [
          for (final (i, (text, _, _)) in lines.indexed) agentSays('m$i', text),
        ],
      },
      files: [
        'mise.toml',
        'start.toml',
        'last.toml',
        'one.toml',
        'two.toml',
        long,
      ],
    );
    // Each name is a link here (a widget span), and the long one wraps.
    expect(find.text('mise.toml'), findsOneWidget);
    final pieces = find.text('folder/');
    expect(
      tester.getTopLeft(pieces.first).dy,
      lessThan(tester.getTopLeft(pieces.last).dy),
    );
    for (final (text, from, to) in lines) {
      final plain = text.replaceAll('`', '');
      await _drag(tester, _ends(tester, from).$1, _ends(tester, to).$2);
      expect(
        await _quoted(tester),
        plain.substring(0, plain.indexOf(to) + to.length),
        reason: text,
      );
    }

    // ⌘C copies the same.
    await _drag(
      tester,
      _ends(tester, 'pin it').$1,
      _ends(tester, 'golangci').$2,
    );
    await press(tester, LogicalKeyboardKey.keyC, cmd: true, settle: false);
    expect(copied.lastOrNull, 'pin it in mise.toml like golangci');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a reply to a line with a file link is sent in its order', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 900), brightness: Brightness.dark);
    const line = 'pin it in `mise.toml` like golangci-lint.';
    final d = await _app(
      tester,
      {
        'a': [agentSays('o', line)],
      },
      files: ['mise.toml'],
    );
    await _drag(
      tester,
      _ends(tester, 'pin').$1,
      _ends(tester, 'golangci-lint.').$2,
    );
    await tester.tap(find.text('Reply').last);
    await tester.pump();
    await render(tester, find.byType(NushiApp), 'reply-file-link');
    final quote = tester.widget<ReplyBox>(find.byType(ReplyBox)).quote;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await closeView(tester, d);

    // The message sent with it, as the owner saw it.
    final sent = await _app(
      tester,
      {
        'b': [
          agentSays('o', line),
          Item(
            id: 'u',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: withReplies([(quote: quote, text: '', from: '')], ''),
          ),
        ],
      },
      files: ['mise.toml'],
    );
    await render(tester, find.byType(NushiApp), 'sent-reply-file-link');
    await closeView(tester, sent);
    expect(quote, 'pin it in mise.toml like golangci-lint.');
  }, variant: onMac);
}
