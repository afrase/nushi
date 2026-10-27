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

  test('an older page goes before; an item it has that came as new moves', () {
    final chat = _recent()
      ..apply(_item(6, _msg(95), index: 110)) // came at the end meanwhile
      ..prepend([for (var i = 90; i < 100; i++) _msg(i)], 90);
    expect(chat.items.map((i) => i.id), [for (var i = 90; i < 110; i++) 'i$i']);
    expect(chat.older, 90);
  });
}
