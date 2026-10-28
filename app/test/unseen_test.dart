import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// One chat in each state the dot shows.
List<Chat> _chats() => [
  chat('w', 'claude', 'Working', status: ChatStatus(busy: true)),
  chat('n', 'codex', 'Needs you', age: 1, status: ChatStatus(waiting: true)),
  chat('u', 'claude', 'Unseen', age: 2)..unseen = true,
  chat('i', 'ante', 'Idle', age: 3),
  chat('c', 'pig', 'Crashed', age: 4, status: ChatStatus(reopenFailed: true)),
  chat('s', 'omp', 'Asleep, unseen', age: 5, status: ChatStatus(asleep: true))
    ..unseen = true,
];

const Tokens _t = Tokens.dark;

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: const NushiTheme(_t).toThemeData(),
  home: MediaQuery(
    // Still, so the working chat's ring doesn't move.
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: SizedBox(width: 260, height: 400, child: child),
        ),
      ),
    ),
  ),
);

/// What the dot in [row] shows: its fill or ring color, "ring" while it
/// works, or the icon's.
Object? _dot(WidgetTester tester, Finder row) {
  final dot = find.descendant(of: row, matching: find.byType(ChatDot));
  final icon = find.descendant(of: dot, matching: find.byType(Icon));
  if (icon.evaluate().isNotEmpty) return tester.widget<Icon>(icon).color;
  final box = find.descendant(of: dot, matching: find.byType(DecoratedBox));
  if (box.evaluate().isEmpty) return 'ring';
  final d = tester.widget<DecoratedBox>(box.last).decoration as BoxDecoration;
  return d.color ?? (d.border! as Border).top.color;
}

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Row)).first;

void main() {
  setUpAll(loadFonts);

  testWidgets('the sidebar: a dot for each state, unseen green', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    final d = await FakeDaemon(_chats()).connect(tester);
    await tester.pumpWidget(_app(Sidebar(daemon: d)));
    await tester.pump();
    expect(_dot(tester, _row('Working')), 'ring');
    expect(_dot(tester, _row('Needs you')), _t.needs);
    expect(_dot(tester, _row('Unseen')), _t.done);
    expect(_dot(tester, _row('Idle')), _t.idle);
    expect(_dot(tester, _row('Crashed')), _t.crashed);
    // Asleep, an unseen end still shows.
    expect(_dot(tester, _row('Asleep, unseen')), _t.done);
    d.dispose();
  });

  testWidgets('the phone: the same dots, and "done" only while unseen', (
    tester,
  ) async {
    final d = await FakeDaemon(_chats()).connect(tester);
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            for (final id in ['w', 'n', 'u', 'i', 'c'])
              ChatRow(d.chats[id]!, onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pump();
    Finder row(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(ChatRow));
    expect(_dot(tester, row('Working')), 'ring');
    expect(_dot(tester, row('Needs you')), _t.needs);
    expect(_dot(tester, row('Unseen')), _t.done);
    expect(_dot(tester, row('Idle')), _t.idle);
    expect(_dot(tester, row('Crashed')), _t.crashed);
    expect(
      find.descendant(of: row('Unseen'), matching: find.text('done')),
      findsOne,
    );
    expect(
      find.descendant(of: row('Idle'), matching: find.text('idle')),
      findsOne,
    );
    d.dispose();
  });

  testWidgets('a turn ending unseen: the check, then the green dot', (
    tester,
  ) async {
    final fake = FakeDaemon([
      chat('a', 'claude', 'A', status: ChatStatus(busy: true)),
    ]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(_app(Sidebar(daemon: d)));
    await tester.pump();
    expect(_dot(tester, _row('A')), 'ring');
    // The daemon marks it before the status says the turn ended.
    fake
      ..emit(
        EventsResponse(
          chatId: 'a',
          chat: chat('a', 'claude', 'A')..unseen = true,
        ),
      )
      ..emit(EventsResponse(chatId: 'a', status: ChatStatus()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The check draws, the green dot under it not yet in.
    final under = find.descendant(
      of: find.descendant(of: _row('A'), matching: find.byType(ChatDot)),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(under).opacity, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(_dot(tester, _row('A')), _t.done);
    // Shown somewhere, it's seen.
    fake.emit(EventsResponse(chatId: 'a', chat: chat('a', 'claude', 'A')));
    await tester.pump();
    await tester.pump();
    expect(_dot(tester, _row('A')), _t.idle);
    d.dispose();
  });

  testWidgets('an older daemon: no mark, and no view told', (tester) async {
    final fake = FakeDaemon([chat('a', 'claude', 'A')..unseen = true])
      ..answer = (input) =>
          input is PingRequest ? PingResponse(apiVersion: 75) : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(_app(Sidebar(daemon: d)));
    await tester.pump();
    expect(d.chats['a']!.unseen, isNull);
    expect(_dot(tester, _row('A')), _t.idle);
    expect(fake.calls.whereType<SetDeviceViewRequest>(), isEmpty);
    d.dispose();
  });

  testWidgets('the Mac tells the daemon which chat its window shows', (
    tester,
  ) async {
    final fake = FakeDaemon([
      chat('a', 'claude', 'A'),
      chat('b', 'codex', 'B'),
    ]);
    final d = await fake.connect(tester);
    List<String> told() => [
      for (final c in fake.calls.whereType<SetDeviceViewRequest>()) c.chatId,
    ];
    d.select('a');
    await tester.pump();
    d.openSettings(section: SettingsSection.general);
    await tester.pump();
    d
      ..closeSettings()
      ..macView.window = false;
    await tester.pump();
    d.macView.window = true;
    await tester.pump();
    expect(told(), ['a', '', 'a', '', 'a']);
    d.dispose();
  });

  // The owner's four states side by side, in the dark theme.
  testWidgets('golden: working, needs you, unseen, idle', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    final d = await FakeDaemon(_chats().take(4).toList()).connect(tester);
    await tester.pumpWidget(_app(Sidebar(daemon: d)));
    await tester.pump();
    await expectLater(
      find.byKey(const Key('shot')),
      matchesGoldenFile('goldens/sidebar_unseen_dark.png'),
    );
    d.dispose();
  });
}
