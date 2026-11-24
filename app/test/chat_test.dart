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
    final chat = ChatState('c', '/x')
      ..loading = true
      // Events that arrive while the snapshot is on its way wait for it.
      ..apply(chunk(3, 'm', 'lo'))
      ..apply(chunk(4, 'm', '!'))
      ..load(
        GetChatResponse(
          items: [
            Item(
              id: 'm',
              kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
              text: 'Hello',
            ),
          ],
          status: ChatStatus(busy: true),
          seq: Int64(3), // includes event 3 already
        ),
      )
      ..apply(chunk(5, 'm', '?'))
      ..apply(chunk(5, 'm', '?')); // a repeat changes nothing
    expect(chat.items.single.text, 'Hello!?');
    expect(chat.busy, isTrue);
  });

  test('streamed text tells streamed, not the chat, and leaves revision; '
      'a new item tells the chat', () {
    final chat = ChatState('c', '/x')
      ..loading = true
      ..load(GetChatResponse(seq: Int64(1)))
      ..apply(chunk(2, 'm', 'Hel', append: false));
    var told = 0;
    var streamed = 0;
    chat.addListener(() => told++);
    chat.streamed.addListener(() => streamed++);
    final revision = chat.revision;
    chat
      ..apply(chunk(3, 'm', 'lo'))
      ..apply(chunk(4, 'm', '!'));
    expect(chat.items.single.text, 'Hello!');
    expect((told, streamed, chat.revision), (0, 2, revision));
    chat.apply(chunk(5, 'n', 'Next', append: false));
    expect((told, streamed), (1, 2));
  });

  test("text streamed into a task running above a paged chat's recent part "
      'leaves revision as it was', () {
    final chat = ChatState('c', '/x')
      ..loading = true
      ..load(
        GetChatResponse(
          older: 5,
          running: [
            Item(
              id: 'bg',
              kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
              text: 'Work',
            ),
          ],
          seq: Int64(1),
        ),
      );
    final revision = chat.revision;
    chat.apply(chunk(2, 'bg', 'ing'));
    expect(chat.runningBefore.single.text, 'Working');
    expect(chat.revision, revision);
  });

  test('before its snapshot is asked for, a chat tracks only busy', () {
    final chat = ChatState('c', '/x')
      ..apply(EventsResponse(seq: Int64(1), status: ChatStatus(busy: true)))
      ..apply(chunk(2, 'm', 'Hi', append: false));
    expect(chat.busy, isTrue);
    expect(chat.items, isEmpty);
  });

  test('a drop takes one item out, a cut it and what follows; '
      'a whole item replaces', () {
    final chat = ChatState('c', '/x')..loading = true;
    Item msg(String id, String text) =>
        Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);
    chat
      ..load(
        GetChatResponse(
          items: [msg('a', 'one'), msg('b', 'two'), msg('c', 'three')],
          seq: Int64(1),
        ),
      )
      ..apply(chunk(2, 'a', 'One', append: false))
      ..apply(EventsResponse(seq: Int64(3), dropped: 'b'));
    expect([for (final it in chat.items) it.text], ['One', 'three']);
    chat.apply(EventsResponse(seq: Int64(4), cut: 'c'));
    expect([for (final it in chat.items) it.text], ['One']);
    chat.apply(EventsResponse(seq: Int64(5), cut: 'gone')); // nothing to cut
    expect(chat.items, hasLength(1));
  });
}
