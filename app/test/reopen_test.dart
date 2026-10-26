import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents_page.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// A failed reopen's notices, each with what helps.
final _notices = [
  Item(
    id: 'n1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'not_ready',
    text: "Couldn't reopen the chat: Claude isn't set up: Settings › Agents",
  ),
  Item(
    id: 'n2',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'folder_gone',
    text: "Couldn't reopen the chat: its folder /Users/me/old-repo is gone",
  ),
  Item(
    id: 'n3',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'reopen_failed',
    text: "Couldn't reopen the chat: no such session",
  ),
];

ChatState _chat({bool failed = true}) => ChatState('c', '/Users/me/repo')
  ..agent = 'claude'
  ..title = 'Fix the login redirect'
  ..reopenFailed = failed
  ..asleep = !failed;

/// The calls asking to reopen a chat, by chat id.
List<String> _reopens(FakeDaemon fake) => [
  for (final c in fake.calls)
    if (c is ReopenChatRequest) c.chatId,
];

Future<Daemon> _show(
  WidgetTester tester,
  FakeDaemon fake,
  Widget Function(Daemon) child, {
  Tokens tokens = Tokens.dark,
}) async {
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(body: child(d)),
    ),
  );
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the header says it couldn’t start, not asleep; each '
        'notice has what helps ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(760, 300);
      addTearDown(tester.view.reset);
      final failed = _chat();
      final d = await _show(
        tester,
        FakeDaemon([]),
        (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final chat in [failed, _chat(failed: false)])
              ChatHeader(
                chat,
                d,
                changes: false,
                onChanges: (_) {},
                panel: false,
                onPanel: () {},
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 12,
                children: [
                  for (final n in _notices)
                    ItemView(n, failed, d, live: false, still: true),
                ],
              ),
            ),
          ],
        ),
        tokens: tokens,
      );
      expect(find.text("couldn't start"), findsOneWidget);
      expect(find.text('asleep'), findsOneWidget);
      for (final label in ['Set up…', 'Move…', 'Try again']) {
        expect(find.text(label), findsOneWidget);
      }
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/reopen_$name.png'),
      );
      d.dispose();
    });
  }

  testWidgets('Try again asks the daemon to reopen the chat', (tester) async {
    final fake = FakeDaemon([]);
    final chat = _chat();
    final d = await _show(
      tester,
      fake,
      (d) => ItemView(_notices[2], chat, d, live: false, still: true),
    );
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(_reopens(fake), ['c']);
    d.dispose();
  });

  testWidgets('Set up… opens Settings › Agents on the chat’s agent', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);
    final fake = FakeDaemon([]);
    final chat = _chat();
    final d = await _show(
      tester,
      fake,
      (d) => ItemView(_notices[0], chat, d, live: false, still: true),
    );
    await tester.tap(find.text('Set up…'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<AgentRow>(find.byType(AgentRow));
    expect(rows.where((r) => r.marked).map((r) => r.agent.name), ['claude']);
    d.dispose();
  });

  testWidgets('a chat picked, or the app coming to the front, asks to '
      'reopen it; an agent ready again reopens it if shown', (tester) async {
    final fake =
        FakeDaemon([
            chat(
              'c',
              'claude',
              'Shown',
              status: ChatStatus(reopenFailed: true),
            ),
            chat(
              'h',
              'claude',
              'Hidden',
              status: ChatStatus(reopenFailed: true),
            ),
          ])
          ..answer = (input) => input is GetChatRequest
              ? GetChatResponse(status: ChatStatus(reopenFailed: true))
              : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    d.select('c');
    await tester.pumpAndSettle();
    expect(_reopens(fake), ['c']);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_reopens(fake), ['c', 'c']);

    // The agent was set up: both chats may try again; only the shown one
    // asks now.
    var seq = 0;
    for (final id in ['h', 'c']) {
      fake.emit(
        EventsResponse(
          chatId: id,
          seq: Int64(++seq),
          status: ChatStatus(asleep: true),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(_reopens(fake), ['c', 'c', 'c']);
    // A reopen starting isn't an agent becoming ready.
    fake
      ..emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(++seq),
          status: ChatStatus(reopenFailed: true),
        ),
      )
      ..emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(++seq),
          status: ChatStatus(busy: true),
        ),
      );
    await tester.pump(); // busy breathes: it never settles
    await tester.pump();
    expect(_reopens(fake), ['c', 'c', 'c']);
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  // A chat kept though its agent deleted its session (its worktree has
  // work): quiet, not an error; Delete… instead of Try again.
  final gone = Item(
    id: 'g',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'session_gone',
    text:
        'Claude no longer has this session (Claude Code deletes sessions '
        'after 30 days by default). The chat stays because its worktree '
        '/Users/me/repo/.worktrees/quiet-yak has uncommitted changes: '
        'Delete… removes it and asks what to do with that.',
  );
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a chat whose session is gone says so quietly ($name)', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(760, 200);
      addTearDown(tester.view.reset);
      final chat = _chat()..sessionGone = true;
      final d = await _show(
        tester,
        FakeDaemon([]),
        (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatHeader(
              chat,
              d,
              changes: false,
              onChanges: (_) {},
              panel: false,
              onPanel: () {},
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ItemView(gone, chat, d, live: false, still: true),
            ),
          ],
        ),
        tokens: tokens,
      );
      expect(find.text('expired'), findsOneWidget);
      expect(find.text("couldn't start"), findsNothing);
      expect(find.text('Try again'), findsNothing);
      // Delete… is in the composer's place (history_test.dart).
      expect(find.text('Delete…'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/reopen_gone_$name.png'),
      );
      d.dispose();
    });
  }
}
