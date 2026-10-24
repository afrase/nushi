import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

EventsResponse chunk(int seq, String id, String text, {bool append = true}) =>
    EventsResponse(
      chatId: 'c',
      seq: Int64(seq),
      item: ItemEvent(
        item: Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text),
        append: append,
      ),
    );

void main() {
  test('a snapshot plus the events after it, each applied once', () {
    final chat = ChatState('c', '/x')..loading = true;
    // Events that arrive while the snapshot is on its way wait for it.
    chat.apply(chunk(3, 'm', 'lo'));
    chat.apply(chunk(4, 'm', '!'));
    chat.load(
      GetChatResponse(
        items: [
          Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Hello'),
        ],
        status: ChatStatus(busy: true),
        seq: Int64(3), // includes event 3 already
      ),
    );
    chat.apply(chunk(5, 'm', '?'));
    chat.apply(chunk(5, 'm', '?')); // a repeat changes nothing
    expect(chat.items.single.text, 'Hello!?');
    expect(chat.busy, isTrue);
  });

  test('before its snapshot is asked for, a chat tracks only busy', () {
    final chat = ChatState('c', '/x');
    chat.apply(EventsResponse(seq: Int64(1), status: ChatStatus(busy: true)));
    chat.apply(chunk(2, 'm', 'Hi', append: false));
    expect(chat.busy, isTrue);
    expect(chat.items, isEmpty);
  });

  test('a drop takes one item out, a cut it and what follows; a whole item replaces', () {
    final chat = ChatState('c', '/x')..loading = true;
    Item msg(String id, String text) =>
        Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);
    chat.load(
      GetChatResponse(
        items: [msg('a', 'one'), msg('b', 'two'), msg('c', 'three')],
        seq: Int64(1),
      ),
    );
    chat.apply(chunk(2, 'a', 'One', append: false));
    chat.apply(EventsResponse(seq: Int64(3), dropped: 'b'));
    expect([for (final it in chat.items) it.text], ['One', 'three']);
    chat.apply(EventsResponse(seq: Int64(4), cut: 'c'));
    expect([for (final it in chat.items) it.text], ['One']);
    chat.apply(EventsResponse(seq: Int64(5), cut: 'gone')); // nothing to cut
    expect(chat.items, hasLength(1));
  });
}
