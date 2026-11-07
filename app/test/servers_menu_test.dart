import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/servers_menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

// The Servers menu (ADR 0098): a browser tab's title row's button, left of
// its ⋯, listing the chat's folder's dev servers, as Claude desktop's.

const _folder = '/Users/me/nushi';

/// A server's row as the daemon lists it.
DevServer _server(
  String name, {
  int index = 0,
  DevServerState state = DevServerState.DEV_SERVER_STATE_STOPPED,
  String id = '',
  String error = '',
  String output = '',
  String source = '.agents/launch.json',
  Map<String, String> env = const {},
  List<String> flagged = const [],
  String problem = '',
  int port = 3000,
}) => DevServer(
  name: name,
  nameOk: true,
  index: index,
  source: source,
  command: 'pnpm',
  program: '/opt/homebrew/bin/pnpm',
  args: ['run', 'dev', '--port', '$port'],
  cwd: _folder,
  env: env.entries,
  flaggedEnv: flagged,
  url: 'http://localhost:$port',
  port: port,
  state: state,
  error: error,
  output: output,
  serverId: id,
  problem: problem,
  hash: problem.isEmpty ? 'hash-$name-$port' : '',
);

/// The daemon's servers, as the test sets them; StartServer and the stops
/// recorded.
class _Servers {
  List<DevServer> rows = [];
  List<LaunchFile> files = [LaunchFile(path: '.agents/launch.json')];
  final starts = <StartServerRequest>[];
  final stops = <StopServerRequest>[];
  final stopAlls = <StopAllServersRequest>[];

  Object? answer(Object input) => switch (input) {
    GetChatRequest() => GetChatResponse(),
    ListServersRequest() => ListServersResponse(
      folder: _folder,
      servers: rows,
      files: files,
    ),
    StartServerRequest() => _start(input),
    StopServerRequest() => _record(stops, input),
    StopAllServersRequest() => _record(stopAlls, input),
    _ => null,
  };

  /// Adds [r] to [list]; the call's answer is the empty one.
  Object? _record<T>(List<T> list, T r) {
    list.add(r);
    return null;
  }

  /// Why StartServer refuses, when it does.
  String? refuse;

  StartServerResponse _start(StartServerRequest r) {
    starts.add(r);
    if (refuse case final why?) {
      throw ConnectException(Code.failedPrecondition, why);
    }
    rows[r.index] = rows[r.index].deepCopy()
      ..state = DevServerState.DEV_SERVER_STATE_STARTING
      ..serverId = 'srv${r.index}';
    return StartServerResponse(server: rows[r.index]);
  }
}

/// A browser pane on its own, its chat's tab at a server's page, on a
/// daemon whose servers [s] has; motion off, so a spinner stands still.
Future<(FakeDaemon, ChatState)> _pane(
  WidgetTester tester,
  _Servers s, {
  Tokens tokens = Tokens.dark,
  Brightness brightness = Brightness.dark,
  bool expanded = false,
  VoidCallback? onExpand,
}) async {
  browserFakes();
  viewport(tester, const Size(560, 420), brightness: brightness);
  final fake = FakeDaemon([chat('c', 'claude', 'Build the tea shop')])
    ..answer = s.answer;
  final d = await fake.connect(tester);
  final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: c.preview,
          builder: (context, tab, _) => tab is BrowserTab
              ? BrowserPane(
                  key: ObjectKey(tab),
                  chat: c,
                  tab: tab,
                  daemon: d,
                  onClose: () {},
                  expanded: expanded,
                  onExpand: onExpand ?? () {},
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  _shown = d;
  return (fake, c);
}

/// The daemon [_pane] made last, which [_close] ends.
late Daemon _shown;

/// Takes the pane away and ends its daemon.
Future<void> _close(WidgetTester tester) => closeView(tester, _shown);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Servers'));
  await tester.pumpAndSettle();
}

/// The daemon says the folder's servers changed, now as the test has them.
Future<void> _changed(WidgetTester tester, FakeDaemon d) async {
  d.emit(EventsResponse(serversChanged: _folder));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the button sits left of the ⋯, and the menu lists the '
      'servers, then Add server', (tester) async {
    final s = _Servers()..rows = [_server('court-finder')];
    await _pane(tester, s);
    final servers = tester.getRect(find.byTooltip('Servers'));
    final more = tester.getRect(find.byTooltip('More'));
    expect(servers.right, lessThanOrEqualTo(more.left));
    expect(servers.center.dy, closeTo(more.center.dy, 0.5));
    await _openMenu(tester);
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('court-finder'), findsOneWidget);
    expect(find.text('pnpm run dev --port 3000'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
    expect(find.text('Stop all servers'), findsNothing);
    await _close(tester);
  }, variant: macOnly);

  testWidgets('Run starts the entry by its place, and its page opens '
      'beside the chat once it answers', (tester) async {
    final s = _Servers()
      ..rows = [_server('api', port: 8080), _server('web', index: 1)];
    final (d, c) = await _pane(tester, s);
    c.openBrowserTab('https://example.com');
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.byTooltip('Run').last);
    await tester.pumpAndSettle();
    expect(s.starts.single.index, 1);
    expect(s.starts.single.hash, 'hash-web-3000');
    expect(c.previewTabs.value, hasLength(2));
    s.rows[1] = s.rows[1].deepCopy()
      ..state = DevServerState.DEV_SERVER_STATE_RUNNING;
    await _changed(tester, d);
    // The tab already at its origin shows; none is added.
    expect(c.previewTabs.value, hasLength(2));
    expect(
      (c.preview.value! as BrowserTab).address.value,
      'http://localhost:3000',
    );
    // A click on a running server's name shows its page; ■ stops it.
    c.showPreviewTab(c.previewTabs.value.last);
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.text('web'));
    await tester.pumpAndSettle();
    expect(
      (c.preview.value! as BrowserTab).address.value,
      'http://localhost:3000',
    );
    await _openMenu(tester);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(s.stops.single.serverId, 'srv1');
    await _close(tester);
  }, variant: macOnly);

  testWidgets('a start that fails opens nothing', (tester) async {
    final s = _Servers()..rows = [_server('web')];
    final (d, c) = await _pane(tester, s);
    await _openMenu(tester);
    await tester.tap(find.byTooltip('Run'));
    await tester.pumpAndSettle();
    s.rows[0] = s.rows[0].deepCopy()
      ..state = DevServerState.DEV_SERVER_STATE_FAILED
      ..error = 'port 3000 is in use by node (pid 412), and autoPort is false';
    await _changed(tester, d);
    s.rows[0] = s.rows[0].deepCopy()
      ..state = DevServerState.DEV_SERVER_STATE_RUNNING;
    await _changed(tester, d);
    expect(c.previewTabs.value, hasLength(1));
    await _close(tester);
  }, variant: macOnly);

  testWidgets('a start refused outright says why on its row', (tester) async {
    final s = _Servers()
      ..rows = [_server('web')]
      ..refuse = '5 servers already run in this folder: stop one first';
    final (d, _) = await _pane(tester, s);
    await _openMenu(tester);
    await tester.tap(find.byTooltip('Run'));
    await tester.pumpAndSettle();
    expect(find.text(s.refuse!), findsOneWidget);
    // The folder's servers changed (one stopped): what refused it may
    // have, and the row no longer says so.
    s.refuse = null;
    await _changed(tester, d);
    expect(
      find.text('5 servers already run in this folder: stop one first'),
      findsNothing,
    );
    await _close(tester);
  }, variant: macOnly);

  testWidgets('a start of an entry changed since it was listed says so above '
      'the rows, until the menu opens again', (tester) async {
    const why = 'the launch file changed since it was shown: look at it again';
    final s = _Servers()
      ..rows = [_server('web')]
      ..refuse = why;
    await _pane(tester, s);
    await _openMenu(tester);
    s.rows = [_server('web', port: 4000)];
    await tester.tap(find.byTooltip('Run'));
    await tester.pumpAndSettle();
    expect(find.text(why), findsOneWidget);
    expect(find.text('pnpm run dev --port 4000'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(find.text(why), findsNothing);
    await _close(tester);
  }, variant: macOnly);

  testWidgets('a failed row’s tooltip has the end of its output', (
    tester,
  ) async {
    final s = _Servers()
      ..rows = [
        _server(
          'web',
          state: DevServerState.DEV_SERVER_STATE_FAILED,
          error: 'it ended (exit code 1)',
          output: [for (var i = 1; i <= 120; i++) 'line $i'].join('\n'),
        ),
      ];
    await _pane(tester, s);
    await _openMenu(tester);
    final tip = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message ?? '')
        .firstWhere((m) => m.contains('line 120'));
    expect(tip.split('\n'), hasLength(18));
    expect(tip, startsWith('line 103\n'));
    await _close(tester);
  }, variant: macOnly);

  testWidgets('Stop all servers shows with more than one running', (
    tester,
  ) async {
    final s = _Servers()
      ..rows = [
        _server(
          'api',
          state: DevServerState.DEV_SERVER_STATE_RUNNING,
          id: 'a',
          port: 8080,
        ),
        _server(
          'web',
          index: 1,
          state: DevServerState.DEV_SERVER_STATE_STARTING,
          id: 'b',
        ),
      ];
    await _pane(tester, s);
    await _openMenu(tester);
    await tester.tap(find.text('Stop all servers'));
    await tester.pumpAndSettle();
    expect(s.stopAlls.single.chatId, 'c');
    await _close(tester);
  }, variant: macOnly);

  testWidgets('Add server puts the request in the box, unsent; an archived '
      'chat can’t take it', (tester) async {
    final s = _Servers()..rows = [];
    final (_, c) = await _pane(tester, s);
    await _openMenu(tester);
    expect(find.text(noServers), findsOneWidget);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    expect(c.draft.put.value, addServerDraft);
    expect(addServerDraft, contains('.agents/launch.json'));
    c.archived = true;
    await _openMenu(tester);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('The chat is archived'), findsOneWidget);
    await _close(tester);
  }, variant: macOnly);

  testWidgets('a chat in a scratch folder has no folder to add a server to', (
    tester,
  ) async {
    final (_, c) = await _pane(tester, _Servers());
    c.scratch = true;
    await _openMenu(tester);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    expect(c.draft.put.value, isNull);
    expect(find.byTooltip('This chat has no folder'), findsOneWidget);
    await _close(tester);
  }, variant: macOnly);

  testWidgets('Add server collapses the expanded tab, so the box shows', (
    tester,
  ) async {
    var collapsed = 0;
    final (_, c) = await _pane(
      tester,
      _Servers(),
      expanded: true,
      onExpand: () => collapsed++,
    );
    await _openMenu(tester);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    expect(collapsed, 1);
    expect(c.draft.put.value, addServerDraft);
    await _close(tester);
  }, variant: macOnly);

  testWidgets('the composer takes Add server’s text and the focus', (
    tester,
  ) async {
    final d = await browserApp(tester);
    final c = d.chats['c']!..draft.text.text = 'First this.';
    c.draft.put.value = addServerDraft;
    await tester.pumpAndSettle();
    expect(c.draft.text.text, 'First this.\n\n$addServerDraft');
    expect(c.draft.put.value, isNull);
    await closeView(tester, d);
  }, variant: macOnly);

  // The menu in each state, in both themes.
  final states = <String, List<DevServer> Function()>{
    'empty': () => [],
    'entries': () => [
      _server('court-finder'),
      _server(
        'storybook',
        index: 1,
        source: '.claude/launch.json',
        port: 6006,
        env: {'NODE_OPTIONS': '--max-old-space-size=4096'},
        flagged: ['NODE_OPTIONS'],
      ),
      _server(
        'worker',
        index: 2,
        problem: '"cwd" names no folder in the project',
      ),
    ],
    'starting': () => [
      _server(
        'court-finder',
        state: DevServerState.DEV_SERVER_STATE_STARTING,
        id: 'a',
      ),
    ],
    'running': () => [
      _server(
        'court-finder',
        state: DevServerState.DEV_SERVER_STATE_RUNNING,
        id: 'a',
      ),
    ],
    'failed': () => [
      _server(
        'court-finder',
        state: DevServerState.DEV_SERVER_STATE_FAILED,
        error: 'it ended (exit code 1) before answering on port 3000',
        output: 'Error: Cannot find module vite',
      ),
    ],
    'several': () => [
      _server(
        'api',
        state: DevServerState.DEV_SERVER_STATE_RUNNING,
        id: 'a',
        port: 8080,
      ),
      _server(
        'court-finder',
        index: 1,
        state: DevServerState.DEV_SERVER_STATE_NOT_ANSWERING,
        id: 'b',
      ),
      _server('storybook', index: 2, port: 6006),
    ],
  };
  for (final (theme, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    for (final MapEntry(key: state, value: rows) in states.entries) {
      testWidgets('looks, $theme: $state', (tester) async {
        final s = _Servers()..rows = rows();
        await _pane(tester, s, tokens: tokens, brightness: brightness);
        await _openMenu(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/servers_menu_${state}_$theme.png'),
        );
        await _close(tester);
      }, variant: macOnly);
    }
  }

  // The whole window, wide and narrow, with the menu open (renders only).
  for (final width in [1700.0, 720.0]) {
    for (final (theme, brightness) in [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      testWidgets('renders at $width, $theme', (tester) async {
        browserFakes();
        viewport(tester, Size(width, 900), brightness: brightness);
        showDetails.value = false;
        paneWidths.value = {};
        final s = _Servers()..rows = states['several']!();
        final fake = FakeDaemon([chat('c', 'claude', 'Build the tea shop')])
          ..answer = s.answer;
        final d = await fake.connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.chats['c']!.openBrowserTab('http://localhost:8080');
        await tester.pumpAndSettle();
        await _openMenu(tester);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'servers_menu_${width.toInt()}_$theme',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }
}
