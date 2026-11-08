import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' hide Terminal;
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/server_logs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:xterm2/xterm.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

// The logs drawer (ADR 0100): a dev server's output at the bottom of the
// browser tab's pane, opened from its row in the Servers menu.

const _folder = '/Users/me/nushi';

/// A server's row as the daemon lists it; [logId] names its output.
DevServer _server(
  String name, {
  int index = 0,
  DevServerState state = DevServerState.DEV_SERVER_STATE_RUNNING,
  String id = '',
  String logId = '',
  String error = '',
  String output = '',
  int port = 5173,
}) => DevServer(
  name: name,
  nameOk: true,
  index: index,
  source: '.agents/launch.json',
  command: 'pnpm',
  program: '/opt/homebrew/bin/pnpm',
  args: ['run', 'dev'],
  cwd: _folder,
  url: 'http://localhost:$port',
  port: port,
  state: state,
  error: error,
  output: output,
  serverId: id,
  logId: logId,
  hash: 'hash-$name',
);

/// What a Vite server writes as it starts, colours and all.
const _vite =
    '\x1b[32m\x1b[1mVITE\x1b[22m v6.0.3\x1b[39m  \x1b[2mready in '
    '\x1b[0m\x1b[1m412\x1b[22m\x1b[2m\x1b[0m ms\r\n\r\n'
    '  \x1b[32m➜\x1b[39m  \x1b[1mLocal\x1b[22m:   '
    '\x1b[36mhttp://localhost:\x1b[1m5173\x1b[22m/\x1b[39m\r\n'
    '  \x1b[32m➜\x1b[39m  \x1b[1mNetwork\x1b[22m: use --host to expose\r\n'
    '\x1b[2m9:41:02 AM\x1b[22m \x1b[36m\x1b[1m[vite]\x1b[22m\x1b[39m '
    '\x1b[32mpage reload \x1b[39m\x1b[2msrc/App.tsx\x1b[22m\r\n'
    '\x1b[2m9:41:07 AM\x1b[22m \x1b[33m\x1b[1m[vite]\x1b[22m\x1b[39m '
    '\x1b[33mwarning: unused import "useMemo"\x1b[39m\r\n';

/// The daemon's servers, as the test sets them; the stops recorded.
class _Servers {
  List<DevServer> rows = [];
  final stops = <StopServerRequest>[];

  Object? answer(Object input) => switch (input) {
    GetChatRequest() => GetChatResponse(),
    ListServersRequest() => ListServersResponse(
      folder: _folder,
      servers: rows,
      files: [LaunchFile(path: '.agents/launch.json')],
    ),
    StopServerRequest() => _stop(input),
    _ => null,
  };

  Object? _stop(StopServerRequest r) {
    stops.add(r);
    return null;
  }
}

/// A browser pane on its own, its chat's tab at a server's page, on a
/// daemon whose servers [s] has.
Future<(FakeDaemon, Daemon, ChatState)> _pane(
  WidgetTester tester,
  _Servers s, {
  Tokens tokens = Tokens.dark,
  Brightness brightness = Brightness.dark,
  Size size = const Size(640, 560),
}) async {
  browserFakes();
  viewport(tester, size, brightness: brightness);
  paneWidths.value = {};
  final fake = FakeDaemon([chat('c', 'claude', 'Build the tea shop')])
    ..answer = s.answer;
  final d = await fake.connect(tester);
  final c = d.chats['c']!..openBrowserTab('http://localhost:5173');
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
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d, c);
}

/// Opens the Servers menu and presses the first row's Logs.
Future<void> _openLogs(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Servers'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Button, 'Logs').first);
  await tester.pumpAndSettle();
}

/// The daemon says the folder's servers changed, now as the test has them.
Future<void> _changed(WidgetTester tester, FakeDaemon d) async {
  d.emit(EventsResponse(serversChanged: _folder));
  await tester.pumpAndSettle();
}

/// Sends [text] as the server [logId]'s output.
Future<void> _write(
  WidgetTester tester,
  FakeDaemon d,
  String logId,
  String text, {
  bool ended = false,
}) async {
  d
      .serverLog(logId)
      .add(WatchServerLogResponse(data: utf8.encode(text), ended: ended));
  await tester.pumpAndSettle();
}

/// The drawer's emulator.
Terminal _terminal(WidgetTester tester) =>
    tester.widget<TerminalView>(find.byType(TerminalView)).terminal;

/// The text the drawer shows.
String _shown(WidgetTester tester) => _terminal(tester).buffer.getText();

void main() {
  setUpAll(loadFonts);

  testWidgets('Logs shows on a row with output only, and opens the drawer '
      'under the page with the server’s name, state and port', (tester) async {
    final s = _Servers()
      ..rows = [
        _server('web', id: 'a', logId: 'a'),
        _server(
          'storybook',
          index: 1,
          port: 6006,
          state: .DEV_SERVER_STATE_STOPPED,
        ),
      ];
    final (fake, d, c) = await _pane(tester, s);
    fake.serverLog('a');
    await tester.tap(find.byTooltip('Servers'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Button, 'Logs'), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, 'Logs'));
    await tester.pumpAndSettle();
    expect(c.serverLogs.value?.name, 'web');
    final drawer = find.byType(ServerLogs);
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('web')),
      findsOneWidget,
    );
    expect(find.text('Running'), findsOneWidget);
    expect(find.text(':5173'), findsOneWidget);
    // Docked at the bottom of the pane, the page above it.
    expect(tester.getRect(drawer).bottom, 560);
    expect(tester.getRect(drawer).top, 560 - ServerLogsDrawer.height);
    final watch = fake.calls.whereType<WatchServerLogRequest>().single;
    expect((watch.chatId, watch.serverId), ('c', 'a'));
    // Its output as it comes; a character cut in two still reads whole.
    final bytes = utf8.encode(_vite);
    final cut = bytes.indexOf(0xe2) + 1; // into ➜
    fake.serverLog('a')
      ..add(WatchServerLogResponse(data: bytes.sublist(0, cut)))
      ..add(WatchServerLogResponse(data: bytes.sublist(cut)));
    await tester.pumpAndSettle();
    expect(_shown(tester), contains('VITE v6.0.3  ready in 412 ms'));
    expect(_shown(tester), contains('➜  Local:   http://localhost:5173/'));
    expect(_shown(tester), isNot(contains('�')));
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('Stop is solid red while it runs; Close shuts the drawer', (
    tester,
  ) async {
    final s = _Servers()..rows = [_server('web', id: 'a', logId: 'a')];
    final (fake, d, c) = await _pane(tester, s);
    fake.serverLog('a');
    await _openLogs(tester);
    final stop = find.descendant(
      of: find.byType(ServerLogs),
      matching: find.byTooltip('Stop'),
    );
    final box = tester.widget<Container>(
      find.descendant(of: stop, matching: find.byType(Container)).first,
    );
    final t = NushiTheme.of(tester.element(stop)).t;
    expect((box.decoration! as BoxDecoration).color, t.crashed);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(s.stops.single.serverId, 'a');
    // It ended: no Stop, its output stays.
    await _write(tester, fake, 'a', 'bye\r\n', ended: true);
    s.rows = [_server('web', state: .DEV_SERVER_STATE_STOPPED, logId: 'a')];
    await _changed(tester, fake);
    expect(stop, findsNothing);
    expect(find.text('Stopped'), findsOneWidget);
    expect(_shown(tester), contains('bye'));
    await tester.tap(find.byTooltip('Close logs'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerLogs), findsNothing);
    expect(c.serverLogs.value, isNull);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a run that follows shows in the open drawer', (tester) async {
    final s = _Servers()
      ..rows = [
        _server(
          'web',
          state: .DEV_SERVER_STATE_FAILED,
          error: 'it ended (exit code 1)',
          logId: 'a',
        ),
      ];
    final (fake, d, _) = await _pane(tester, s);
    fake.serverLog('b');
    await _write(tester, fake, 'a', '');
    await _openLogs(tester);
    await _write(tester, fake, 'a', 'Error: Cannot find module vite\r\n');
    expect(find.text('Failed'), findsOneWidget);
    expect(_shown(tester), contains('Cannot find module vite'));
    s.rows = [_server('web', id: 'b', logId: 'b')];
    await _changed(tester, fake);
    await _write(tester, fake, 'b', 'VITE ready\r\n');
    expect(find.text('Running'), findsOneWidget);
    expect(_shown(tester), contains('VITE ready'));
    expect(_shown(tester), isNot(contains('Cannot find module')));
    expect(
      fake.calls.whereType<WatchServerLogRequest>().map((w) => w.serverId),
      ['a', 'b'],
    );
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('its bytes act on nothing: no clipboard, no title, no answer', (
    tester,
  ) async {
    final s = _Servers()..rows = [_server('web', id: 'a', logId: 'a')];
    final (fake, d, _) = await _pane(tester, s);
    final platform = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platform.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    fake.serverLog('a');
    await _openLogs(tester);
    final term = _terminal(tester);
    final answers = <String>[];
    term.onOutput = answers.add;
    // Focused, as after a click into it: the view's own clipboard handler
    // would write then.
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    term.onOutput = null;
    await _write(
      tester,
      fake,
      'a',
      [
        '\x1b]8;;https://example.com\x07click\x1b]8;;\x07\r\n', // a link
        '\x1b]52;c;cm0gLXJmIH4K\x07', // OSC 52: put text on the clipboard
        '\x1b]0;evil title\x07', // a title
        '\x1b]52;c;?\x07', // read the clipboard
      ].join(),
    );
    // A click on the link's text, at the screen's first line.
    await tester.tapAt(
      tester.getTopLeft(find.byType(TerminalView)) + const Offset(16, 12),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(platform.where((m) => m.startsWith('Clipboard')), isEmpty);
    expect(platform.where((m) => m.contains('Title')), isEmpty);
    expect(answers, isEmpty);
    expect(_terminal(tester).onOutput, isNull);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a stream that closes before the end watches again; output '
      'that’s gone says so', (tester) async {
    final s = _Servers()..rows = [_server('web', id: 'a', logId: 'a')];
    final (fake, d, _) = await _pane(tester, s);
    await _write(tester, fake, 'a', '');
    await _openLogs(tester);
    await _write(tester, fake, 'a', 'one\r\n');
    unawaited(fake.serverLog('a').close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<WatchServerLogRequest>(), hasLength(2));
    // The output so far comes again, into a fresh screen: refused now.
    expect(
      find.text('no such server’s output is kept in this chat’s folder'),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a failed row’s tooltip ends by pointing to Logs', (
    tester,
  ) async {
    final s = _Servers()
      ..rows = [
        _server(
          'web',
          state: .DEV_SERVER_STATE_FAILED,
          error: 'it ended (exit code 1)',
          output: 'Error: Cannot find module vite',
          logId: 'a',
        ),
      ];
    final (_, d, _) = await _pane(tester, s);
    await tester.tap(find.byTooltip('Servers'));
    await tester.pumpAndSettle();
    final tip = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message ?? '')
        .firstWhere((m) => m.contains('Cannot find module'));
    expect(
      tip,
      'Error: Cannot find module vite\n\nThe whole output is in Logs.',
    );
    await closeView(tester, d);
  }, variant: macOnly);

  // The drawer in each state, in both themes.
  final states = <String, DevServer>{
    'running': _server('web', id: 'a', logId: 'a'),
    'failed': _server(
      'web',
      state: .DEV_SERVER_STATE_FAILED,
      error: 'it ended (exit code 1)',
      logId: 'a',
    ),
  };
  for (final (theme, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    for (final MapEntry(key: state, value: row) in states.entries) {
      testWidgets('looks, $theme: $state', (tester) async {
        final s = _Servers()..rows = [row];
        final (fake, d, _) = await _pane(
          tester,
          s,
          tokens: tokens,
          brightness: brightness,
        );
        fake.serverLog('a');
        await _openLogs(tester);
        await _write(
          tester,
          fake,
          'a',
          state == 'failed'
              ? '$_vite\x1b[31mError: Cannot find module vite\x1b[39m\r\n'
              : _vite,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/server_logs_${state}_$theme.png'),
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }

  // The whole window, wide and narrow, with the drawer open (renders only).
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
        final s = _Servers()..rows = [_server('web', id: 'a', logId: 'a')];
        final fake = FakeDaemon([chat('c', 'claude', 'Build the tea shop')])
          ..answer = s.answer
          ..serverLog('a');
        final d = await fake.connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.chats['c']!.openBrowserTab('http://localhost:5173');
        await tester.pumpAndSettle();
        await _openLogs(tester);
        await _write(tester, fake, 'a', _vite);
        expect(tester.takeException(), isNull);
        expect(find.byType(ServerLogs), findsOneWidget);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'server_logs_${width.toInt()}_$theme',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }
}
