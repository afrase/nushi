import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';

/// A daemon with chat "a"; the chat list and StartChat answer once [list]
/// and [start] complete, when given.
FakeDaemon _fake({
  Completer<ListChatsResponse>? list,
  Completer<StartChatResponse>? start,
}) =>
    FakeDaemon([Chat(id: 'a', folder: '/x', agent: 'claude')])
      ..answer = (input) => switch (input) {
        ListChatsRequest() when list != null => list.future,
        GetChatRequest() => GetChatResponse(seq: Int64(1)),
        StartChatRequest() when start != null => start.future,
        ForkChatRequest() => ForkChatResponse(chatId: 'side'),
        _ => null,
      };

void main() {
  test('events go to their chat, side chat or terminals', () async {
    final fake = _fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    Future<void> send(EventsResponse e) async {
      fake.emit(e);
      await pumpEventQueue();
    }

    await pumpEventQueue(); // live: the chats are listed
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

  test('places: Settings opens over the place and shuts leaving it; '
      'going elsewhere or picking a chat shuts it; Jira and GitHub go back '
      'to the chat', () {
    final d = Daemon(transport: _fake());
    addTearDown(d.dispose);
    d
      ..go(const JiraPlace())
      ..openSettings(section: SettingsSection.mcp, folder: '/x')
      ..openSettings(section: SettingsSection.skills);
    expect(d.settingsOpen, const SettingsAt(SettingsSection.skills));
    expect(d.place, const JiraPlace());
    expect(d.mcpFolder, '/x');
    d.closeSettings();
    expect(d.settingsOpen, isNull);
    expect(d.place, const JiraPlace());
    d.toggle(const JiraPlace());
    expect(d.place, const ChatPlace());
    d.toggle(const GitHubPlace());
    expect(d.place, const GitHubPlace());
    d.toggleSettings(); // the section shown last
    expect(d.settingsOpen, const SettingsAt(SettingsSection.skills));
    d.toggleSettings();
    expect(d.settingsOpen, isNull);
    d
      ..openSettings()
      ..go(const JiraPlace());
    expect(d.settingsOpen, isNull, reason: 'going elsewhere shuts it');
    d
      ..openSettings()
      ..select('a');
    expect(d.settingsOpen, isNull, reason: 'picking a chat shuts it');
    expect(d.place, const ChatPlace());
  });

  test('a side chat: one fork at a time; closing it tells the daemon and '
      'the chat', () async {
    final fake = _fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    final chat = ChatState('a', '/x')..agent = 'claude';
    // The second while the first forks: no second fork.
    await Future.wait([d.openSide(chat), d.openSide(chat)]);
    expect(fake.calls.whereType<ForkChatRequest>(), hasLength(1));
    final side = chat.side.value!;
    expect((side.id, side.agent), ('side', 'claude'));
    expect(d.sides.keys, ['side']);
    await d.openSide(chat); // it has one
    expect(fake.calls.whereType<ForkChatRequest>(), hasLength(1));

    var told = 0;
    chat.side.addListener(() => told++);
    d.closeSide(chat);
    expect((chat.side.value, told), (null, 1));
    expect(d.sides, isEmpty);
    await pumpEventQueue();
    expect(fake.calls.whereType<CloseSideChatRequest>().single.chatId, 'side');
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

    final fake = _fake();
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue(); // live: the chats are listed
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
    final list = Completer<ListChatsResponse>();
    final fake = _fake(list: list);
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue(); // live: the chats are listed
    // The turn ends after the list was read, and before it arrives; a chat
    // starts meanwhile too.
    fake
      ..emit(
        EventsResponse(
          chatId: 'a',
          seq: Int64(9),
          status: ChatStatus(busy: false),
        ),
      )
      ..emit(
        EventsResponse(
          chatId: 'b',
          chat: Chat(id: 'b', folder: '/y'),
        ),
      );
    await pumpEventQueue();
    list.complete(
      ListChatsResponse(
        chats: [Chat(id: 'a', folder: '/x', status: ChatStatus(busy: true))],
      ),
    );
    await pumpEventQueue();
    expect(d.chats.keys.toSet(), {'a', 'b'});
    expect(d.chats['a']!.busy, isFalse);
  });

  test('chats let go after a reconnect: still only the last six picked '
      'keep their items', () async {
    final ids = [for (var i = 0; i < 10; i++) String.fromCharCode(97 + i)];
    // Each subscription is a daemon's events; closing it, the link lost.
    late StreamController<EventsResponse> events;
    final fake = FakeDaemon([for (final id in ids) Chat(id: id, folder: '/x')])
      ..streams = ((input) => input is EventsRequest
          ? (events = StreamController()..add(EventsResponse())).stream
          : null)
      ..answer = (input) => switch (input) {
        GetChatRequest(:final chatId) => GetChatResponse(
          items: [Item(id: '$chatId-1', text: 'hi')],
          seq: Int64(1),
        ),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue(); // live: the chats are listed
    Future<void> pick(String id) async {
      d.select(id);
      await pumpEventQueue();
    }

    for (final id in ids.take(3)) {
      await pick(id);
    }
    await events.close();
    await pumpEventQueue();
    await d.ping(); // back: unloaded, and only "c" loads again
    await pumpEventQueue();
    expect(d.chats['a']!.loaded, isFalse);
    for (final id in ids.skip(3)) {
      await pick(id);
    }
    final holding = [
      for (final c in d.chats.values)
        if (c.items.isNotEmpty) c.id,
    ];
    expect(holding, ids.skip(4));
  });

  test('a slow start leaves the chat the user went to', () async {
    final start = Completer<StartChatResponse>();
    final d = Daemon(transport: _fake(start: start));
    addTearDown(d.dispose);
    await pumpEventQueue();
    final started = d.startChat('/z', 'claude');
    await pumpEventQueue();
    d.select('a');
    start.complete(StartChatResponse(chatId: 'new'));
    expect(await started, 'new'); // whether it shows or not
    expect(d.selectedId, 'a');
    expect(d.chats.containsKey('new'), isTrue);
  });
}
