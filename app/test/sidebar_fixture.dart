import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The sidebar's arrangement tests' chats and window
// (`sidebar_arrange_test.dart`, `sidebar_sections_test.dart`); the window
// every sidebar test draws it alone in.

Int64 _at(DateTime t) => Int64(t.millisecondsSinceEpoch);

Chat _chat(
  String id,
  String agent,
  String title,
  String folder, {
  required DateTime created,
  DateTime? updated,
  ChatStatus? status,
}) => Chat(
  id: id,
  agent: agent,
  title: title,
  folder: folder,
  createdUnixMs: _at(created),
  updatedUnixMs: _at(updated ?? created),
  status: status ?? ChatStatus(),
);

/// Six chats in four projects, of four agents, made and updated over two
/// months before [fixtureNow] (Thursday 29 October 2026, noon):
/// - Wire the parcel: Claude, parcel-poc, needs you; made today.
/// - Seed data: PiG, parcel-poc, in a worktree; made yesterday.
/// - Fold the maps: Codex, cubby, working; made 5 days ago, updated today.
/// - Plant the beds: Claude, garden, done; made 19 days ago.
/// - Jot it down: Ante, notes; made in September.
/// - Keep this: Claude, attic, pinned.
List<Chat> arrangeChats() => [
  _chat(
    'a',
    'claude',
    'Wire the parcel',
    '/Users/me/parcel-poc',
    created: fixtureNow.subtract(const Duration(minutes: 10)),
    status: ChatStatus(busy: true, waiting: true),
  ),
  _chat(
      'b',
      'pig',
      'Seed data',
      '/Users/me/parcel-poc/.worktrees/brisk-otter',
      created: DateTime(2026, 10, 28, 9),
    )
    ..worktree = Worktree(
      repo: '/Users/me/parcel-poc',
      path: '/Users/me/parcel-poc/.worktrees/brisk-otter',
      branch: 'nushi/brisk-otter',
    ),
  _chat(
    'c',
    'codex',
    'Fold the maps',
    '/Users/me/cubby',
    created: DateTime(2026, 10, 24, 15),
    updated: fixtureNow.subtract(const Duration(hours: 1)),
    status: ChatStatus(busy: true),
  ),
  _chat(
    'd',
    'claude',
    'Plant the beds',
    '/Users/me/garden',
    created: DateTime(2026, 10, 10, 8),
  )..done = true,
  _chat(
    'e',
    'ante',
    'Jot it down',
    '/Users/me/notes',
    created: DateTime(2026, 9, 3, 18),
  ),
  _chat(
    'p',
    'claude',
    'Keep this',
    '/Users/me/attic',
    created: DateTime(2026, 9, 1, 10),
  )..pin = 1,
];

/// The sidebar alone, [width] wide (260 unless given) and [height] high
/// (the window's unless given) in a window of [size], over [chats]
/// ([arrangeChats] unless given), still (no ring turns) unless not
/// [still], in [tokens]; [icons], the projects' icons the daemon has, by
/// folder. Settled, or one frame when not [settle]. The window is a
/// repaint boundary keyed `screen`, the sidebar's box one keyed `shot`.
Future<(Daemon, FakeDaemon)> arrangedSidebar(
  WidgetTester tester, {
  List<Chat>? chats,
  Tokens tokens = Tokens.dark,
  Size size = const Size(560, 700),
  double width = 260,
  double? height,
  bool still = true,
  bool settle = true,
  Map<String, List<int>> icons = const {},
}) async {
  viewport(tester, size);
  final fake = FakeDaemon(chats ?? arrangeChats())..projectIcons.addAll(icons);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('screen'),
      child: MaterialApp(
        builder: (context, child) => ToastHost(child: child!),
        debugShowCheckedModeBanner: false,
        theme: NushiTheme(tokens).toThemeData(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const Key('shot'),
                child: SizedBox(
                  width: width,
                  height: height ?? size.height,
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
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (d, fake);
}

/// Those of [texts] the sidebar shows, top to bottom (each where it first
/// shows).
List<String> shownInOrder(WidgetTester tester, List<String> texts) {
  // A header's or a row's own words: not a row's Needs you pill, which says
  // what a Status group is called.
  Finder words(String t) => find.descendant(
    of: find.byType(Sidebar),
    matching: find.byElementPredicate(
      (e) => switch (e.widget) {
        final Text w =>
          (w.data ?? w.textSpan?.toPlainText()) == t &&
              e.findAncestorWidgetOfExactType<PhasePill>() == null,
        _ => false,
      },
    ),
  );
  final shown = [
    for (final t in texts)
      if (words(t).evaluate().isNotEmpty) t,
  ];
  double y(String t) => tester.getTopLeft(words(t).first).dy;
  return shown..sort((a, b) => y(a).compareTo(y(b)));
}

/// Every chat's title, headers' names a test adds to it.
const arrangeTitles = [
  'Wire the parcel',
  'Seed data',
  'Fold the maps',
  'Plant the beds',
  'Jot it down',
  'Keep this',
];
