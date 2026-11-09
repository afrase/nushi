// A chat that holds only its recent part (the phone): events for items
// before it, a rewind there, older pages coming in.
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

Item _msg(int i) =>
    Item(id: 'i$i', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'm$i');

/// A chat loaded with items 100 to 109 of 110.
ChatState _recent() => ChatState('c', '/f')
  ..load(
    GetChatResponse(
      items: [for (var i = 100; i < 110; i++) _msg(i)],
      older: 100,
      seq: Int64(5),
    ),
  );

EventsResponse _item(int seq, Item it, {int index = 0, bool append = false}) =>
    EventsResponse(
      chatId: 'c',
      seq: Int64(seq),
      item: ItemEvent(item: it, index: index, append: append),
    );

void main() {
  test('an update to an item before the recent part is left out', () {
    final chat = _recent()
      ..apply(
        _item(6, Item(id: 'plan', kind: ItemKind.ITEM_KIND_PLAN), index: 40),
      )
      ..apply(_item(7, _msg(3)..text = ' more', index: 3, append: true));
    expect(chat.items.map((i) => i.id), [
      for (var i = 100; i < 110; i++) 'i$i',
    ]);
    // A new item comes at the end.
    chat.apply(_item(8, _msg(110), index: 110));
    expect(chat.items.last.id, 'i110');
  });

  test(
    'a rewind before the recent part, or at its start, asks again',
    () async {
      var asked = 0;
      EventsResponse cut(String id) =>
          EventsResponse(chatId: 'c', seq: Int64(6), cut: id);
      _recent()
        ..stale = (() => asked++)
        ..apply(cut('i50'));
      await Future<void>.delayed(Duration.zero);
      expect(asked, 1);
      final at = _recent()
        ..stale = (() => asked++)
        ..apply(cut('i100'));
      await Future<void>.delayed(Duration.zero);
      expect(asked, 2);
      expect(
        at.items,
        isEmpty,
        reason: 'nothing after the cut shows meanwhile',
      );
      // Inside the recent part: cut there, nothing asked.
      final inside = _recent()
        ..stale = (() => asked++)
        ..apply(cut('i105'));
      await Future<void>.delayed(Duration.zero);
      expect(asked, 2);
      expect(inside.items.last.id, 'i104');
    },
  );

  test('a rewind held while loading asks again after it, safely', () async {
    var asked = 0;
    ChatState('c', '/f')
      ..loading = true
      ..stale = (() => asked++)
      ..apply(EventsResponse(chatId: 'c', seq: Int64(9), cut: 'i10'))
      ..load(
        GetChatResponse(
          items: [for (var i = 100; i < 110; i++) _msg(i)],
          older: 100,
          seq: Int64(5),
        ),
      );
    await Future<void>.delayed(Duration.zero);
    expect(asked, 1);
  });

  test('a new item at the first loaded place goes first, not at the end', () {
    // A reopen's compaction mark sent at the page's edge (older == index),
    // or at 0 in a chat held whole.
    final chat = _recent()
      ..apply(
        _item(6, Item(id: 'mark', kind: ItemKind.ITEM_KIND_NOTICE), index: 100),
      );
    expect(chat.items.first.id, 'mark');
    final whole = ChatState('c', '/f')
      ..load(GetChatResponse(items: [_msg(0), _msg(1)], seq: Int64(5)))
      ..apply(_item(6, Item(id: 'mark', kind: ItemKind.ITEM_KIND_NOTICE)));
    expect(whole.items.map((i) => i.id), ['mark', 'i0', 'i1']);
  });

  test('an older page goes before; an item it has that came as new moves', () {
    final chat = _recent()
      ..apply(_item(6, _msg(95), index: 110)) // came at the end meanwhile
      ..prepend([for (var i = 90; i < 100; i++) _msg(i)], 90);
    expect(chat.items.map((i) => i.id), [for (var i = 90; i < 110; i++) 'i$i']);
    expect(chat.older, 90);
  });

  test('trimmed to its last items, a subagent among them stays whole', () {
    final chat = ChatState('c', '/f')
      ..load(
        GetChatResponse(
          items: [
            for (var i = 0; i < 10; i++) _msg(i),
            Item(id: 'sa', kind: ItemKind.ITEM_KIND_TOOL_CALL),
            for (var i = 0; i < 3; i++)
              Item(id: 's$i', parent: 'sa', kind: ItemKind.ITEM_KIND_TOOL_CALL),
            _msg(20),
          ],
          older: 5,
          seq: Int64(5),
        ),
      );
    expect(chat.trim(2), isTrue);
    expect(chat.items.map((i) => i.id), ['sa', 's0', 's1', 's2', 'i20']);
    expect(chat.older, 15);
    expect(chat.trim(20), isFalse, reason: 'nothing to let go');
    // A new item still lands at its place.
    chat.apply(_item(6, _msg(21), index: 20));
    expect(chat.items.last.id, 'i21');
  });

  test('trimmed, it keeps the call its pane shows, and nothing while a find '
      'looks', () {
    ChatState loaded() => ChatState('c', '/f')
      ..load(
        GetChatResponse(
          items: [for (var i = 0; i < 20; i++) _msg(i)],
          older: 5,
          seq: Int64(5),
        ),
      );
    final shown = loaded()..pane.value = 'i3';
    expect(shown.trim(2), isTrue);
    expect(shown.items.first.id, 'i3');
    expect(shown.older, 8);
    final finding = loaded()..find.query = 'm1';
    expect(finding.trim(2), isFalse);
    expect(finding.items.length, 20);
  });

  test('a task running before the recent part is kept, through a trim and '
      'its page coming back', () {
    final dev = Item(
      id: 'dev',
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      backgroundCommand: BackgroundCommand(id: 'b', state: 'running'),
    );
    final chat = ChatState('c', '/f')
      ..load(
        GetChatResponse(
          items: [dev, for (var i = 0; i < 20; i++) _msg(i)],
          older: 5,
          seq: Int64(5),
        ),
      );
    expect(chat.trim(2), isTrue);
    expect(chat.runningBefore.map((it) => it.id), ['dev']);
    expect(chat.withRunning.first.id, 'dev');
    chat.prepend([dev, for (var i = 0; i < 18; i++) _msg(i)], 5);
    expect(chat.runningBefore, isEmpty);
    expect(chat.items.where((it) => it.id == 'dev').length, 1);
  });

  test('trimmed, a permission or question still waiting stays, with what '
      'came after it; one answered goes', () {
    Item prompt(String id, ItemKind kind, String status) =>
        Item(id: id, kind: kind, status: status);
    ChatState loaded(Item asks) => ChatState('c', '/f')
      ..load(
        GetChatResponse(
          items: [
            for (var i = 0; i < 5; i++) _msg(i),
            asks,
            for (var i = 5; i < 20; i++) _msg(i),
          ],
          older: 5,
          seq: Int64(5),
        ),
      );
    for (final kind in [
      ItemKind.ITEM_KIND_PERMISSION,
      ItemKind.ITEM_KIND_QUESTION,
    ]) {
      final waiting = loaded(prompt('p', kind, 'pending'));
      expect(waiting.trim(2), isTrue);
      expect(waiting.items.first.id, 'p');
      expect(waiting.items.length, 16);
      expect(waiting.older, 10);
      final answered = loaded(prompt('p', kind, 'allowed'));
      expect(answered.trim(2), isTrue);
      expect(answered.items.map((i) => i.id), ['i18', 'i19']);
    }
  });

  test("trimmed back to a waiting prompt or the pane's call, a subagent "
      'step kept there keeps its call', () {
    // y runs a subagent; s, its step, comes after the prompt p (or the
    // call x the pane shows), all above the last 3.
    ChatState loaded(Item mid) => ChatState('c', '/f')
      ..load(
        GetChatResponse(
          items: [
            _msg(0),
            Item(
              id: 'y',
              kind: ItemKind.ITEM_KIND_TOOL_CALL,
              subagent: Subagent(state: 'running'),
            ),
            mid,
            Item(id: 's', kind: ItemKind.ITEM_KIND_TOOL_CALL, parent: 'y'),
            for (var i = 1; i < 6; i++) _msg(i),
          ],
          seq: Int64(5),
        ),
      );
    final waiting = loaded(
      Item(id: 'p', kind: ItemKind.ITEM_KIND_PERMISSION, status: 'pending'),
    );
    expect(waiting.trim(3), isTrue);
    expect(waiting.items.first.id, 'y');
    expect(waiting.runningBefore, isEmpty);
    final shown = loaded(Item(id: 'x', kind: ItemKind.ITEM_KIND_TOOL_CALL))
      ..pane.value = 'x';
    expect(shown.trim(3), isTrue);
    expect(shown.items.first.id, 'y');
  });
}
