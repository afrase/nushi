import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/code_run_view.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

// ▷ on an agent's shell block: it types the block into the chat's
// terminal, a spinner while it runs (✕ under the pointer stops it), the
// newest output under the block, and the output in the box at its end.

const _run = 'Run, and send its output to Claude with your next message';
const _cancel = 'Running — click to cancel';
const _prompt = '\x1b]133;A\x1b\\> \x1b]133;B\x1b\\';

const _message =
    'Start the server:\n\n'
    '```bash\n\$ python3 -m tennis.server\n```\n\n'
    'Or by hand:\n\n'
    '```python\nserve()\n```\n\n'
    '```\nls\n```\n';

typedef _View = (FakeShells, Daemon, ChatState);

Future<_View> _view(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  String text = _message,
  bool live = false,
  bool phone = false,
  bool box = false,
}) async {
  final fake = FakeDaemon([]);
  final shells = FakeShells(
    fake,
    terminals: [
      Terminal(id: 'a', chatId: 'c', folder: '/Users/me/nushi', shell: 'fish'),
    ],
  )..replay['a'] = _prompt;
  addTearDown(shells.close);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  d.chats['c'] = chat;
  d.terminals.active['c'] = 'a';
  Widget message = LinkedMarkdown(text, chat, d, live: live);
  if (phone) message = TouchTargets(child: message);
  await tester.pumpWidget(
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        backgroundColor: tokens.base,
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const Key('view'),
            child: Container(
              width: 640,
              color: tokens.base,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  if (box)
                    ListenableBuilder(
                      listenable: chat,
                      builder: (context, _) => Composer(chat: chat, daemon: d),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (shells, d, chat);
}

/// Lets the calls, the stream's messages and the frames through.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

/// Runs the bash block and lets it write [output], then end with [exit]
/// (or not, when null).
Future<void> _runIt(
  WidgetTester tester,
  FakeShells shells, {
  String output = '',
  int? exit,
}) async {
  await tester.tap(find.byTooltip(_run));
  await _settle(tester);
  shells.write('a', '\r\n\x1b]133;C\x1b\\$output');
  if (exit != null) shells.write('a', '\x1b]133;D;$exit\x1b\\$_prompt');
  await _settle(tester);
}

Future<void> _end(WidgetTester tester, Daemon d) async {
  await closeView(tester, d);
  await tester.pump(const Duration(seconds: 2)); // a tooltip's timers
}

void main() {
  setUpAll(loadFonts);

  testWidgets('▷ on shell blocks only, once whole, not on the phone', (
    tester,
  ) async {
    var (_, d, _) = await _view(tester);
    expect(find.byTooltip(_run), findsOne, reason: 'not python, not untagged');
    expect(find.byTooltip('Copy'), findsNWidgets(3));
    await _end(tester, d);

    (_, d, _) = await _view(tester, text: '```bash\nmake check\n', live: true);
    expect(find.byTooltip(_run), findsNothing, reason: 'still streaming');
    await _end(tester, d);

    (_, d, _) = await _view(tester, phone: true);
    expect(find.byTooltip(_run), findsNothing);
    await _end(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('running: a spinner, ✕ under the pointer stops it; the '
        'newest line under the block, its exit at the end, $name', (
      tester,
    ) async {
      final (shells, d, _) = await _view(tester, tokens: tokens);
      await _runIt(
        tester,
        shells,
        output: '\x1b[2mINFO\x1b[m serving on http://127.0.0.1:8000\r\n',
      );
      expect(shells.typed['a'], ['python3 -m tennis.server\r']);
      expect(find.byType(Spinner), findsOne);
      expect(find.text('INFO serving on http://127.0.0.1:8000'), findsOne);
      await expectLater(
        find.byKey(const Key('view')),
        matchesGoldenFile('goldens/code_run_running_$name.png'),
      );

      // A pointer's hover shows as on the Mac, after the test's taps.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byTooltip(_cancel)));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOne);
      expect(find.byType(Spinner), findsNothing);
      await tester.tap(find.byTooltip(_cancel));
      await tester.pump();
      expect(shells.typed['a']!.last, '\x03');
      shells.write('a', '^C\x1b]133;D;130\x1b\\$_prompt');
      await mouse.moveTo(Offset.zero);
      await _settle(tester);
      expect(find.byTooltip(_run), findsOne);
      expect(find.text('exit 130'), findsOne);
      final exit = tester.widget<Text>(find.text('exit 130'));
      expect(exit.style?.color, tokens.crashed);

      await _runIt(tester, shells, output: 'ok\r\n', exit: 0);
      expect(find.text('exit 0'), findsOne);
      expect(find.text('ok'), findsOne);
      await expectLater(
        find.byKey(const Key('view')),
        matchesGoldenFile('goldens/code_run_ended_$name.png'),
      );
      await _end(tester, d);
    });
  }

  testWidgets('>_ opens the terminal panel on the run’s tab', (tester) async {
    final (shells, d, _) = await _view(tester);
    await _runIt(tester, shells, output: 'ok\r\n', exit: 0);
    d.terminals.active['c'] = 'other';
    expect(terminalChats.value, isNot(contains('c')));
    await tester.tap(find.byTooltip('Show in the terminal'));
    await tester.pump();
    expect(terminalChats.value, contains('c'));
    expect(d.terminals.active['c'], 'a');
    await _end(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('its output in the box at its end, sent with the next '
        'message; ✕ drops it, a run again replaces it, $name', (tester) async {
      final (shells, d, chat) = await _view(tester, tokens: tokens, box: true);
      final card = find.byType(OutputCard);
      await _runIt(tester, shells, output: 'one\r\n');
      expect(card, findsNothing, reason: 'not while it runs');
      shells.write('a', 'two\r\n\x1b]133;D;0\x1b\\$_prompt');
      await _settle(tester);
      expect(card, findsOne);
      expect(
        [
          for (final t in tester.widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          ))
            t.data,
        ].join(),
        'Output of python3 -m tennis.server · exit 0 · 2 lines',
      );
      await tester.pumpAndSettle(); // the box's line grown in
      await expectLater(
        find.byKey(const Key('view')),
        matchesGoldenFile('goldens/code_run_card_$name.png'),
      );

      await _runIt(tester, shells, output: 'three\r\n', exit: 1);
      expect(chat.draft.outputs.value.single.text, 'three');
      expect(card, findsOne);

      await tester.enterText(find.byType(TextField), 'Why did it fail?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send\u2002⏎'));
      await _settle(tester);
      final fake = shells.fake;
      expect(
        fake.calls.whereType<SendPromptRequest>().single.text,
        'Why did it fail?\n\n'
        'Output of `python3 -m tennis.server` (exit 1):\n\n'
        '```\nthree\n```',
      );
      expect(chat.draft.outputs.value, isEmpty);
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      await _runIt(tester, shells, output: 'four\r\n', exit: 0);
      await tester.pumpAndSettle(); // the box's line grown in
      expect(card, findsOne);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(card));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove'));
      expect(chat.draft.outputs.value, isEmpty);
      await tester.pumpAndSettle(); // the line folded away
      expect(card, findsNothing);
      await _end(tester, d);
    });
  }

  test('outputs are kept by block', () {
    final runs = CodeRuns('c', ValueNotifier(const []));
    expect(identical(runs.of('ls'), runs.of('ls')), isTrue);
    runs.dispose();
  });
}
