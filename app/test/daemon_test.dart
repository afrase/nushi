import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

/// A daemon with chat "a" and its events in [events].
class _Fake implements Transport {
  final events = StreamController<EventsResponse>();

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    final Object out = switch (input) {
      PingRequest() => PingResponse(apiVersion: apiVersion),
      ListChatsRequest() => ListChatsResponse(
        chats: [Chat(id: 'a', folder: '/x', agent: 'claude')],
      ),
      GetChatRequest() => GetChatResponse(seq: Int64(1)),
      ForkChatRequest() => ForkChatResponse(chatId: 'side'),
      _ => spec.outputFactory(),
    };
    return UnaryResponse(spec, Headers(), out as O, Headers());
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async =>
      StreamResponse(spec, Headers(), events.stream as Stream<O>, Headers());
}

void main() {
  test('events go to their chat, side chat or terminals', () async {
    final fake = _Fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    Future<void> send(EventsResponse e) async {
      fake.events.add(e);
      await pumpEventQueue();
    }

    await send(EventsResponse()); // live: the chats are listed
    expect(d.chats.keys, ['a']);
    expect(d.chats['a']!.agentName, 'Claude');

    d.select('a');
    await pumpEventQueue();
    Item item(String text) =>
        Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);
    await send(
      EventsResponse(
        chatId: 'a',
        seq: Int64(2),
        item: ItemEvent(item: item('hi')),
      ),
    );
    expect(d.chats['a']!.items.single.text, 'hi');

    final side = d.chats['a']!.side = await d.forkChat(d.chats['a']!);
    await pumpEventQueue();
    await send(
      EventsResponse(
        chatId: 'side',
        seq: Int64(2),
        item: ItemEvent(item: item('aside')),
      ),
    );
    expect(side.items.single.text, 'aside');
    expect(d.chats['a']!.items.single.text, 'hi');

    await send(
      EventsResponse(
        chatId: 'a',
        terminals: ChatTerminals(
          terminals: [Terminal(id: 't', chatId: 'a')],
        ),
      ),
    );
    expect(d.terminals.of('a')!.single.id, 't');

    await send(
      EventsResponse(
        chatId: 'b',
        chat: Chat(id: 'b', folder: '/y', scratch: true),
      ),
    );
    expect(d.chats['b']!.scratch, isTrue);

    changeScopes.value = {'a': 'branch'};
    await send(EventsResponse(chatId: 'a', removed: true));
    expect(d.chats.keys, ['b']);
    expect(d.selectedId, isNull);
    expect(changeScopes.value, isEmpty);
  });
}
