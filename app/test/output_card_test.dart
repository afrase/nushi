// A command's card over the box, typed after `!`: running (the spinner,
// Show and ✕), done (its exit and lines), failed (unmistakably: a mark,
// its exit in red, on the failed fill), its output a click away; ✕ stops
// it and drops it, and the done ones go with the next message.
//
// The tags meet their text with no space between, as sent.
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/output_card.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

typedef _View = (FakeShells, Daemon, ChatState);

Future<_View> _view(WidgetTester tester, {Tokens tokens = Tokens.dark}) async {
  final fake = FakeDaemon([]);
  final shells = FakeShells(fake)
    ..commands['git status --short'] = (
      output: ' M app/lib/run_text.dart\r\n',
      exit: 0,
    )
    ..commands['make lint-dart'] = (
      output: 'run_text.dart:12:3: missing a doc comment\r\n1 issue\r\n',
      exit: 2,
    );
  addTearDown(shells.close);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  d.chats['c'] = chat;
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.bottomLeft,
        child: RepaintBoundary(
          key: const Key('view'),
          child: Container(
            width: 640,
            color: tokens.base,
            padding: const EdgeInsets.all(12),
            child: ListenableBuilder(
              listenable: chat,
              builder: (context, _) => Composer(chat: chat, daemon: d),
            ),
          ),
        ),
      ),
      tokens: tokens,
    ),
  );
  await tester.pump();
  return (shells, d, chat);
}

Future<void> _settle(WidgetTester tester) => frames(tester, 10);

Future<CodeRun> _run(
  WidgetTester tester,
  ChatState chat,
  Daemon d,
  String c,
) async {
  final run = await chat.runs.command(d.terminals, c);
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 400)); // grown in
  return run;
}

String _words(WidgetTester tester, Finder card) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  ))
    t.data,
].join();

Future<void> _end(WidgetTester tester, Daemon d) async {
  await closeView(tester, d);
  await tester.pump(const Duration(seconds: 2)); // a tooltip's timers
}

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('running, done and failed, $name', (tester) async {
      final (_, d, chat) = await _view(tester, tokens: tokens);
      final running = await _run(tester, chat, d, 'npm run dev');
      await _run(tester, chat, d, 'git status --short');
      await _run(tester, chat, d, 'make lint-dart');
      await tester.pump(const Duration(milliseconds: 400)); // grown in
      final cards = find.byType(OutputCard);
      expect(cards, findsNWidgets(3));
      expect(
        find.descendant(of: cards.at(0), matching: find.byType(Spinner)),
        findsOne,
      );
      expect(running.state, RunState.running);
      expect(_words(tester, cards.at(0)), '! npm run dev');
      expect(
        _words(tester, cards.at(1)),
        '! git status --short · exit 0 · 1 line',
      );
      expect(
        _words(tester, cards.at(2)),
        '! make lint-dart · exit 2 · 2 lines',
      );
      final failed = tester.widget<Container>(
        find.byKey(ValueKey('output-${chat.draft.outputs.value[2].key}')),
      );
      expect((failed.decoration! as BoxDecoration).color, tokens.crashedSoft);
      expect(
        find.descendant(of: cards.at(2), matching: find.byIcon(Icons.error)),
        findsOne,
      );
      await expectLater(
        find.byKey(const Key('view')),
        matchesGoldenFile('goldens/command_cards_$name.png'),
      );
      await _end(tester, d);
    });
  }

  testWidgets('✕ stops a running one and drops it; Show opens its terminal', (
    tester,
  ) async {
    final (shells, d, chat) = await _view(tester);
    final run = await _run(tester, chat, d, 'npm run dev');
    expect(terminalChats.value, isNot(contains('c')));
    await tester.tap(find.byTooltip('Show in the terminal'));
    await tester.pump();
    expect(terminalChats.value, contains('c'));
    expect(d.terminals.active['c'], run.terminalId);
    expect(run.shown, isTrue);
    await tester.tap(find.byTooltip('Stop'));
    await _settle(tester);
    expect(shells.typed[run.terminalId], ['\x03']);
    expect(chat.draft.outputs.value, isEmpty);
    await tester.pump(const Duration(milliseconds: 400)); // folded away
    expect(find.byType(OutputCard), findsNothing);
    await _end(tester, d);
  });

  testWidgets('a done one shows its output; it goes with the message, a '
      'running one stays', (tester) async {
    final (shells, d, chat) = await _view(tester);
    await _run(tester, chat, d, 'make lint-dart');
    await _run(tester, chat, d, 'sleep 60');
    await tester.tap(find.textContaining('make lint-dart'));
    await tester.pumpAndSettle();
    expect(find.text('Output'), findsOne);
    expect(
      find.text('run_text.dart:12:3: missing a doc comment\n1 issue'),
      findsOne,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Fix it');
    await tester.pump();
    await tester.tap(find.byTooltip('Send ⏎'));
    await _settle(tester);
    expect(
      shells.fake.calls.whereType<SendPromptRequest>().single.text,
      'Fix it\n\n<bash-input>make lint-dart</bash-input>\n'
      '<bash-stdout>run_text.dart:12:3: missing a doc comment\n1 issue'
      '</bash-stdout><bash-stderr></bash-stderr>'
      '<bash-exit-code>2</bash-exit-code>',
    );
    expect(find.byType(OutputCard), findsOne, reason: 'sleep 60 still runs');
    await _end(tester, d);
  });

  for (final (width, b) in [
    (1700.0, Brightness.dark),
    if (rendering) (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    if (rendering) (720.0, Brightness.light),
  ]) {
    testWidgets('the window, $width wide, ${b.name}', (tester) async {
      showDetails.value = false;
      final c = chat('c', 'claude', 'Why the check fails');
      final fake = FakeDaemon([c]);
      final shells = FakeShells(fake)
        ..commands['git status --short'] = (
          output: ' M app/lib/run_text.dart\r\n',
          exit: 0,
        )
        ..commands['make lint-dart'] = (output: '1 issue\r\n', exit: 2);
      addTearDown(shells.close);
      final d = await openApp(
        tester,
        fake,
        size: Size(width, 900),
        brightness: b,
      );
      final state = d.chats['c']!;
      for (final cmd in [
        'npm run dev',
        'git status --short',
        'make lint-dart',
      ]) {
        await state.runs.command(d.terminals, cmd);
        await _settle(tester);
      }
      // A ▷ run's, beside them.
      state.draft.outputs.value = [
        ...state.draft.outputs.value,
        (
          key: 'k',
          command: 'make check',
          exit: 2,
          lines: 42,
          text: 'FAIL',
          run: null,
        ),
      ];
      state.draft.text.text = 'Why does the lint fail?';
      // The row the last card wraps to eases in: one frame starts it,
      // the next ends it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(OutputCard).last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(EditableText)).top),
      );
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'command_cards_${width.toInt()}_${b.name}',
      );
      await closeView(tester, d);
      await tester.pump(const Duration(seconds: 2));
    }, variant: onMac);
  }
}
