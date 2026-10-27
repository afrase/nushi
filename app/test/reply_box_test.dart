import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';

const _answer =
    'The timestamp is parsed once when the chat loads and kept as a '
    'DateTime, so sorting the sidebar compares instants rather than strings. '
    'Formatting happens only where a row shows it, in the reader’s time zone.';

const _quote = 'kept as a DateTime';

/// The app [size] on a chat whose agent explained something, the agent's
/// message at the top of the transcript or, [low], under a few others.
Future<(FakeDaemon, Future<void> Function())> _open(
  WidgetTester tester, {
  Size size = const Size(1700, 620),
  Brightness brightness = Brightness.dark,
  bool low = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Timestamps in the sidebar');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(
            id: 'u1',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Why does the sidebar sort chats by their time?',
          ),
          if (low)
            for (var i = 0; i < 6; i++)
              Item(
                id: 'f$i',
                kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                text: 'Looking at `sidebar.dart` and `chat.dart`, part $i.',
              ),
          Item(id: 'm1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _answer),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (
    fake,
    () async {
      await tester.pumpWidget(const SizedBox()); // its timers end
      d.dispose();
    },
  );
}

/// Selects [_quote] in the agent's message with the mouse and, [open],
/// opens the reply box on it; where the selection starts.
Future<Offset> _reply(WidgetTester tester, {bool open = true}) async {
  final text = find.textContaining('kept as a', findRichText: true).last;
  final para = tester.renderObject<RenderParagraph>(text);
  final whole = para.text.toPlainText();
  final from = whole.indexOf(_quote);
  // A character's box's left or right edge, at its middle.
  Offset at(int i, {bool right = false}) {
    final box = para
        .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
        .first
        .toRect();
    return para.localToGlobal(
      Offset(right ? box.right - 1 : box.left + 1, box.center.dy),
    );
  }

  final drag = await tester.startGesture(
    at(from),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await drag.moveTo(at(from + _quote.length - 1, right: true));
  await tester.pump();
  await drag.up();
  await tester.pumpAndSettle();
  if (!open) return at(from);
  await tester.tap(find.text('Reply'));
  await tester.pumpAndSettle();
  expect(find.byType(ReplyBox), findsOneWidget);
  return at(from);
}

Finder get _field => find.descendant(
  of: find.byType(ReplyBox),
  matching: find.byType(TextField),
);

/// Shift-Enter in the reply: Nushi starts the line itself (`isSendKey`),
/// and nothing is sent.
Future<void> _shiftEnter(WidgetTester tester) async {
  final was = tester.widget<TextField>(_field).controller!.text;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
  expect(find.byType(ReplyBox), findsOneWidget, reason: 'not sent');
  expect(tester.widget<TextField>(_field).controller!.text, '$was\n');
}

Future<void> _type(WidgetTester tester, List<String> lines) async {
  for (final (i, line) in lines.indexed) {
    if (i > 0) await _shiftEnter(tester);
    final was = tester.widget<TextField>(_field).controller!.text;
    await tester.enterText(_field, '$was$line');
    await tester.pump();
  }
}

const _lines = [
  'Why a DateTime and not the string as it comes?',
  'Strings in ISO order sort the same, and need no parsing.',
  'Or is it for the time zone?',
  'Couldn’t we just put the time into a string or something?',
];

void main() {
  setUpAll(loadFonts);

  testWidgets('Shift-Enter starts a line, the box grows upward from where '
      'it opened, and Enter sends the reply with its lines', (tester) async {
    final (fake, end) = await _open(tester, low: true);
    final selection = await _reply(tester);
    final box = find.byType(ReplyBox);
    final first = tester.getRect(box);
    expect(first.bottom, lessThan(selection.dy), reason: 'above the selection');

    await _type(tester, _lines.sublist(0, 1));
    var last = tester.getRect(box);
    expect(last.bottom, first.bottom);
    for (final line in _lines.skip(1)) {
      await _type(tester, ['', line]); // Shift-Enter, then the line
      final now = tester.getRect(box);
      expect(now.bottom, first.bottom, reason: 'its bottom stays');
      expect(now.top, lessThan(last.top), reason: 'it grows upward');
      last = now;
    }
    // The send button beside the last line, at the box's bottom right.
    final send = tester.getRect(find.byTooltip('Add to the message (⏎)'));
    expect(send.bottom, closeTo(last.bottom, 8));
    expect(send.right, closeTo(last.right, 8));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ReplyBox), findsNothing);
    // Its card shows the lines run on.
    expect(find.text(_lines.join(' ')), findsOneWidget);

    // The composer has it as a card; Enter there sends it, lines and all.
    await tester.tap(
      find.descendant(
        of: find.byType(Composer),
        matching: find.byType(TextField),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect(
      sent.text,
      withReplies([(quote: _quote, text: _lines.join('\n'))], ''),
    );
    expect(splitReplies(sent.text).$1.single.text, _lines.join('\n'));
    await end();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a click in the composer clears the selection and its toolbar', (
    tester,
  ) async {
    final (_, end) = await _open(tester);
    await _reply(tester, open: false);
    expect(find.byType(SelectionToolbar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Composer),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionToolbar), findsNothing);
    await end();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a short window keeps the box inside, its field scrolling', (
    tester,
  ) async {
    final (_, end) = await _open(tester, size: const Size(720, 300));
    await _reply(tester);
    await tester.enterText(
      _field,
      [for (var i = 1; i <= 12; i++) 'Line $i of a long reply'].join('\n'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final view = tester.getRect(find.byType(Transcript));
    final box = tester.getRect(find.byType(ReplyBox));
    expect(box.top, greaterThanOrEqualTo(view.top));
    expect(box.bottom, lessThanOrEqualTo(view.bottom));
    expect(box.right, lessThanOrEqualTo(view.right));
    await end();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden, the reply box with four lines, $name', (tester) async {
      final (_, end) = await _open(tester, brightness: brightness, low: true);
      await _reply(tester);
      await tester.enterText(_field, _lines.join('\n'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ReplyBox),
        matchesGoldenFile('goldens/reply_box_$name.png'),
      );
      await end();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  // The whole window, wide and narrow, with the box open on a long reply
  // that wraps: inside the transcript, nothing cut.
  for (final width in [1700.0, 720.0]) {
    testWidgets('the window ${width.round()} wide with a long reply', (
      tester,
    ) async {
      final (_, end) = await _open(tester, size: Size(width, 620), low: true);
      await _reply(tester);
      await tester.enterText(_field, _lines.join(' '));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final view = tester.getRect(find.byType(Transcript));
      final box = tester.getRect(find.byType(ReplyBox));
      expect(box.left, greaterThanOrEqualTo(view.left));
      expect(box.right, lessThanOrEqualTo(view.right));
      expect(box.top, greaterThanOrEqualTo(view.top));
      await end();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('a reply edited from its card grows too: Shift-Enter starts '
      'a line, Enter saves it', (tester) async {
    final replies = Replies([(quote: _quote, text: _lines.first)]);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: ReplyCards(replies, onDone: () {})),
      ),
    );
    await tester.tap(find.text(_lines.first));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final one = tester.getSize(field).height;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'not saved');
    await tester.enterText(field, _lines.join('\n'));
    await tester.pump();
    expect(tester.getSize(field).height, greaterThan(one * 3));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(replies.value.single.text, _lines.join('\n'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
