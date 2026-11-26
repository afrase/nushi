import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/sidebar_row.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// A sleeping chat recedes: no mark in its dot's place (the slot keeps its
// size) and its title in the muted ink, unless an unseen end shows its
// green dot. The rows of every state side by side, in goldens and in the
// window at full size (`make renders TEST=test/sleeping_rows_test.dart`).

Chat _chat(
  String id,
  String agent,
  String title, {
  String folder = '/Users/me/parcel',
  int minutes = 0,
  ChatStatus? status,
}) => Chat(
  id: id,
  agent: agent,
  title: title,
  folder: folder,
  createdUnixMs: msAgo(Duration(minutes: minutes)),
  updatedUnixMs: msAgo(Duration(minutes: minutes)),
  status: status ?? ChatStatus(),
);

/// A chat in each state, three of them asleep: one with an unseen end,
/// one pinned, one the test opens ([_selected]).
List<Chat> _chats() => [
  _chat(
    'w',
    'claude',
    'Wire the parcel',
    status: ChatStatus(busy: true, started: msAgo(Duration.zero)),
  ),
  _chat(
    'n',
    'codex',
    'Pick the font colour',
    minutes: 1,
    status: ChatStatus(busy: true, waiting: true),
  ),
  _chat('i', 'claude', 'Tidy the README', minutes: 2),
  _chat(
    's',
    'pig',
    'Old spike on caching',
    minutes: 3,
    status: ChatStatus(asleep: true),
  ),
  _chat(
    'u',
    'ante',
    'Asleep, unseen',
    minutes: 4,
    status: ChatStatus(asleep: true),
  )..done = true,
  _chat(
    'z',
    'claude',
    'Read the crash logs',
    minutes: 5,
    status: ChatStatus(asleep: true),
  ),
  _chat('j', 'codex', 'Plan the sprint', minutes: 6),
  _chat(
    'q',
    'claude',
    'Notes from the call',
    folder: '/Users/me/notes',
    minutes: 7,
    status: ChatStatus(asleep: true),
  ),
  _chat(
    'p',
    'codex',
    'Keep this',
    folder: '/Users/me/attic',
    minutes: 8,
    status: ChatStatus(asleep: true),
  )..pin = 1,
];

/// The sleeping chat the tests open.
const _selected = 'z';

/// [fake] answering GetChat with each chat's own status, so the one
/// opened stays asleep.
FakeDaemon _keepAsleep(FakeDaemon fake) =>
    fake
      ..answer = (input) => input is GetChatRequest
          ? switch (fake.chats.where((c) => c.id == input.chatId)) {
              final found when found.isNotEmpty => GetChatResponse(
                chat: found.first,
                status: found.first.status,
              ),
              _ => null,
            }
          : null;

Finder _rowOf(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SidebarRow));

Finder _dotIn(Finder row) =>
    find.descendant(of: row, matching: find.byType(ChatDot));

Color? _titleColor(WidgetTester tester, String title) =>
    tester.widget<Text>(find.text(title).first).style?.color;

/// [dot] takes the dot's whole slot, as every state's mark does.
void _expectSlot(WidgetTester tester, Finder dot) {
  final size = tester.getSize(dot);
  expect(size.width, closeTo(ChatDot.size * 1.6, 0.01));
  expect(size.height, closeTo(ChatDot.size * 1.6, 0.01));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a sleeping row: no moon, no ring, its slot kept, its title '
      'muted; an unseen end keeps its green dot', (tester) async {
    final (d, fake) = await arrangedSidebar(tester, chats: _chats());
    _keepAsleep(fake);
    const t = Tokens.dark;
    final asleep = _dotIn(_rowOf('Old spike on caching'));
    expect(
      find.descendant(of: asleep, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: asleep, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    _expectSlot(tester, asleep);
    _expectSlot(tester, _dotIn(_rowOf('Tidy the README')));
    // Still said on hover.
    expect(
      find.descendant(
        of: _rowOf('Old spike on caching'),
        matching: find.byTooltip('asleep'),
      ),
      findsOne,
    );
    expect(_titleColor(tester, 'Old spike on caching'), recededColor(t));
    expect(_titleColor(tester, 'Tidy the README'), t.textSecondary);
    // Its agent's mark muted too, as an archived chat's.
    AgentMark mark(String title) => tester.widget<AgentMark>(
      find.descendant(of: _rowOf(title), matching: find.byType(AgentMark)),
    );
    expect(mark('Old spike on caching').color, recededColor(t));
    expect(mark('Tidy the README').color, isNull);
    // Pinned, it's the same.
    expect(_titleColor(tester, 'Keep this'), recededColor(t));
    expect(
      tester.widget<Text>(find.text('Keep this').first).style?.fontStyle,
      FontStyle.italic,
    );
    expect(
      tester.widget<Text>(find.text('Tidy the README').first).style?.fontStyle,
      isNot(FontStyle.italic),
    );
    // An unseen end shows through sleep, the title not dimmed.
    final unseen = find.descendant(
      of: _dotIn(_rowOf('Asleep, unseen')),
      matching: find.byType(DecoratedBox),
    );
    expect(
      (tester.widget<DecoratedBox>(unseen).decoration as BoxDecoration).color,
      t.done,
    );
    expect(_titleColor(tester, 'Asleep, unseen'), t.textSecondary);
    // Open, its title is the open chat's.
    d.select(_selected);
    await tester.pump();
    expect(_titleColor(tester, 'Read the crash logs'), t.text);
    d.dispose();
  });

  testWidgets('the phone: a sleeping row has no mark and a muted title', (
    tester,
  ) async {
    const t = Tokens.dark;
    final d = await FakeDaemon(_chats()).connect(tester);
    await tester.pumpWidget(
      themed(
        ListView(
          children: [
            for (final id in ['i', 's', 'u'])
              ChatRow(d.chats[id]!, onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pump();
    Finder row(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(ChatRow));
    final asleep = _dotIn(row('Old spike on caching'));
    expect(
      find.descendant(of: asleep, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: asleep, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    _expectSlot(tester, asleep);
    expect(_titleColor(tester, 'Old spike on caching'), recededColor(t));
    expect(_titleColor(tester, 'Tidy the README'), t.text);
    expect(_titleColor(tester, 'Asleep, unseen'), t.text);
    // Its state still in a word at the row's end.
    expect(
      find.descendant(
        of: row('Old spike on caching'),
        matching: find.text('asleep'),
      ),
      findsOne,
    );
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: a row in each state, three asleep ($name)', (
      tester,
    ) async {
      final (d, fake) = await arrangedSidebar(
        tester,
        chats: _chats(),
        tokens: tokens,
      );
      _keepAsleep(fake);
      d.select(_selected);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/sidebar_sleeping_$name.png'),
      );
      d.dispose();
    });
  }

  for (final width in [1700.0, 720.0]) {
    for (final brightness in renderThemes) {
      final name = '${width.toInt()}_${brightness.name}';
      testWidgets('the window with sleeping rows, $name', (tester) async {
        viewport(tester, Size(width, 760), brightness: brightness);
        final d = await _keepAsleep(FakeDaemon(_chats())).connect(tester);
        await tester.pumpWidget(NushiApp(daemon: d));
        d.select(_selected);
        await tester.pump(const Duration(seconds: 1));
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'sleeping_rows_$name');
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
