import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status_bar.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  test("a chat's look tells of a change of state or title, not of text "
      'streaming in', () {
    final chat = ChatState('c', '/x')..load(GetChatResponse(seq: Int64(1)));
    var told = 0;
    chat.look.addListener(() => told++);
    var seq = 2;
    void event(EventsResponse e) => chat.apply(
      e
        ..seq = Int64(seq++)
        ..chatId = 'c',
    );
    event(EventsResponse(status: ChatStatus(busy: true)));
    expect(told, 1, reason: 'a turn started');
    event(
      EventsResponse(
        item: ItemEvent(
          item: Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE),
        ),
      ),
    );
    for (final chunk in ['Hel', 'lo', ', there']) {
      event(
        EventsResponse(
          item: ItemEvent(
            append: true,
            item: Item(id: 'm', text: chunk),
          ),
        ),
      );
    }
    expect(told, 1, reason: 'text streamed in');
    event(EventsResponse(status: ChatStatus()));
    expect(told, 2, reason: 'the turn ended');
  });

  testWidgets("streamed text rebuilds no sidebar row, the chat's own "
      'included; a change of state rebuilds its row only', (tester) async {
    viewport(tester, const Size(400, 600));
    final fake = FakeDaemon([
      chat('a', 'claude', 'Fix the login redirect'),
      chat('b', 'codex', 'Bump the API version', age: 1),
    ]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 260,
          child: ListenableBuilder(
            listenable: d,
            builder: (context, _) => Sidebar(daemon: d),
          ),
        ),
        still: true,
      ),
    );
    d.select('a'); // loaded, so its events apply
    await tester.pumpAndSettle();
    final built = <String>[];
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget case Text(:final data?)) built.add(data);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    var seq = 1;
    // Sent, then applied and drawn.
    Future<void> event(EventsResponse e) async {
      fake.emit(
        e
          ..seq = Int64(seq++)
          ..chatId = 'a',
      );
      await tester.pump();
      await tester.pump();
    }

    await event(
      EventsResponse(
        item: ItemEvent(
          item: Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE),
        ),
      ),
    );
    built.clear();
    for (final chunk in ['Hel', 'lo', ', there']) {
      await event(
        EventsResponse(
          item: ItemEvent(
            append: true,
            item: Item(id: 'm', text: chunk),
          ),
        ),
      );
    }
    expect(d.chats['a']!.items.single.text, 'Hello, there');
    expect(built, isNot(contains('Fix the login redirect')));
    expect(built, isNot(contains('Bump the API version')));
    await event(EventsResponse(status: ChatStatus(busy: true)));
    expect(built, contains('Fix the login redirect'));
    expect(built, isNot(contains('Bump the API version')));
    d.dispose();
  });

  testWidgets('streamed text rebuilds none of the status bar; a turn '
      'starting does', (tester) async {
    final fake = FakeDaemon([chat('a', 'claude', 'Fix the login redirect')]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(StatusBar(d)));
    d.select('a'); // loaded, so its events apply
    await tester.pumpAndSettle();
    var seq = 1;
    Future<void> event(EventsResponse e) async {
      fake.emit(
        e
          ..seq = Int64(seq++)
          ..chatId = 'a',
      );
      await tester.pump();
      await tester.pump();
    }

    await event(
      EventsResponse(
        item: ItemEvent(
          item: Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE),
        ),
      ),
    );
    final built = <String>[];
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget case Text(:final data?)) built.add(data);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (final chunk in ['Hel', 'lo', ', there']) {
      await event(
        EventsResponse(
          item: ItemEvent(
            append: true,
            item: Item(id: 'm', text: chunk),
          ),
        ),
      );
    }
    expect(d.chats['a']!.items.single.text, 'Hello, there');
    expect(built, isEmpty);
    await event(EventsResponse(status: ChatStatus(busy: true)));
    expect(built, isNotEmpty);
    d.dispose();
  });
}
