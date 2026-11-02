import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

// ⌘F's jump: the current match in view, whatever its distance, on a chat
// as long as the owner's. Its marks are in find_marks_test.dart.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _agent(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

/// The app on chat c with [items]; [settle] lets it fill in first.
Future<Daemon> _app(
  WidgetTester tester,
  List<Item> items, {
  bool settle = true,
}) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final c = chat('c', 'claude', 'Long');
  final fake = FakeDaemon([c])
    ..answer = (input) =>
        input is GetChatRequest ? GetChatResponse(chat: c, items: items) : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return d;
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    query,
  );
  await tester.pumpAndSettle();
}

/// Where the [n]th [word] is on screen, of those laid out.
Rect _rect(WidgetTester tester, String word, {int n = 0}) {
  var left = n;
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final text = p.text.toPlainText(includeSemanticsLabels: false);
    for (final m in word.allMatches(text)) {
      if (left-- > 0) continue;
      final box = p
          .getBoxesForSelection(
            TextSelection(baseOffset: m.start, extentOffset: m.end),
          )
          .first
          .toRect();
      return box.shift(p.localToGlobal(Offset.zero));
    }
  }
  throw StateError('no $word laid out');
}

/// The transcript's box on screen.
Rect _list(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(SelectionArea),
        matching: find.byType(Scrollable),
      )
      .first,
);

void _inView(WidgetTester tester, String word, {int n = 0}) {
  final at = _rect(tester, word, n: n);
  final list = _list(tester);
  expect(at.top, greaterThanOrEqualTo(list.top), reason: '$at in $list');
  expect(at.bottom, lessThanOrEqualTo(list.bottom), reason: '$at in $list');
}

/// [lines] lines of prose, with needle on the given ones.
String _long(int lines, Set<int> needles) => [
  for (var i = 0; i < lines; i++) ...[
    if (i % 12 == 0) '',
    if (needles.contains(i)) 'A needle here' else 'Plain line $i',
  ],
].join('\n');

/// The transcript's scroll.
ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

var _seq = 1000;

/// [n] more of the agent's messages come in, as the daemon sends them.
Future<void> _stream(WidgetTester tester, Daemon d, int n) async {
  final chat = d.chats['c']!;
  for (var i = 0; i < n; i++) {
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(_seq++),
        item: ItemEvent(
          item: _agent('s$_seq', 'Streamed words.\n\n${'More. ' * 40}'),
          index: chat.items.length,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a long chat, filled in: typing goes to the match at its top', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('top', 'The needle is here, far above.'),
      ...longChat('a', turns: 40),
    ]);
    await _type(tester, 'needle');
    expect(find.text('1 of 1'), findsOne);
    _inView(tester, 'needle');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a long chat still filling in: typing goes to the match', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('top', 'The needle is here, far above.'),
      ...longChat('a', turns: 40),
    ], settle: false);
    await _type(tester, 'needle');
    _inView(tester, 'needle');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a long chat still filling in: a match halfway up', (
    tester,
  ) async {
    final d = await _app(tester, [
      ...longChat('a', turns: 20),
      _agent('mid', 'The needle is here, halfway.'),
      ...longChat('b', turns: 20),
    ], settle: false);
    await _type(tester, 'needle');
    _inView(tester, 'needle');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a match deep in a long message comes into view itself', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('m', _long(400, {350})),
      ...longChat('a', turns: 4),
    ]);
    await _type(tester, 'needle');
    _inView(tester, 'needle');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⏎ goes on to the next match in the same long message', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('m', _long(400, {20, 350})),
      ...longChat('a', turns: 4),
    ]);
    await _type(tester, 'needle');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    _inView(tester, 'needle', n: 1);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⇧⏎ from the first match goes round to the last, far below', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('top', 'A needle at the top.'),
      ...longChat('a', turns: 30),
      _agent('end', 'A needle at the end.'),
    ]);
    await _type(tester, 'needle');
    _inView(tester, 'needle');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOne);
    _inView(tester, 'needle at the end');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a match that shows stays where it is', (tester) async {
    final d = await _app(tester, [
      ...longChat('a', turns: 10),
      _agent('m', 'A needle just above the end.'),
      _agent('n', 'The last words of the chat.'),
    ]);
    final before = _scroll(tester).pixels;
    await _type(tester, 'needle');
    expect(_scroll(tester).pixels, before);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a match under the find bar is brought out from under it', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('l', 'Lines.\n\n${'Words to the far right and more. ' * 400}'),
      ...longChat('a', turns: 4),
    ]);
    await _type(tester, 'far right');
    final bar = tester.getRect(find.byType(FindBar));
    final at = _rect(tester, 'far right');
    expect(at.overlaps(bar), isFalse, reason: '$at under $bar');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a chat's first message, right under the find bar, comes out "
      'from under it', (tester) async {
    final d = await _app(tester, [
      Item(
        id: 'u',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'Find the needle.',
      ),
      ...longChat('a', turns: 8),
    ]);
    await _type(tester, 'needle');
    final bar = tester.getRect(find.byType(FindBar));
    final at = _rect(tester, 'needle');
    expect(at.overlaps(bar), isFalse, reason: '$at under $bar');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a match off a code block's right edge comes into view", (
    tester,
  ) async {
    final wide = 'wide ' * 300;
    final d = await _app(tester, [
      _agent('c', 'Code:\n\n```\n$wide needle\n```'),
      ...longChat('a', turns: 10),
    ]);
    await _type(tester, 'needle');
    final at = _rect(tester, 'needle');
    final list = _list(tester);
    expect(at.right, lessThanOrEqualTo(list.right));
    expect(at.left, greaterThanOrEqualTo(list.left));
    _inView(tester, 'needle');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a streaming chat stays where a jump put it, until the user '
      'goes back to the bottom', (tester) async {
    final d = await _app(tester, [
      _agent('top', 'The needle is here, far above.'),
      ...longChat('a', turns: 20),
    ]);
    await _type(tester, 'needle');
    final at = _scroll(tester).pixels;
    await _stream(tester, d, 3);
    expect(_scroll(tester).pixels, at);
    _inView(tester, 'needle');
    await tester.tap(find.byType(JumpChip));
    await tester.pumpAndSettle();
    final s = _scroll(tester);
    expect(s.pixels, s.maxScrollExtent);
    await _stream(tester, d, 1);
    expect(s.pixels, s.maxScrollExtent);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a jump to the very bottom doesn't follow it from there", (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('top', 'A needle at the top.'),
      ...longChat('a', turns: 20),
      _agent('end', 'A needle at the end.'),
    ]);
    await _type(tester, 'needle');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final s = _scroll(tester);
    expect(s.pixels, s.maxScrollExtent, reason: 'the last match is at the end');
    final at = s.pixels;
    await _stream(tester, d, 2);
    expect(s.pixels, at);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a jump the follower would pull back as the chat fills in', (
    tester,
  ) async {
    final d = await _app(tester, [
      ...longChat('a', turns: 20),
      _agent('mid', 'The needle is here, halfway.'),
      ...longChat('b', turns: 20),
    ], settle: false);
    await _type(tester, 'needle');
    final at = _scroll(tester).pixels;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_scroll(tester).pixels, at);
    await closeView(tester, d);
  }, variant: _mac);
}
