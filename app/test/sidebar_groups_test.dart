import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_groups.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Four projects, newest chat first: ledger-poc (one chat waiting on you,
/// one idle), cappy (working), garden (a turn's end unseen), notes (idle).
List<Chat> _chats() => [
  chat(
    'a',
    'claude',
    'Wire the ledger',
    folder: '/Users/me/ledger-poc',
    status: ChatStatus(busy: true, waiting: true),
  ),
  chat(
    'c',
    'codex',
    'Cap the rates',
    folder: '/Users/me/cappy',
    age: 1,
    status: ChatStatus(busy: true),
  ),
  chat('d', 'claude', 'Plant the beds', folder: '/Users/me/garden', age: 2)
    ..done = true,
  chat('e', 'ante', 'Jot it down', folder: '/Users/me/notes', age: 3),
  chat('b', 'pig', 'Seed data', folder: '/Users/me/ledger-poc', age: 5),
];

Future<Daemon> _sidebar(
  WidgetTester tester, {
  List<Chat>? chats,
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, const Size(400, 600));
  final d = await FakeDaemon(chats ?? _chats()).connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        // Still, so the working chat's ring doesn't move.
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const Key('shot'),
              child: SizedBox(
                width: 260,
                height: 560,
                child: ListenableBuilder(
                  listenable: d,
                  builder: (context, _) => Sidebar(daemon: d),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return d;
}

const _projects = ['ledger-poc', 'cappy', 'garden', 'notes'];

/// The projects' headers, top to bottom.
List<String> _order(WidgetTester tester) => [
  for (final p in [..._projects, 'zeta'])
    if (find.text(p).evaluate().isNotEmpty) p,
]..sort((a, b) => _y(tester, a).compareTo(_y(tester, b)));

double _y(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text)).dy;

/// The header of [project].
Finder _header(String project) => find.ancestor(
  of: find.text(project),
  matching: find.byWidgetPredicate((w) => w is Draggable),
);

/// The summary dot's phase in [project]'s header, if it shows one.
ChatPhase? _dot(WidgetTester tester, String project) {
  final dot = find.descendant(
    of: _header(project),
    matching: find.byType(PhaseDot),
  );
  return dot.evaluate().isEmpty ? null : tester.widget<PhaseDot>(dot).phase;
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('a project is dragged by its header into another place, '
      'the others moving apart where it goes; remembered, a new project '
      'first', (tester) async {
    var d = await _sidebar(tester);
    expect(_order(tester), _projects);
    // With the mouse, as on the Mac (a touch drag scrolls the list); up,
    // into the top half of ledger-poc's group.
    final top = _y(tester, 'ledger-poc');
    var at = tester.getCenter(find.text('notes'));
    final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
    while (at.dy > top - 4) {
      at -= const Offset(0, 12);
      await drag.moveTo(at);
      await tester.pump();
    }
    // Reduce Motion: there at once, notes's place open above it.
    expect(_y(tester, 'ledger-poc'), greaterThan(top));
    await drag.up();
    await tester.pump();
    final order = ['notes', 'ledger-poc', 'cappy', 'garden'];
    expect(_order(tester), order);
    final paths = [for (final p in order) '/Users/me/$p'];
    expect(sidebarOrder.value, paths);
    expect(readSaved()['sidebarOrder'], paths);
    // ⌘1–⌘9 go through them as they show.
    expect(chatOrder(d).map((c) => c.id), ['e', 'a', 'b', 'c', 'd']);
    d.dispose();

    // Again, as after a restart, with a new project's chat: it goes first.
    d = await _sidebar(
      tester,
      chats: [
        ..._chats(),
        chat('z', 'claude', 'Start zeta', folder: '/Users/me/zeta', age: 9),
      ],
    );
    expect(_order(tester), ['zeta', ...order]);
    d.dispose();
  });

  testWidgets('the chevron collapses a project: its rows hidden, the most '
      'urgent state as one dot, remembered', (tester) async {
    final d = await _sidebar(tester);
    expect(_dot(tester, 'ledger-poc'), isNull); // open: no summary
    await tester.tap(
      find.descendant(
        of: _header('ledger-poc'),
        matching: find.byTooltip('Collapse'),
      ),
    );
    await tester.pump();
    expect(find.text('Wire the ledger'), findsNothing);
    expect(find.text('Seed data'), findsNothing);
    expect(_dot(tester, 'ledger-poc'), ChatPhase.waiting); // over idle
    expect(readSaved()['sidebarCollapsed'], ['/Users/me/ledger-poc']);

    // The chevron is a button the keyboard presses.
    Focus.of(
      tester.element(
        find.descendant(
          of: _header('cappy'),
          matching: find.byIcon(Icons.expand_more),
        ),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Cap the rates'), findsNothing);
    expect(_dot(tester, 'cappy'), ChatPhase.working);

    sidebarCollapsed.value = {
      ...sidebarCollapsed.value,
      '/Users/me/garden',
      '/Users/me/notes',
    };
    await tester.pump();
    expect(_dot(tester, 'garden'), ChatPhase.unseen);
    expect(_dot(tester, 'notes'), isNull); // all idle: nothing
    // A turn's end in notes goes unseen: its dot shows.
    d.chats['e']!.unseen = true;
    await tester.pump();
    expect(_dot(tester, 'notes'), ChatPhase.unseen);
    expect(chatOrder(d), isEmpty); // nothing shows for the keys

    await tester.tap(
      find.descendant(
        of: _header('ledger-poc'),
        matching: find.byTooltip('Expand'),
      ),
    );
    await tester.pump();
    expect(find.text('Wire the ledger'), findsOneWidget);
    expect(_dot(tester, 'ledger-poc'), isNull);
    expect(sidebarCollapsed.value, {
      '/Users/me/cappy',
      '/Users/me/garden',
      '/Users/me/notes',
    });
    d.dispose();
  });

  testWidgets('the selected chat of a collapsed project still shows its row, '
      'until another is selected', (tester) async {
    sidebarCollapsed.value = {'/Users/me/cappy'};
    final d = await _sidebar(tester);
    expect(find.text('Cap the rates'), findsNothing);
    expect(chatOrder(d).map((c) => c.id), ['a', 'b', 'd', 'e']);
    d.select('c'); // as ⌘1–9, a notification or New chat do
    await tester.pump();
    expect(find.text('Cap the rates'), findsOneWidget);
    expect(_y(tester, 'Cap the rates'), greaterThan(_y(tester, 'cappy')));
    expect(_y(tester, 'Cap the rates'), lessThan(_y(tester, 'garden')));
    expect(chatOrder(d).map((c) => c.id), ['a', 'b', 'c', 'd', 'e']);
    expect(sidebarCollapsed.value, {'/Users/me/cappy'}); // still collapsed
    d.select('a');
    await tester.pump();
    expect(find.text('Cap the rates'), findsNothing);
    d.dispose();
  });

  testWidgets('a header is one line, its path in the tooltip; the + shows '
      'under the pointer or with keyboard focus', (tester) async {
    final d = await _sidebar(tester);
    final header = tester.getRect(_header('cappy'));
    expect(header.height, lessThan(40)); // no second line
    expect(find.byTooltip('/Users/me/cappy'), findsOneWidget);
    double plus() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.descendant(
                  of: _header('cappy'),
                  matching: find.byTooltip('New chat here'),
                ),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(plus(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('cappy')));
    await tester.pump();
    expect(plus(), 1);
    await mouse.moveTo(tester.getCenter(find.text('Jot it down')));
    await tester.pump();
    expect(plus(), 0);
    // Tabbed to, it shows.
    Focus.of(
      tester.element(
        find.descendant(of: _header('cappy'), matching: find.byIcon(Icons.add)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.pump();
    expect(plus(), 1);
    d.dispose();
  });

  testWidgets('two projects of the same name show their parents; a chat '
      'that needs you says so in its dot’s tooltip, not its row', (
    tester,
  ) async {
    final d = await _sidebar(
      tester,
      chats: [
        ..._chats(),
        chat('w', 'claude', 'Ship it', folder: '/Users/me/work/cappy', age: 7),
      ],
    );
    expect(find.text('cappy  · me'), findsOneWidget);
    expect(find.text('cappy  · work'), findsOneWidget);
    expect(find.text('ledger-poc'), findsOneWidget); // no twin: the name
    expect(find.text('needs you'), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(ChatDot).first,
        matching: find.byTooltip('needs you'),
      ),
      findsOneWidget,
    );
    expect(twinParents(['/a/x/app', '/b/x/app', '/c/web']), {
      '/a/x/app': '/a/x',
      '/b/x/app': '/b/x',
    });
    // A project in the home folder: its parent "~" has no parent of its
    // own (this threw in the sidebar's build).
    final home = Platform.environment['HOME']!;
    expect(twinParents(['$home/app', '$home/x/app']), {
      '$home/app': '~',
      '$home/x/app': 'x',
    });
    // And one under the root.
    expect(twinParents(['/app', '/x/app']), {'/app': '/', '/x/app': 'x'});
    d.dispose();
  });

  testWidgets('golden: ledger-poc collapsed, its dot amber (dark)', (
    tester,
  ) async {
    sidebarCollapsed.value = {'/Users/me/ledger-poc'};
    final d = await _sidebar(tester);
    await expectLater(
      find.byKey(const Key('shot')),
      matchesGoldenFile('goldens/sidebar_collapsed_dark.png'),
    );
    d.dispose();
  });
}
