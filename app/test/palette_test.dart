import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_nav.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'fake_daemon.dart';

/// Two chats in nushi, one in site; b has a pull request.
final _pull = GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi',
  number: 12,
  id: 'PR_12',
  pull: true,
);

List<Chat> _chats() => [
  chat('a', 'claude', 'Fix the login redirect', age: 2),
  chat('b', 'codex', 'Bump the API version', age: 1)..pull = _pull,
  chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 3),
];

/// The app on [_chats], [select] shown; its terminals are one shell's.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  String? select,
  Size size = const Size(1200, 700),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  Object? answer(Object input) => switch (input) {
    ListTerminalsRequest(:final chatId) => ListTerminalsResponse(
      terminals: [
        Terminal(id: 't1', chatId: chatId, folder: '/tmp', shell: 'zsh'),
      ],
    ),
    FindChatPullRequest(:final chatId) => FindChatPullResponse(
      pull: chatId == 'b' ? _pull : null,
    ),
    _ => null,
  };
  // A live shell's stream: it stays open.
  Stream<Object>? streams(Object input) => input is AttachTerminalRequest
      ? (StreamController<AttachTerminalResponse>()..add(
              AttachTerminalResponse(data: utf8.encode('old output\r\n\$ ')),
            ))
            .stream
      : null;
  final fake = FakeDaemon(_chats())
    ..answer = answer
    ..streams = streams;
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  if (select != null) {
    d.select(select);
    await tester.pumpAndSettle();
  }
  addTearDown(() {
    recentRows.clear();
    terminalChats.value = {};
  });
  return (d, fake);
}

Future<void> _keys(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
  bool control = false,
  bool shift = false,
}) async {
  final mods = [
    if (control) LogicalKeyboardKey.controlLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pumpAndSettle();
}

/// [text] in the palette.
Finder _p(String text) =>
    find.descendant(of: find.byType(Palette), matching: find.text(text));

/// Types [text] into the palette's field.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(of: find.byType(Palette), matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('⌃Tab and ⌃⇧Tab cycle the tabs, Pull request only with one', (
    tester,
  ) async {
    final (d, _) = await _app(tester, select: 'a');
    final a = d.chats['a']!;
    Future<void> next({bool back = false}) =>
        _keys(tester, LogicalKeyboardKey.tab, control: true, shift: back);
    await next();
    expect(a.shownTab, ChatTab.changes);
    await next();
    expect(a.shownTab, ChatTab.chat); // no pull request: back to Chat
    await next(back: true);
    expect(a.shownTab, ChatTab.changes);

    d.select('b'); // a chat opens on its transcript
    await tester.pumpAndSettle();
    final b = d.chats['b']!;
    expect(b.shownTab, ChatTab.chat);
    await next();
    await next();
    expect(b.shownTab, ChatTab.pull);
    await next();
    expect(b.shownTab, ChatTab.chat);
    await next(back: true);
    expect(b.shownTab, ChatTab.pull);
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('⌃⌘2 shows Changes with the focus in the terminal; there ⌘K '
      'clears it and ⌘⇧P opens the palette', (tester) async {
    terminalChats.value = {'a'};
    final (d, _) = await _app(tester, select: 'a');
    final view = find.byType(TerminalView);
    expect(view, findsOneWidget);
    await tester.tap(view);
    await tester.pumpAndSettle();
    final term = tester.widget<TerminalView>(view).terminal;
    expect(term.buffer.getText(), contains('old output'));

    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    expect(find.byType(Palette), findsNothing);
    expect(term.buffer.getText(), isNot(contains('old output')));

    await _keys(tester, LogicalKeyboardKey.digit2, meta: true, control: true);
    expect(d.chats['a']!.shownTab, ChatTab.changes);

    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();
    await _keys(tester, LogicalKeyboardKey.keyP, meta: true, shift: true);
    expect(find.byType(Palette), findsOneWidget);
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('⌘K opens the palette; typing filters, Enter runs', (
    tester,
  ) async {
    final (d, _) = await _app(tester, select: 'a');
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    expect(find.byType(Palette), findsOneWidget);
    expect(_p('Release notes'), findsOneWidget);
    expect(_p('⌘N'), findsOneWidget); // New chat's key

    await _type(tester, 'sett');
    expect(_p('Release notes'), findsNothing);
    expect(_p('Settings'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsNothing);
    expect(d.settings, SettingsSection.general);

    // What ran comes first next time.
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    final rows = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(rows.first).data, 'Settings');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsNothing);
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('a chat’s row opens the chat; its project’s chats first', (
    tester,
  ) async {
    final (d, _) = await _app(tester, select: 'a');
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    double y(String text) => tester.getCenter(_p(text)).dy;
    // a shows: b (nushi) before c (site); a itself isn't offered.
    expect(y('Bump the API version'), lessThan(y('Release notes')));
    expect(_p('Fix the login redirect'), findsNothing);
    await tester.tap(_p('Release notes'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'c');
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('actions that don’t apply are left out', (tester) async {
    final (d, _) = await _app(tester);
    expect(d.selected, isNull);
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    expect(_p('New chat'), findsOneWidget);
    expect(_p('Settings'), findsOneWidget);
    for (final t in ['Show changes', 'Archive chat', 'Open file…']) {
      expect(_p(t), findsNothing, reason: t);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    d.select('a'); // no pull request
    await tester.pumpAndSettle();
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    await _type(tester, 'show');
    expect(_p('Show changes'), findsOneWidget);
    expect(_p('Show pull request'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    d.showJira(open: true); // no chat shows: its tabs don't apply
    await tester.pumpAndSettle();
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    expect(_p('Show changes'), findsNothing);
    expect(_p('Close Jira'), findsOneWidget);
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('golden: the palette with a few matches, dark', (tester) async {
    await loadFonts();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _app(tester, select: 'b');
    await _keys(tester, LogicalKeyboardKey.keyK, meta: true);
    await _type(tester, 's');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/palette_dark.png'),
    );
    tester.daemonOf().dispose();
  }, variant: macOS);
}

extension on WidgetTester {
  Daemon daemonOf() => widget<NushiApp>(find.byType(NushiApp)).daemon;
}
