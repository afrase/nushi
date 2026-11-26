import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/transcript_find.dart';
import 'package:xterm2/xterm.dart' show TerminalView;

import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'fake_shells.dart';
import 'harness.dart';

/// Two terminals of the chat on a fake daemon, each first showing
/// [replay], and [live] after it once attached; a new one shows [replay].
(FakeDaemon, FakeShells) _daemon({String replay = r'$ ', String? live}) {
  final fake = FakeDaemon([]);
  final shells = FakeShells(fake, terminals: [_term('a'), _term('b')])
    ..newReplay = replay
    ..replay.addAll({'a': replay, 'b': replay});
  if (live != null) shells.onAttach.addAll({'a': live, 'b': live});
  return (fake, shells);
}

Terminal _term(String id) =>
    Terminal(id: id, chatId: 'chat', folder: '/tmp/veg', shell: 'zsh');

Future<void> _panel(
  WidgetTester tester,
  Terminals terms, {
  VoidCallback? onHide,
}) async {
  await tester.pumpWidget(
    themed(
      TerminalPanel(
        chatId: 'chat',
        terms: terms,
        onHide: onHide ?? () {},
        showChange: (_) async => false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('tabs, and the keys the panel keeps from the shell', (
    tester,
  ) async {
    final (fake, shells) = _daemon();
    final terms = Terminals(NushiServiceClient(fake));
    var hidden = false;
    await _panel(tester, terms, onHide: () => hidden = true);
    expect(find.text('zsh — veg'), findsNWidgets(2));
    expect(terms.active['chat'], 'b'); // the last one shows
    expect(terms.looked, {'b'}, reason: 'seen in the open panel');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB); // Option as Meta
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), 'l\x1bb');

    await press(
      tester,
      LogicalKeyboardKey.keyF,
      cmd: true,
      settle: false,
    ); // find in the scrollback
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), r'$');
    await tester.pump();
    expect(find.text('1 of 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);

    // ⌥⌘1 the first terminal (⌘1 is the first chat's).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await press(tester, LogicalKeyboardKey.digit1, cmd: true, settle: false);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(terms.active['chat'], 'a');
    await press(tester, LogicalKeyboardKey.keyT, cmd: true, settle: false);
    await tester.pumpAndSettle();
    expect(fake.calls, contains(isA<OpenTerminalRequest>()));
    expect(terms.active['chat'], 'new0');
    await press(tester, LogicalKeyboardKey.keyW, cmd: true, settle: false);
    expect(fake.calls.last, isA<CloseTerminalRequest>());
    expect(shells.typedAll.join(), 'l\x1bb'); // none of those reached the shell

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(hidden, isTrue);
  });

  testWidgets('⌘F in a terminal reads newest first, as a chat: the latest '
      'match is 1, ⏎ goes up to older output (round to the latest), ⇧⏎ '
      'down', (tester) async {
    final (fake, shells) = _daemon(replay: 'one x\r\ntwo x\r\nthree x\r\n\$ ');
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    await press(tester, LogicalKeyboardKey.keyF, cmd: true, settle: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(find.text('1 of 3'), findsOne, reason: 'the latest, counted 1');
    // The arrows go up and down the scrollback, their words the chat's.
    Finder arrow(IconData icon) =>
        find.descendant(of: find.byType(FindBar), matching: find.byIcon(icon));
    final (up, down) = (
      arrow(Icons.keyboard_arrow_up),
      arrow(Icons.keyboard_arrow_down),
    );
    String tip(Finder arrow) => tester
        .widget<IconTap>(
          find.ancestor(of: arrow, matching: find.byType(IconTap)).first,
        )
        .tooltip;
    expect(tip(up), 'Older match\u2002⏎');
    expect(tip(down), 'Newer match\u2002⇧⏎');
    for (final w in [1700.0, 720.0]) {
      viewport(tester, Size(w, 500));
      await tester.pumpAndSettle();
      await render(
        tester,
        find.byType(TerminalPanel),
        'terminal_find_${w.toInt()}',
      );
    }
    for (final count in ['2 of 3', '3 of 3', '1 of 3']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text(count), findsOne, reason: '⏎ goes older, round');
    }
    await press(tester, LogicalKeyboardKey.enter, shift: true, settle: false);
    expect(find.text('3 of 3'), findsOne, reason: '⇧⏎ from the latest, round');
    await press(tester, LogicalKeyboardKey.enter, shift: true, settle: false);
    expect(find.text('2 of 3'), findsOne, reason: '⇧⏎ goes newer');
    await tester.tap(up);
    await tester.pump();
    expect(find.text('3 of 3'), findsOne, reason: 'the up arrow goes up');
    await tester.tap(down);
    await tester.pump();
    expect(find.text('2 of 3'), findsOne, reason: 'the down arrow goes down');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL); // the shell's again
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), 'l');
  });

  // A terminal's program as the app last heard it can lag: one that took
  // the foreground silently isn't in it. Closing asks the daemon afresh
  // (ListTerminals reads the foreground live) and decides on its answer.
  testWidgets('closing a terminal the app thinks idle asks first when the '
      "daemon's fresh answer has a program running", (tester) async {
    final (fake, shells) = _daemon();
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    expect(terms.of('chat')!.last.program, isEmpty);
    shells.list[1] = shells.list[1].deepCopy()..program = 'quiet-server';
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(find.text('Close this terminal?'), findsOne);
    expect(
      find.text(
        '“quiet-server” is still running in it. Closing the terminal ends it.',
      ),
      findsOne,
    );
    expect(shells.closed, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(shells.closed, isEmpty);
  });

  testWidgets("closing a terminal the daemon's fresh answer agrees is idle "
      'asks it once more and closes it unasked', (tester) async {
    final (fake, shells) = _daemon();
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    final listed = fake.calls.whereType<ListTerminalsRequest>().length;
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(find.text('Close this terminal?'), findsNothing);
    expect(shells.closed, ['b']);
    expect(fake.calls.whereType<ListTerminalsRequest>().length, listed + 1);
  });

  testWidgets("closing a terminal when the daemon can't be asked goes on "
      'from what the app knew, saying nothing new', (tester) async {
    final (fake, shells) = _daemon();
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    fake.on(
      (input) => input is ListTerminalsRequest
          ? throw ConnectException(Code.unavailable, 'gone')
          : null,
    );
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(find.text('Close this terminal?'), findsNothing);
    expect(find.textContaining('gone'), findsNothing);
    expect(shells.closed, ['b']);
  });

  // fish waits 10 seconds for an answer to the query it starts with.
  testWidgets('only a shell opened here gets answers to its replayed queries', (
    tester,
  ) async {
    final (fake, shells) = _daemon(replay: '\x1b[c\$ ');
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    expect(shells.typedAll, isEmpty); // answered when it was opened
    await press(tester, LogicalKeyboardKey.keyT, cmd: true, settle: false);
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), startsWith('\x1b[?'));
  });

  testWidgets('a query after an empty replay is live, and answered', (
    tester,
  ) async {
    final (fake, shells) = _daemon(replay: '', live: '\x1b[c');
    await _panel(tester, Terminals(NushiServiceClient(fake)));
    expect(shells.typedAll.join(), startsWith('\x1b[?'));
  });

  testWidgets("output can't have its title typed at the prompt", (
    tester,
  ) async {
    final (fake, shells) = _daemon(
      live: '\x1b]2;s; echo hi #\x07\x1b[21t\x1b[20t',
    );
    await _panel(tester, Terminals(NushiServiceClient(fake)));
    expect(shells.typedAll.join(), isNot(contains('echo hi')));
  });

  testWidgets("output can't read the clipboard (OSC 52)", (tester) async {
    final asked = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        asked.add(call.method);
        return call.method == 'Clipboard.getData' ? {'text': 'hunter2'} : null;
      },
    );
    final (fake, shells) = _daemon(live: '\x1b]52;c;?\x07');
    await _panel(tester, Terminals(NushiServiceClient(fake)));
    // Focused, as a terminal is when output reaches it while it's used.
    await tester.tap(find.byType(TerminalView).last);
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), isNot(contains('52;')));
    expect(asked, isNot(contains('Clipboard.getData')));
  });
}
