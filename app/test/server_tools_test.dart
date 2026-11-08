import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

// The agent's dev server tools and show's url (ADR 0100): their rows, their
// permission card, and the page that opens beside the chat.

/// A call to one of Nushi's tools, as Claude's agents or Codex's adapter
/// sends it.
Item _call(
  String id,
  String tool,
  Map<String, Object> args, {
  String status = 'completed',
  bool codex = false,
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: codex ? 'execute' : 'other',
  title: codex ? 'mcp.nushi.$tool' : 'mcp__nushi__$tool',
  status: status,
  text: text,
  input: codex
      ? jsonEncode({'server': 'nushi', 'tool': tool, 'arguments': args})
      : const JsonEncoder.withIndent('  ').convert(args),
);

Item _say(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

/// The ask to run [title]'s tool, with the command the daemon resolved.
Item _ask(String title, String input, {String command = ''}) => Item(
  id: 'ask',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  title: title,
  input: input,
  status: 'pending',
  serverCommand: command,
  options: [
    Option(id: 'yes', name: 'Yes', kind: 'allow_once'),
    Option(id: 'no', name: 'No', kind: 'reject_once'),
  ],
);

final Chat _c = chat('c', 'claude', 'Build the tea shop');
final Chat _other = chat('o', 'claude', 'Something else');

/// The app on chat [select], [items] in chat c.
Future<(FakeDaemon, Daemon)> _app(
  WidgetTester tester, {
  List<Item> items = const [],
  Size size = const Size(1700, 900),
  String select = 'c',
}) async {
  browserFakes();
  viewport(tester, size);
  showDetails.value = false;
  paneWidths.value = {};
  Collapsible.opened.clear();
  final fake = FakeDaemon([_c, _other])
    ..answer = ((input) => switch (input) {
      GetChatRequest(:final chatId) => GetChatResponse(
        chat: chatId == 'c' ? _c : _other,
        items: chatId == 'c' ? items : [],
      ),
      _ => null,
    });
  final d = await fake.connect(tester);
  d.select(select);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (fake, d);
}

/// The daemon asks the Mac to show [url] beside chat c.
Future<void> _showsUrl(WidgetTester tester, FakeDaemon fake, String url) async {
  fake.emit(EventsResponse(chatId: 'c', showUrl: url));
  await tester.pumpAndSettle();
}

/// The address of chat c's browser tab that shows, or null.
String? _page(Daemon d) => switch (d.chats['c']!.preview.value) {
  BrowserTab(:final address) => address.value,
  _ => null,
};

void main() {
  setUpAll(loadFonts);

  group('a dev server tool’s row', () {
    test('its name and title, Claude’s and Codex’s, by its status', () {
      final start = _call('a', 'preview_start', {'name': 'web'});
      expect(serverTool(start), 'preview_start');
      expect(serverName(start), 'web');
      expect(callTitle(start), 'Started web');
      expect(
        callTitle(_call('a', 'preview_start', {'name': 'web'}, codex: true)),
        'Started web',
      );
      expect(
        doingOf(
          _call('a', 'preview_start', {'name': 'web'}, status: 'pending'),
        ),
        'Starting web',
      );
      expect(
        callTitle(
          _call('a', 'preview_start', {'name': 'web'}, status: 'failed'),
        ),
        'Start web',
      );
      expect(
        callTitle(_call('a', 'preview_stop', {'name': 'api'})),
        'Stopped api',
      );
      expect(
        callTitle(_call('a', 'preview_logs', {'name': 'web', 'lines': 50})),
        'Read the logs of web',
      );
      expect(callTitle(_call('a', 'preview_list', {})), 'Listed servers');
      expect(
        doingOf(_call('a', 'preview_list', {}, status: 'in_progress')),
        'Listing servers',
      );
      // Its input yet to come.
      expect(
        doingOf(_call('a', 'preview_start', {}, status: 'pending')..input = ''),
        'Starting a server',
      );
      expect(
        groupLabel([start, _call('b', 'preview_list', {})]),
        'Used 2 server tools',
      );
      // Another server's tool of the same name isn't Nushi's.
      expect(serverTool(Item(title: 'mcp__other__preview_start')), isNull);
      expect(serverTool(Item(title: 'mcp__nushi__preview_open')), isNull);
    });

    test('a name that could read as another is marked', () {
      expect(
        serverName(_call('a', 'preview_start', {'name': 'web\napi\u202E'})),
        'web�api�',
      );
    });

    testWidgets('reads as what it did, never as a command or an MCP call', (
      tester,
    ) async {
      final (_, d) = await _app(
        tester,
        items: [
          _call('a', 'preview_list', {}, text: '[{"name": "web"}]'),
          _say('m', 'Starting it.'),
          _call('b', 'preview_start', {'name': 'web'}, codex: true),
          _say('n', 'And its logs.'),
          _call('c', 'preview_logs', {'name': 'web'}, text: 'VITE ready'),
        ],
      );
      expect(find.textContaining('Listed servers'), findsOneWidget);
      expect(find.textContaining('Started web'), findsOneWidget);
      expect(find.textContaining('Read the logs of web'), findsOneWidget);
      expect(find.textContaining('nushi ·'), findsNothing);
      expect(find.textContaining(r'$ mcp'), findsNothing);
      await closeView(tester, d);
    }, variant: macOnly);

    test('its output is as written, out of a failure’s fence', () {
      expect(serverOutput('web (running)\n# a'), 'web (running)\n# a');
      expect(serverOutput('```\nweb failed\n```'), 'web failed');
      expect(serverOutput('````\na ``` b\n````\n'), 'a ``` b');
      expect(serverOutput('```\na\n```\nafter'), '```\na\n```\nafter');
    });

    for (final width in [1700.0, 720.0]) {
      testWidgets('opens to its output as written, line by line, not Markdown, '
          'at $width', (tester) async {
        const logs =
            'web (running), its last 100 lines at most:\n'
            '9:41:02 AM [vite] page reload src/App.tsx\n'
            'GET /__init__.py 404\n'
            '# not a heading\n'
            '- not a list';
        final (_, d) = await _app(
          tester,
          size: Size(width, 900),
          items: [
            _call('c', 'preview_logs', {'name': 'web'}, text: logs),
            _say('m', 'Then it failed.'),
            _call(
              'f',
              'preview_start',
              {'name': 'web'},
              status: 'failed',
              text:
                  '```\nweb failed: it ended (exit code 1)\n\n'
                  'Its last lines:\n**boom**\n```',
            ),
          ],
        );
        await tester.tap(find.textContaining('Read the logs of web'));
        await tester.tap(find.textContaining('Start web'));
        await tester.pumpAndSettle();
        expect(
          find.text(logs),
          findsOneWidget,
          reason: 'one text, its lines kept',
        );
        expect(
          find.text(
            'web failed: it ended (exit code 1)\n\nIts last lines:\n**boom**',
          ),
          findsOneWidget,
          reason: 'out of its fence, its stars as written',
        );
        await render(
          tester,
          find.byType(NushiApp),
          'server-tool-output-$width',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  });

  group('show of a page', () {
    test('its url, Claude’s and Codex’s; a path isn’t one', () {
      final claude = _call('a', 'show', {'url': 'http://localhost:5173/about'});
      final codex = _call('a', 'show', {
        'url': 'http://localhost:5173',
      }, codex: true);
      expect(showUrl(claude), 'http://localhost:5173/about');
      expect(showUrl(codex), 'http://localhost:5173');
      expect(showPath(claude), isNull);
      expect(showUrl(_call('a', 'show', {'path': 'r.md'})), isNull);
      expect(previewPath(claude), isNull);
      expect(groupLabel([claude]), 'Showed 1 page');
    });

    testWidgets('its row reads “Showed <url>”, and Open opens it in a tab', (
      tester,
    ) async {
      final (_, d) = await _app(
        tester,
        items: [
          _call('a', 'show', {'url': 'http://localhost:5173/about'}),
          _say('m', 'And then.'),
          _call('b', 'show', {'url': 'http://localhost:9'}, status: 'failed'),
        ],
      );
      expect(
        find.textContaining('Showed http://localhost:5173/about'),
        findsOneWidget,
      );
      expect(find.textContaining('Show http://localhost:9'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget, reason: 'not on a failed one');
      expect(find.text('Preview'), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(_page(d), 'http://localhost:5173/about');
      await closeView(tester, d);
    }, variant: macOnly);
  });

  group('the permission card', () {
    testWidgets('of preview_start says the command it runs', (tester) async {
      final (_, d) = await _app(
        tester,
        items: [
          _ask(
            'mcp__nushi__preview_start',
            '{\n  "name": "web"\n}',
            command: 'PORT=5173 /opt/homebrew/bin/pnpm run dev',
          ),
        ],
      );
      expect(find.text('Start web'), findsOneWidget);
      expect(find.text('It runs:'), findsOneWidget);
      expect(
        find.text('PORT=5173 /opt/homebrew/bin/pnpm run dev'),
        findsOneWidget,
      );
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('Codex’s too; with no command, that the start will be '
        'refused; what could read as another marked', (tester) async {
      final (_, d) = await _app(
        tester,
        items: [
          _ask(
            'mcp.nushi.preview_start',
            '{"server": "nushi", "arguments": {"name": "nope"}}',
          ),
        ],
      );
      expect(find.text('Start nope'), findsOneWidget);
      expect(find.textContaining('the start will be refused'), findsOneWidget);
      expect(find.text('It runs:'), findsNothing);
      await closeView(tester, d);
      final (_, d2) = await _app(
        tester,
        items: [
          _ask(
            'mcp__nushi__preview_start',
            '{"name": "web"}',
            command: 'pnpm "run\u202Edev"',
          ),
        ],
      );
      expect(find.text('pnpm "run�dev"'), findsOneWidget);
      await closeView(tester, d2);
    }, variant: macOnly);

    testWidgets('of show’s url and the other tools say what they ask', (
      tester,
    ) async {
      final (_, d) = await _app(
        tester,
        items: [_ask('mcp__nushi__show', '{"url": "http://localhost:5173"}')],
      );
      expect(find.text('Show http://localhost:5173'), findsOneWidget);
      await closeView(tester, d);
      final (_, d2) = await _app(
        tester,
        items: [_ask('mcp__nushi__preview_logs', '{"name": "web"}')],
      );
      expect(find.text('Read the logs of web'), findsOneWidget);
      await closeView(tester, d2);
    }, variant: macOnly);
  });

  // preview_start's card, in both themes.
  for (final (theme, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    testWidgets('preview_start’s card looks, $theme', (tester) async {
      viewport(tester, const Size(520, 240));
      await tester.pumpWidget(
        themed(
          Container(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(16),
            child: PermissionCard(
              _ask(
                'mcp__nushi__preview_start',
                '{"name": "web"}',
                command:
                    'PORT=5173 /opt/homebrew/bin/pnpm run dev --host 127.0.0.1',
              ),
              onAnswer: (_) async {},
            ),
          ),
          tokens: tokens,
          still: true,
        ),
      );
      await tester.pumpAndSettle();
      // The Scaffold, not the app: the app adds the debug banner.
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/preview_start_card_$theme.png'),
      );
    }, variant: macOnly);
  }

  group('the show_url event', () {
    testWidgets('opens the page in a browser tab beside the chat that’s '
        'showing; a server’s address shows its tab already open', (
      tester,
    ) async {
      final (fake, d) = await _app(tester);
      await _showsUrl(tester, fake, 'http://localhost:5173');
      expect(_page(d), 'http://localhost:5173');
      expect(d.chats['c']!.showAsked.value, isNull);
      // A page within it opens a tab of its own; the server's again shows
      // the tab at its address.
      await _showsUrl(tester, fake, 'http://localhost:5173/about');
      expect(_page(d), 'http://localhost:5173/about');
      expect(d.chats['c']!.previewTabs.value, hasLength(2));
      await _showsUrl(tester, fake, 'http://localhost:5173/');
      expect(d.chats['c']!.previewTabs.value, hasLength(2));
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('waits while another chat or Changes shows; never moves '
        'the user', (tester) async {
      final (fake, d) = await _app(tester, select: 'o');
      await _showsUrl(tester, fake, 'http://localhost:5173');
      expect(d.selectedId, 'o');
      expect(_page(d), isNull);
      d.select('c');
      await tester.pumpAndSettle();
      final c = d.chats['c']!;
      expect(_page(d), 'http://localhost:5173');
      c.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _showsUrl(tester, fake, 'http://localhost:8080');
      expect(c.tab.value, ChatTab.changes);
      expect(c.previewTabs.value, hasLength(1));
      c.tab.value = ChatTab.chat;
      await tester.pumpAndSettle();
      expect(_page(d), 'http://localhost:8080');
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('a narrow window keeps the transcript', (tester) async {
      final (fake, d) = await _app(tester, size: const Size(720, 900));
      await _showsUrl(tester, fake, 'http://localhost:5173');
      expect(_page(d), isNull);
      expect(d.chats['c']!.showAsked.value, isNull);
      await closeView(tester, d);
    }, variant: macOnly);
  });
}
