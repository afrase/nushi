import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

/// A daemon with chat "a" and its events in [events].
class _Fake implements Transport {
  // The test's stream, which lives as long as the test.
  // ignore: close_sinks
  final events = StreamController<EventsResponse>();

  /// When set, the chat list answers once it completes; StartChat too.
  Completer<ListChatsResponse>? list;
  Completer<StartChatResponse>? start;

  /// Every call's request, in order.
  final asked = <Object>[];

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    asked.add(input);
    final out = switch (input) {
      PingRequest() => PingResponse(apiVersion: apiVersion),
      ListChatsRequest() =>
        await list?.future ??
            ListChatsResponse(
              chats: [Chat(id: 'a', folder: '/x', agent: 'claude')],
            ),
      GetChatRequest() => GetChatResponse(seq: Int64(1)),
      StartChatRequest() => await start!.future,
      CheckFolderRequest() => CheckFolderResponse(),
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

    await d.openSide(d.chats['a']!);
    final side = d.chats['a']!.side.value!;
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
    pullSeen.value = {'a': 1};
    cleanUpLater.value = {'a'};
    await send(EventsResponse(chatId: 'a', removed: true));
    expect(d.chats.keys, ['b']);
    expect(d.selectedId, isNull);
    expect(changeScopes.value, isEmpty);
    expect(chatsKept(), isEmpty);
  });

  test('places: Settings goes back to the view it came from, Jira and '
      'GitHub to the chat', () {
    final d = Daemon(transport: _Fake());
    addTearDown(d.dispose);
    d
      ..go(const JiraPlace())
      ..openSettings(section: SettingsSection.mcp, folder: '/x')
      ..openSettings(section: SettingsSection.skills); // still from Jira
    expect(d.place, const SettingsPlace(SettingsSection.skills));
    expect(d.mcpFolder, '/x');
    d.back();
    expect(d.place, const JiraPlace());
    d.toggle(const JiraPlace());
    expect(d.place, const ChatPlace());
    d.toggle(const GitHubPlace());
    expect(d.place, const GitHubPlace());
    d.openSettings(); // the section shown last
    expect(d.place, const SettingsPlace(SettingsSection.skills));
    d.back();
    expect(d.place, const GitHubPlace());
    d.back();
    expect(d.place, const ChatPlace());
  });

  test('a side chat: one fork at a time; closing it tells the daemon and '
      'the chat', () async {
    final fake = _Fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    final chat = ChatState('a', '/x')..agent = 'claude';
    // The second while the first forks: no second fork.
    await Future.wait([d.openSide(chat), d.openSide(chat)]);
    expect(fake.asked.whereType<ForkChatRequest>(), hasLength(1));
    final side = chat.side.value!;
    expect((side.id, side.agent), ('side', 'claude'));
    expect(d.sides.keys, ['side']);
    await d.openSide(chat); // it has one
    expect(fake.asked.whereType<ForkChatRequest>(), hasLength(1));

    var told = 0;
    chat.side.addListener(() => told++);
    d.closeSide(chat);
    expect((chat.side.value, told), (null, 1));
    expect(d.sides, isEmpty);
    await pumpEventQueue();
    expect(fake.asked.whereType<CloseSideChatRequest>().single.chatId, 'side');
  });

  test('a chat deleted while the app was away: what was kept goes', () async {
    // Kept from an earlier run for "a", listed, and "gone", deleted since.
    ReviewComment comment(String chat) => ReviewComment(
      id: chat,
      where: 'branch',
      path: 'main.go',
      old: false,
      start: 1,
      end: 1,
      quote: 'x',
      text: 'why?',
    );
    // Every pref kept by chat has something for both.
    changeScopes.value = {'a': 'branch', 'gone': 'branch'};
    terminalChats.value = {'a', 'gone'};
    sidebarChats.value = {
      '/x': ['gone', 'a'],
    };
    chatOpened.value = {'a': 1, 'gone': 2};
    pinnedFiles.value = {
      'a': ['notes.md'],
      'gone': ['notes.md'],
    };
    pullSeen.value = {'a': 1, 'gone': 2};
    cleanUpLater.value = {'a', 'gone'};
    setComments('a', [comment('a')]);
    setComments('gone', [comment('gone')]);
    final context = GetContextUsageResponse(
      categories: [ContextCategory(name: 'Messages', tokens: Int64(5))],
    );
    rememberContext('a', context);
    rememberContext('gone', context);
    addTearDown(() => forgetContext('a'));

    final fake = _Fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    fake.events.add(EventsResponse()); // live: the chats are listed
    await pumpEventQueue();
    expect(d.chats.keys, ['a']);
    expect(changeScopes.value.keys, ['a']);
    expect(terminalChats.value, {'a'});
    expect(sidebarChats.value, {
      '/x': ['a'],
    });
    expect(chatsKept(), {'a'});
    expect(reviews.value.keys, ['a']);
    expect(rememberedContexts, contains('a'));
    expect(rememberedContexts, isNot(contains('gone')));
  });

  test('events while the list is on its way come after it', () async {
    final fake = _Fake()..list = Completer();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    fake.events.add(EventsResponse()); // live: the chats are listed
    await pumpEventQueue();
    // The turn ends after the list was read, and before it arrives; a chat
    // starts meanwhile too.
    fake.events
      ..add(
        EventsResponse(
          chatId: 'a',
          seq: Int64(9),
          status: ChatStatus(busy: false),
        ),
      )
      ..add(
        EventsResponse(
          chatId: 'b',
          chat: Chat(id: 'b', folder: '/y'),
        ),
      );
    await pumpEventQueue();
    fake.list!.complete(
      ListChatsResponse(
        chats: [Chat(id: 'a', folder: '/x', status: ChatStatus(busy: true))],
      ),
    );
    await pumpEventQueue();
    expect(d.chats.keys.toSet(), {'a', 'b'});
    expect(d.chats['a']!.busy, isFalse);
  });

  test('a slow start leaves the chat the user went to', () async {
    final fake = _Fake()..start = Completer();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    fake.events.add(EventsResponse());
    await pumpEventQueue();
    final started = d.startChat('/z', 'claude');
    await pumpEventQueue();
    d.select('a');
    fake.start!.complete(StartChatResponse(chatId: 'new'));
    await started;
    expect(d.selectedId, 'a');
    expect(d.chats.containsKey('new'), isTrue);
  });
}
