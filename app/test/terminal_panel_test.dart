import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminals.dart';

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

Future<void> _meta(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

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

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB); // Option as Meta
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), 'l\x1bb');

    await _meta(tester, LogicalKeyboardKey.keyF); // find in the scrollback
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), r'$');
    await tester.pump();
    expect(find.text('1 of 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);

    // ⌥⌘1 the first terminal (⌘1 is the first chat's).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await _meta(tester, LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(terms.active['chat'], 'a');
    await _meta(tester, LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(fake.calls, contains(isA<OpenTerminalRequest>()));
    expect(terms.active['chat'], 'new0');
    await _meta(tester, LogicalKeyboardKey.keyW);
    expect(fake.calls.last, isA<CloseTerminalRequest>());
    expect(shells.typedAll.join(), 'l\x1bb'); // none of those reached the shell

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(hidden, isTrue);
  });

  testWidgets('⌘F in a terminal starts at the latest match; ⏎ goes down '
      '(round to the first), ⇧⏎ up', (tester) async {
    final (fake, shells) = _daemon(replay: 'one x\r\ntwo x\r\nthree x\r\n\$ ');
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    await _meta(tester, LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(find.text('3 of 3'), findsOne);
    for (final w in [1700.0, 720.0]) {
      viewport(tester, Size(w, 500));
      await tester.pumpAndSettle();
      await render(
        tester,
        find.byType(TerminalPanel),
        'terminal_find_${w.toInt()}',
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('1 of 3'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('2 of 3'), findsOne);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('1 of 3'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL); // the shell's again
    await tester.pumpAndSettle();
    expect(shells.typedAll.join(), 'l');
  });

  // fish waits 10 seconds for an answer to the query it starts with.
  testWidgets('only a shell opened here gets answers to its replayed queries', (
    tester,
  ) async {
    final (fake, shells) = _daemon(replay: '\x1b[c\$ ');
    final terms = Terminals(NushiServiceClient(fake));
    await _panel(tester, terms);
    expect(shells.typedAll, isEmpty); // answered when it was opened
    await _meta(tester, LogicalKeyboardKey.keyT);
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
}
