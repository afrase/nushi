// The window's frame (ADR 0111): the panes floating on the window's own
// background, the sidebar straight on it, a chat's details as cards beside
// its pane, and the header inside it. Rendered at 1700 and 720, in both
// themes (`make renders TEST=test/frame_test.dart`).
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Paginate the home feed: 20 a page, and keep the reader’s place.',
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        '`ListPosts` reads the whole table in one query. I’ll give it a '
        'keyset cursor on `(published, id)`, so a post published while '
        'someone reads doesn’t shift the pages.',
  ),
  Item(
    id: 't',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'execute',
    title: 'go test ./internal/store/...',
    status: 'completed',
  ),
];

/// A few chats in two projects: the open one working with a Jira issue,
/// one that needs you, one with a color, one pinned.
List<Chat> _chats() => [
  chat(
    'c',
    'claude',
    'Paginate the feed',
    folder: '/Users/me/lumen',
    status: ChatStatus(
      busy: true,
      started: Int64(
        fixtureNow.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      ),
    ),
  )..jiraKey = 'LUM-142',
  chat(
    'n',
    'codex',
    'Atom feed drops the summary',
    folder: '/Users/me/lumen',
    age: 5,
    status: ChatStatus(busy: true, waiting: true),
  ),
  chat('d', 'claude', 'Resize images at build time', folder: '/Users/me/lumen')
    ..color = 'teal'
    ..done = true,
  chat('q', 'ante', 'Rewrite the quickstart', folder: '/Users/me/lumen-docs'),
  chat('p', 'claude', 'Release notes for 0.9', folder: '/Users/me/lumen')
    ..pin = 1,
];

/// The window on those chats, [open] showing (none for the empty window).
Future<Daemon> _window(
  WidgetTester tester, {
  required Size size,
  Brightness brightness = Brightness.dark,
  String? open = 'c',
  bool details = false,
  bool sidebar = true,
  bool terminal = false,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = details;
  sidebarHidden.value = !sidebar;
  final chats = _chats();
  final fake = FakeDaemon(chats);
  if (terminal) {
    FakeShells(
      fake,
      terminals: [
        Terminal(
          id: 't1',
          chatId: 'c',
          folder: '/Users/me/lumen',
          shell: 'fish',
        ),
      ],
    );
    terminalChats.value = {'c'};
  }
  final shells = fake.answer;
  fake.answer = (input) => switch (input) {
    GetChatRequest(:final chatId) => GetChatResponse(
      chat: chats.firstWhere((c) => c.id == chatId),
      items: _items,
      status: chats.firstWhere((c) => c.id == chatId).status,
      config: [
        ConfigOption(
          id: 'model',
          category: 'model',
          current: 'opus',
          values: [ConfigValue(value: 'opus', name: 'Opus')],
        ),
      ],
    ),
    GetMemoryRequest() => GetMemoryResponse(
      chats: [MapEntry('c', Int64(210 << 20))],
      daemon: Int64(48 << 20),
      app: Int64(390 << 20),
    ),
    _ => shells?.call(input),
  };
  final d = await fake.connect(tester);
  if (open != null) d.select(open);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return d;
}

void main() {
  setUpAll(loadFonts);

  // A toggle never moves when pressed (ADR 0111): the details are inside
  // the pane, under its header, so the header's buttons stay put.
  for (final sidebar in [true, false]) {
    testWidgets('the header’s buttons are where they were with the details '
        'shown and hidden, the sidebar ${sidebar ? 'shown' : 'hidden'}', (
      tester,
    ) async {
      final d = await _window(
        tester,
        size: const Size(1700, 1000),
        sidebar: sidebar,
      );
      Rect at(String tooltip) => tester.getRect(find.byTooltip(tooltip));
      // The terminal's, the browser's and the menu's buttons beside it.
      List<Rect> others() => [
        tester.getRect(find.byType(TerminalButton)),
        tester.getRect(find.byType(BrowserButton)),
        at('Chat menu'),
      ];
      expect(find.byType(DetailsPanel), findsNothing);
      final hidden = at('Show details');
      final rest = others();
      final header = tester.getRect(find.byType(ChatHeader));
      final pane = tester.getRect(find.byType(Pane));

      await tester.tap(find.byTooltip('Show details'));
      await tester.pump();
      // At once, while they slide in, and once they're there.
      expect(at('Hide details'), hidden);
      await tester.pump(const Duration(milliseconds: 60));
      expect(at('Hide details'), hidden);
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPanel), findsOneWidget);
      expect(at('Hide details'), hidden);
      expect(others(), rest);
      expect(tester.getRect(find.byType(ChatHeader)), header);
      expect(tester.getRect(find.byType(Pane)), pane);

      await tester.tap(find.byTooltip('Hide details'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPanel), findsNothing);
      expect(at('Show details'), hidden);
      await closeView(tester, d);
    }, variant: _mac);
  }

  for (final (theme, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      testWidgets('a chat, its details in its pane, $w wide, $theme', (
        tester,
      ) async {
        final d = await _window(
          tester,
          size: Size(width, 1000),
          brightness: brightness,
          details: true,
        );
        await render(tester, find.byType(NushiApp), 'frame-chat-$w-$theme');
        // The pane floats: the window's margin above, below and at the
        // right; the sidebar brings the gap at its left.
        final pane = tester.getRect(find.byType(Pane));
        final side = tester.getRect(find.byType(Sidebar));
        expect(pane.top, NushiTheme.windowPad);
        expect(pane.bottom, 1000 - NushiTheme.windowPad);
        expect(pane.left, side.right);
        // The header is the pane's top, its menu at the pane's edge.
        final header = tester.getRect(find.byType(ChatHeader));
        expect(header.top, pane.top);
        expect(header.height, PaneHeader.height);
        final menu = tester.getRect(find.byTooltip('Chat menu'));
        expect(menu.right, pane.right - ChatHeader.end);
        // The pane takes the room whatever shows in it.
        expect(pane.right, width - NushiTheme.windowPad);
        expect(header.right, pane.right);
        if (width > 1200) {
          // The details are a column in the pane, under the header, at
          // its right.
          final details = tester.getRect(find.byType(DetailsPanel));
          expect(details.width, DetailsPanel.width);
          expect(details.right, pane.right);
          expect(details.top, header.bottom);
          expect(details.bottom, pane.bottom);
        } else {
          expect(find.byType(DetailsPanel), findsNothing);
        }
        // The agents' counts and the memory are the sidebar's foot.
        final status = tester.getRect(find.byType(StatusBar));
        expect(status.bottom, 1000 - NushiTheme.windowPad);
        expect(status.left, greaterThanOrEqualTo(side.left));
        expect(status.right, lessThanOrEqualTo(side.right));
        expectTextInside(tester, width);
        await closeView(tester, d);
      }, variant: _mac);

      // For the owner's look (2026-11-11): the details shown and hidden.
      for (final (state, details) in [('open', true), ('closed', false)]) {
        testWidgets('the details $state, $w wide, $theme', (tester) async {
          final d = await _window(
            tester,
            size: Size(width, 1000),
            brightness: brightness,
            details: details,
            sidebar: false,
          );
          await render(
            tester,
            find.byType(NushiApp),
            'details-$state-$w-$theme',
          );
          expect(
            find.byType(DetailsPanel),
            details && width > 1200 ? findsOneWidget : findsNothing,
          );
          expectTextInside(tester, width);
          await closeView(tester, d);
        }, variant: _mac);
      }

      testWidgets('the sidebar hidden, $w wide, $theme', (tester) async {
        final d = await _window(
          tester,
          size: Size(width, 1000),
          brightness: brightness,
          sidebar: false,
        );
        await render(tester, find.byType(NushiApp), 'frame-hidden-$w-$theme');
        final pane = tester.getRect(find.byType(Pane));
        expect(pane.left, NushiTheme.windowPad);
        expect(pane.top, NushiTheme.windowPad);
        expect(pane.right, width - NushiTheme.windowPad);
        // The pane is as high as beside the sidebar, so nothing in it
        // moves as the sidebar comes and goes; the status card goes with
        // the sidebar.
        expect(pane.bottom, 1000 - NushiTheme.windowPad);
        expect(find.byType(StatusBar), findsNothing);
        // The title starts past the traffic lights.
        final title = tester.getRect(find.text('Paginate the feed'));
        expect(title.left, greaterThan(84));
        final menu = tester.getRect(find.byTooltip('Chat menu'));
        expect(menu.right, pane.right - ChatHeader.end);
        expectTextInside(tester, width);
        await closeView(tester, d);
      }, variant: _mac);
    }

    // What takes the chat's place sits in the same pane, its header the
    // pane's top; Settings opens over all of it.
    final views = <String, void Function(Daemon)>{
      'changes': (d) => d.chats['c']!.tab.value = ChatTab.changes,
      'jira': (d) => d.go(const JiraPlace()),
      'github': (d) => d.go(const GitHubPlace()),
      'settings': (d) => d.openSettings(),
    };
    for (final MapEntry(key: name, value: go) in views.entries) {
      for (final width in [1700.0, 720.0]) {
        final w = width.toInt();
        testWidgets('$name in the main pane, $w wide, $theme', (tester) async {
          final d = await _window(
            tester,
            size: Size(width, 1000),
            brightness: brightness,
          );
          go(d);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          await render(tester, find.byType(NushiApp), 'frame-$name-$w-$theme');
          expect(tester.takeException(), isNull);
          final pane = tester.getRect(find.byType(Pane));
          final side = tester.getRect(find.byType(Sidebar));
          expect(pane.left, side.right);
          expect(pane.top, NushiTheme.windowPad);
          expect(pane.right, width - NushiTheme.windowPad);
          expect(pane.bottom, 1000 - NushiTheme.windowPad);
          // A header of the pane's, at its top, as high as the chat's.
          final header = tester.getRect(
            find
                .descendant(
                  of: find.byType(Pane),
                  matching: find.byWidgetPredicate(
                    (w) => w is PaneHeader || w is ChatHeader,
                  ),
                )
                .first,
          );
          expect(header.top, pane.top);
          expect(header.height, PaneHeader.height);
          expectTextInside(tester, width);
          await closeView(tester, d);
        }, variant: _mac);
      }
    }

    // To look at only (`make renders`).
    testWidgets(
      'a terminal under the chat, in its pane, $theme',
      (tester) async {
        final d = await _window(
          tester,
          size: const Size(1700, 1000),
          brightness: brightness,
          details: true,
          terminal: true,
        );
        await render(tester, find.byType(NushiApp), 'frame-terminal-$theme');
        await closeView(tester, d);
      },
      variant: _mac,
      skip: rendersDir == null,
    );

    testWidgets('the empty window, $theme', (tester) async {
      final d = await _window(
        tester,
        size: const Size(1700, 1000),
        brightness: brightness,
        open: null,
      );
      await render(tester, find.byType(NushiApp), 'frame-empty-$theme');
      final pane = tester.getRect(find.byType(Pane));
      expect(pane.top, NushiTheme.windowPad);
      expect(pane.right, 1700 - NushiTheme.windowPad);
      await closeView(tester, d);
    }, variant: _mac);

    // To look at only (`make renders`).
    testWidgets(
      'a menu over the new surfaces, $theme',
      (tester) async {
        final d = await _window(
          tester,
          size: const Size(1700, 1000),
          brightness: brightness,
          details: true,
        );
        await tester.tap(
          find.text('Atom feed drops the summary'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await render(tester, find.byType(NushiApp), 'frame-menu-$theme');
        await closeView(tester, d);
      },
      variant: _mac,
      skip: rendersDir == null,
    );
  }
}
