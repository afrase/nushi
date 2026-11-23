import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/command_mode.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/output_card.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spell_check.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';
import 'spell_harness.dart' show FakeSpeller, flagged;
import 'theme_sets.dart';

// Command mode (ADR 0148): a box whose text starts with "!" runs the rest
// in a terminal of the chat's, its card over the box, rather than sending
// it; the desktop app's only.

typedef _Box = (FakeDaemon, FakeShells, Daemon, ChatState);

/// The composer of a chat in /Users/me/nushi, at the foot of the window;
/// [phone] puts it on a touch screen; [commands] false is a side chat's.
Future<_Box> _box(
  WidgetTester tester, {
  bool phone = false,
  bool commands = true,
}) async {
  final fake = FakeDaemon([]);
  final shells = FakeShells(fake)
    ..commands['git status'] = (output: 'clean\r\n', exit: 0);
  addTearDown(shells.close);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  d.chats['c'] = chat;
  viewport(tester, const Size(900, 400));
  Widget box = Column(
    children: [
      const Spacer(),
      ListenableBuilder(
        listenable: chat,
        builder: (context, _) =>
            Composer(chat: chat, daemon: d, commands: commands),
      ),
    ],
  );
  if (phone) box = TouchTargets(child: box);
  await tester.pumpWidget(themed(box));
  await tester.pump();
  return (fake, shells, d, chat);
}

Finder get _field => find.byType(TextField);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

/// Lets the calls and the terminal's stream through.
Future<void> _settle(WidgetTester tester) => frames(tester, 10);

Future<void> _end(WidgetTester tester, Daemon d) async {
  await closeView(tester, d);
  await tester.pump(const Duration(seconds: 2)); // a session's retry
}

bool _inCommandMode(WidgetTester tester) =>
    find.byType(CommandMark).evaluate().isNotEmpty;

void main() {
  setUpAll(loadFonts);

  test("command mode's ring keeps 3:1 on its fill in every set", () {
    for (final (name, t) in everySet) {
      final ring = commandBoxLook(t).ring as BoxDecoration;
      final line = (ring.border! as Border).top.color;
      final (a, b) = (line.computeLuminance(), t.codeBlock.computeLuminance());
      final ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05);
      expect(ratio, greaterThanOrEqualTo(3), reason: name);
    }
  });

  testWidgets('a "!" first puts the box in command mode, its look over '
      'the same box, and taking it away leaves it', (tester) async {
    final (_, _, d, chat) = await _box(tester);
    await _type(tester, 'git status');
    final box = tester.getRect(find.byType(Composer));
    final text = tester.getRect(_field);
    expect(_inCommandMode(tester), isFalse);
    expect(find.byTooltip(withKey('Send', '⏎')), findsOneWidget);

    await _type(tester, '!git status');
    await tester.pumpAndSettle();
    expect(_inCommandMode(tester), isTrue);
    expect(chat.draft.text.commandMode, isTrue);
    expect(find.byTooltip(withKey('Run', '⏎')), findsOneWidget);
    expect(find.byTooltip(withKey('Send', '⏎')), findsNothing);
    expect(find.text('Runs in nushi'), findsOneWidget);
    expect(tester.getRect(find.byType(Composer)), box, reason: 'nothing moves');
    expect(tester.getRect(_field), text);

    await _type(tester, 'git status');
    await tester.pumpAndSettle();
    expect(_inCommandMode(tester), isFalse);
    expect(find.text('Runs in nushi'), findsNothing);

    await _type(tester, ' !git status');
    expect(_inCommandMode(tester), isFalse, reason: 'a space first: a message');
    await _end(tester, d);
  }, variant: onMac);

  for (final lines in [false, true]) {
    testWidgets('the send key runs it, with "Enter starts a new line" '
        '${lines ? 'on' : 'off'}; the box empties and its card shows', (
      tester,
    ) async {
      enterStartsLine.value = lines;
      final (fake, shells, d, chat) = await _box(tester);
      await _type(tester, '!git status');
      if (lines) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(shells.opened, isEmpty, reason: 'Enter starts a line');
        expect(chat.draft.text.text, '!git status\n');
        await press(tester, LogicalKeyboardKey.enter, cmd: true, settle: false);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }
      await _settle(tester);
      expect(shells.opened, ['git status']);
      expect(chat.draft.text.text, isEmpty);
      expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OutputCard), findsOneWidget);
      await _end(tester, d);
    }, variant: onMac);
  }

  testWidgets('Run runs it too; an empty command runs nothing', (tester) async {
    final (fake, shells, d, chat) = await _box(tester);
    for (final empty in ['!', '!   ']) {
      await _type(tester, empty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(shells.opened, isEmpty);
      expect(chat.draft.text.text, empty, reason: 'it stays in the box');
      final run = tester.widget<RoundButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(RoundButton),
        ),
      );
      expect(run.onPressed, isNull, reason: 'Run is off');
    }
    await _type(tester, '!git status');
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    expect(shells.opened, ['git status']);
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('other cards and files stay for the next message', (
    tester,
  ) async {
    final (_, shells, d, chat) = await _box(tester);
    chat.draft
      ..addReply((quote: 'q', text: 'Look at this', from: 'Ann'))
      ..files.value = [AttachedFile.at('/Users/me/nushi/notes.txt')];
    await _type(tester, '!git status');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(shells.opened, ['git status']);
    expect(chat.draft.replies.value, hasLength(1));
    expect(chat.draft.files.value, hasLength(1));
    expect(chat.draft.outputs.value, hasLength(1));
    await _end(tester, d);
  }, variant: onMac);

  testWidgets("while the agent works it runs at once, Run in Queue's "
      'place and Stop kept', (tester) async {
    final (fake, shells, d, chat) = await _box(tester);
    chat
      ..busy = true
      ..started = clock()
      ..notifyListeners();
    await _type(tester, '!git status');
    await tester.pumpAndSettle();
    expect(find.byTooltip(withKey('Queue', '⏎')), findsNothing);
    expect(find.byTooltip(withKey('Run', '⏎')), findsOneWidget);
    expect(find.byTooltip(withKey('Stop', 'Esc')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(shells.opened, ['git status']);
    expect(
      fake.calls.whereType<SendPromptRequest>(),
      isEmpty,
      reason:
          'no '
          'queued message',
    );
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('with a daemon too old for commands the box says so and '
      'runs nothing, nor sends it', (tester) async {
    final (fake, shells, d, chat) = await _box(tester);
    d.daemonApi = commandTerminalApi - 1;
    await _type(tester, '!git status');
    await tester.pumpAndSettle();
    expect(find.text('Running commands needs a newer daemon'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(shells.opened, isEmpty);
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    expect(chat.draft.text.text, '!git status');
    await tester.pump(const Duration(seconds: 5)); // the toast
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('on the phone "!x" is a message, as before', (tester) async {
    final (fake, shells, d, _) = await _box(tester, phone: true);
    await _type(tester, '!git status');
    await tester.pumpAndSettle();
    expect(_inCommandMode(tester), isFalse);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(shells.opened, isEmpty);
    expect(
      fake.calls.whereType<SendPromptRequest>().single.text,
      '!git status',
    );
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('a message starting with "!" put back is still a message', (
    tester,
  ) async {
    final (fake, shells, d, chat) = await _box(tester);
    chat.takeBack.value = QueuedMessage(text: '!rm -rf build');
    await tester.pumpAndSettle();
    expect(chat.draft.text.text, ' !rm -rf build');
    expect(_inCommandMode(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(shells.opened, isEmpty);
    expect(
      fake.calls.whereType<SendPromptRequest>().single.text,
      '!rm -rf build',
    );
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('a chat without a folder runs in a scratch folder, so the '
      'box says', (tester) async {
    final (_, _, d, chat) = await _box(tester);
    chat.scratch = true;
    await _type(tester, '!ls');
    await tester.pumpAndSettle();
    expect(find.text('Runs in a scratch folder'), findsOne);
    expect(find.textContaining('Runs in nushi'), findsNothing);
    await _end(tester, d);
  }, variant: onMac);

  testWidgets("a side chat's box has no command mode", (tester) async {
    final (fake, shells, d, _) = await _box(tester, commands: false);
    await _type(tester, '!git status');
    await tester.pumpAndSettle();
    expect(_inCommandMode(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(shells.opened, isEmpty);
    expect(
      fake.calls.whereType<SendPromptRequest>().single.text,
      '!git status',
    );
    await _end(tester, d);
  }, variant: onMac);

  testWidgets('no completions and no spelling marks in command mode', (
    tester,
  ) async {
    native.speller = FakeSpeller({'chekc'});
    final (_, _, d, chat) = await _box(tester);
    await _type(tester, '!echo chekc @');
    await tester.pump(spellPause);
    await tester.pump();
    expect(flagged(chat), isEmpty);
    expect(find.byType(ChoiceList), findsNothing);
    await _type(tester, 'echo chekc');
    await tester.pump(spellPause);
    await tester.pump();
    expect(flagged(chat), ['chekc'], reason: 'out of it, checked again');
    await _type(tester, '/');
    await tester.pump();
    expect(find.byType(ChoiceList), findsOneWidget);
    await _end(tester, d);
  }, variant: onMac);
}
