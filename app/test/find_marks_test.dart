import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

// ⌘F's marks: the exact characters of each match, what's folded away, and
// the text left as it was. The jump to a match is in find_jump_test.dart.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const ItemKind _user = ItemKind.ITEM_KIND_USER_MESSAGE;
const ItemKind _agentKind = ItemKind.ITEM_KIND_AGENT_MESSAGE;

Item _agent(String id, String text) =>
    Item(id: id, kind: _agentKind, text: text);

Item _tool(String id, String kind, String title, {String text = ''}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  text: text,
  status: 'completed',
);

Future<Daemon> _app(
  WidgetTester tester,
  List<Item> items, {
  Size size = const Size(1400, 900),
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  paneWidths.value = {};
  showDetails.value = false;
  final c = chat('c', 'claude', 'Flaky relay');
  final fake = FakeDaemon([c])
    ..answer = (input) =>
        input is GetChatRequest ? GetChatResponse(chat: c, items: items) : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> _find(WidgetTester tester, String query) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    query,
  );
  await tester.pumpAndSettle();
}

List<TextMark> _marks(WidgetTester tester) =>
    tester.widget<TextMarksScope>(find.byType(TextMarksScope)).marks.marks;

/// A drag from [from] to [to], as a mouse makes it.
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
}

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

/// A chat with a match of "relay" in each kind of thing a transcript shows.
List<Item> _everything() => [
  Item(id: 'u', kind: _user, text: 'Why does the relay drop?'),
  _tool('r1', 'read', 'Read relay/notes.md', text: 'the Relay, read'),
  _tool('r2', 'read', 'Read web/go.mod'),
  _agent('a1', 'Reading.'),
  _tool('x', 'execute', 'go test ./...', text: 'relay_test.go fails\nrelay'),
  _agent('a2', 'Next.'),
  Item(
    id: 'sa',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    agentId: 'ag',
    title: 'Trace the socket',
    status: 'completed',
    subagent: Subagent(state: 'done'),
  ),
  Item(
    id: 'sa-1',
    parent: 'sa',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'read',
    title: 'Read relay/conn.go',
    status: 'completed',
  ),
  Item(
    id: 't',
    kind: ItemKind.ITEM_KIND_THOUGHT,
    text: 'It may be the relay timing out.',
  ),
  _agent(
    'a3',
    '## The relay\n\nThe **re**lay and `relay.go` both, and [a link](https://example.com/relay).\n\n'
        '| Relay | Why |\n| --- | --- |\n| relay.go | keeps a relay |\n\n'
        '```go\nfunc relay() {\n\treturn // the Relay\n}\n```\n',
  ),
];

void main() {
  setUpAll(loadFonts);

  testWidgets('every match is of the exact text shown, case aside', (
    tester,
  ) async {
    final d = await _app(tester, [
      _agent('a', 'The **re**lay and RELAY and [link](https://relay.example).'),
    ]);
    await _find(tester, 'relay');
    expect(find.text('1 of 2'), findsOne, reason: "not the link's address");
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      '**',
    );
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOne, reason: "not the Markdown's syntax");
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a match in each kind of text, and what's folded away", (
    tester,
  ) async {
    final d = await _app(tester, _everything());
    await _find(tester, 'relay');
    final marks = _marks(tester);
    expect(find.text('1 of ${marks.length}'), findsOne);
    final by = <String, int>{};
    for (final m in marks) {
      final entry = m.key.split(' ').first;
      by[entry] = (by[entry] ?? 0) + 1;
    }
    expect(by['u'], 1);
    // The run's closed: its title and its first call's output in its row.
    expect(by['r1'], 2);
    expect(by['x'], 2, reason: 'two in its output');
    expect(by['agent'], 1, reason: 'a step of the subagent');
    expect(by['t'], 1);
    // The heading, two in the paragraph (not the link's address), the
    // table's head and two in its row, two in the code block.
    expect(by['a3'], 8);
    expect(find.text('2 matches'), findsNWidgets(2));
    expect(find.text('1 match'), findsNWidgets(2));
    expect(marks.where((m) => m.folded), hasLength(6));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a row opened shows its match, marked in place', (tester) async {
    final d = await _app(tester, [
      _tool('x', 'execute', 'go test ./...', text: 'relay_test.go fails'),
      _agent('a', 'Done.'),
    ]);
    await _find(tester, 'relay');
    expect(find.text('1 match'), findsOne);
    expect(_marks(tester).single.folded, isTrue);
    await tester.tap(find.textContaining('go test', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsNothing);
    expect(find.text('1 of 1'), findsOne);
    expect(_marks(tester).single.folded, isFalse);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a word cut off a row's title marks the row", (tester) async {
    final long = '${'word ' * 400}needle';
    final d = await _app(tester, [
      _tool('x', 'execute', long),
      _agent('a', 'Done.'),
    ]);
    await _find(tester, 'needle');
    expect(find.text('1 of 1'), findsOne);
    expect(_marks(tester).single.folded, isTrue);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('marks leave the text as it was: a drag and ⌘C take the same', (
    tester,
  ) async {
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
    final d = await _app(tester, [
      _agent('a', 'One relay here.\n\nAnd **relay** there.\n\nLast words.'),
    ]);
    await _find(tester, 'relay');
    await _drag(
      tester,
      _ends(tester, 'One relay').$1,
      _ends(tester, 'Last words').$2,
    );
    await tester.pump();
    expect(_marks(tester), hasLength(2), reason: 'still marked');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(copied, 'One relay here.\n\nAnd relay there.\n\nLast words');
    await tester.tap(find.text('Reply').last);
    await tester.pump();
    expect(
      tester.widget<ReplyBox>(find.byType(ReplyBox)).quote,
      'One relay here.\n\nAnd relay there.\n\nLast words',
    );
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a find coming and going leaves an entry's state alone", (
    tester,
  ) async {
    final d = await _app(tester, [
      _tool('x', 'execute', 'go test ./...', text: 'a relay'),
      _agent('a', 'Done with the relay.'),
    ]);
    await tester.tap(find.textContaining('go test', findRichText: true).first);
    await tester.pumpAndSettle();
    final para = tester.renderObject<RenderParagraph>(
      find.textContaining('Done with', findRichText: true).last,
    );
    await _find(tester, 'relay');
    expect(para.attached, isTrue, reason: 'not built again');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(para.attached, isTrue);
    expect(_marks(tester), isEmpty);
    expect(
      find.textContaining('a relay', findRichText: true),
      findsOne,
      reason: 'the row is still open',
    );
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("closing the bar takes every mark, the rows' too", (
    tester,
  ) async {
    final d = await _app(tester, _everything());
    await _find(tester, 'relay');
    expect(_marks(tester), isNotEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_marks(tester), isEmpty);
    expect(find.textContaining(RegExp(r'^\d+ match')), findsNothing);
    expect(d.chats['c']!.find.hits, isEmpty);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a chunk looks again only at the entry it changed', (
    tester,
  ) async {
    final d = await _app(tester, longChat('a', turns: 12));
    await _find(tester, 'session');
    final before = _marks(tester);
    final chat = d.chats['c']!;
    final last = chat.items.last;
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1000),
        item: ItemEvent(
          item: Item(id: last.id, text: '\n\nA session more.'),
          append: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final after = _marks(tester);
    expect(after, hasLength(before.length + 1));
    expect(identical(after.first, before.first), isTrue);
    expect(
      find.text('1 of ${after.length}'),
      findsOne,
      reason: 'the current one stays',
    );
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a message's actions on hover aren't looked in", (tester) async {
    final d = await _app(tester, [
      Item(
        id: 'a',
        kind: _agentKind,
        text: 'Words.',
        sent: Int64(
          fixtureNow.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        ),
      ),
    ]);
    await _find(tester, 'ago');
    expect(find.text('None'), findsOne);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Words.')));
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOne);
    await mouse.removePointer();
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, size) in [
    ('wide', const Size(1700, 900)),
    ('narrow', const Size(720, 900)),
  ]) {
    for (final (mode, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      testWidgets('the marks in each kind of text, $name $theme', (
        tester,
      ) async {
        final d = await _app(
          tester,
          _everything(),
          size: size,
          brightness: mode,
        );
        await _find(tester, 'relay');
        // The current one a thought's row, among rows and text with marks.
        for (var i = 0; i < 6; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tester.pumpAndSettle();
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'find_marks_${name}_$theme',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
