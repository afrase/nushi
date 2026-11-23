// A sent message's commands, in its bubble: each a card (the command, its
// exit, its output folded), read back from the tags it went with, Claude
// Code's own two messages of a `!` too; messages from before show as they
// did.
//
// The messages' tags meet their text with no space between, as sent.
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/sent_commands.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _sent =
    'Why does the check fail?\n\n'
    '<bash-input>git status --short</bash-input>\n'
    '<bash-stdout> M app/lib/run_text.dart\n?? app/lib/sent_commands.dart'
    '</bash-stdout><bash-stderr></bash-stderr>'
    '<bash-exit-code>0</bash-exit-code>\n\n'
    '<bash-input>make lint-dart</bash-input>\n'
    '<bash-stdout>app/lib/run_text.dart:12:3: missing a doc comment\n'
    'lint-dart: 1 issue</bash-stdout><bash-stderr></bash-stderr>'
    '<bash-exit-code>2</bash-exit-code>';

final _items = <Item>[
  Item(id: 'u1', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: _sent),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        'The lint wants a doc comment on `keptOutput`; `run_text.dart` '
        'line 12. I can add one.',
  ),
  // Claude Code's own, from a terminal session that ran `! ls`.
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: '<bash-input>ls app</bash-input>',
  ),
  Item(
    id: 'u3',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        '<bash-stdout>lib\npubspec.yaml\ntest</bash-stdout>'
        '<bash-stderr></bash-stderr>',
  ),
  Item(
    id: 'm2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'That is the Flutter app: its code, its packages and its tests.',
  ),
];

Future<void> _show(WidgetTester tester, String message) async {
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 600, child: UserMessageText(message)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('each command a card, its output folded until clicked', (
    tester,
  ) async {
    await _show(tester, _sent);
    expect(find.text('Why does the check fail?'), findsOne);
    expect(find.byType(SentCommandCard), findsNWidgets(2));
    expect(find.textContaining('<bash-'), findsNothing);
    expect(find.text('exit 0'), findsOne);
    expect(
      find.widgetWithText(NotePill, 'exit 2'),
      findsOne,
      reason: 'a failed exit is a red pill',
    );
    expect(find.textContaining('lint-dart: 1 issue'), findsNothing);
    await tester.tap(find.byTooltip('Show its output').last);
    await tester.pump();
    expect(find.textContaining('lint-dart: 1 issue'), findsOne);
    await tester.tap(find.byTooltip('Hide its output'));
    await tester.pump();
    expect(find.textContaining('lint-dart: 1 issue'), findsNothing);
  });

  testWidgets("Claude Code's two messages: the command, then its output", (
    tester,
  ) async {
    await _show(tester, '<bash-input>ls app</bash-input>');
    expect(find.byType(SentCommandCard), findsOne);
    expect(find.byTooltip('Show its output'), findsNothing);
    expect(find.textContaining('ls app'), findsOne);
    await _show(
      tester,
      '<bash-stdout>lib</bash-stdout><bash-stderr>oops</bash-stderr>',
    );
    expect(find.text('Output'), findsOne);
    await tester.tap(find.byTooltip('Show its output'));
    await tester.pump();
    expect(find.text('lib\noops'), findsOne);
  });

  testWidgets('a message from before is as it was', (tester) async {
    const old = 'Why?\n\nOutput of `ls` (exit 0):\n\n```\na.txt\n```';
    await _show(tester, old);
    expect(find.byType(SentCommandCard), findsNothing);
    expect(find.textContaining('a.txt'), findsOne);
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
      final fake = FakeDaemon([c])
        ..answer = ((input) => input is GetChatRequest
            ? GetChatResponse(chat: c, items: _items)
            : null);
      final d = await openApp(
        tester,
        fake,
        size: Size(width, 900),
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      final name = 'sent_commands_${width.toInt()}_${b.name}';
      await render(tester, find.byType(NushiApp), name);
      final open = find.byTooltip('Show its output');
      if (open.evaluate().isNotEmpty) {
        await tester.tap(open.at(1));
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), '${name}_open');
      }
      await closeView(tester, d);
    }, variant: onMac);
  }
}
