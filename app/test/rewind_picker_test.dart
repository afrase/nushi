import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A user message sent [minutes] ago, rewindable.
Item _message(String id, String text, int minutes) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: text,
  rewindable: true,
  sent: Int64(
    fixtureNow
        .subtract(Duration(minutes: minutes, seconds: 5))
        .millisecondsSinceEpoch,
  ),
);

/// A Claude chat of three turns that can be rewound.
ChatState _chat() => ChatState('c', '/tmp')
  ..agent = 'claude'
  ..canRewind = true
  ..items.addAll([
    _message('u1', 'Add a rewind picker', 42),
    Item(id: 'a1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done.'),
    _message('u2', 'Make Esc Esc open it\nwith a second line', 12),
    Item(id: 'a2', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done.'),
    _message('u3', 'Now the golden', 2),
  ]);

/// The composer on [chat] in a 1200×700 window, a fake daemon behind it
/// whose rewinds are kept (the list returned).
Future<(Daemon, List<RewindChatRequest>)> _box(
  WidgetTester tester,
  ChatState chat,
) async {
  viewport(tester, const Size(1200, 700));
  final rewound = <RewindChatRequest>[];
  final fake = FakeDaemon([])
    ..answer = (input) {
      if (input is! RewindChatRequest) return null;
      rewound.add(input);
      final it = chat.items.firstWhere((it) => it.id == input.itemId);
      return RewindChatResponse(message: QueuedMessage(text: it.text));
    };
  final daemon = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.light).toThemeData(),
      darkTheme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            Composer(chat: chat, daemon: daemon),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return (daemon, rewound);
}

Future<void> _esc(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _done(WidgetTester tester, Daemon daemon) async {
  await tester.pump(escEscWithin); // a first Esc's timer
  daemon.dispose();
  await tester.pump(const Duration(seconds: 4)); // the ping's timeout
}

void main() {
  setUpAll(loadFonts);

  testWidgets('Esc Esc opens the picker, newest first', (tester) async {
    final (daemon, _) = await _box(tester, _chat());
    await _esc(tester);
    await _esc(tester);
    await tester.pumpAndSettle();
    expect(find.byType(RewindPicker), findsOne);
    final lines = [
      'Now the golden',
      'Make Esc Esc open it',
      'Add a rewind picker',
    ];
    final ys = [for (final l in lines) tester.getTopLeft(find.text(l)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('12m ago'), findsOne);
    expect(
      find.text('Files aren’t rewound: Claude’s changes since then stay.'),
      findsOne,
    );
    await _done(tester, daemon);
  });

  testWidgets('a single Esc, or two too far apart, does not', (tester) async {
    final (daemon, _) = await _box(tester, _chat());
    await _esc(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RewindPicker), findsNothing);
    await _esc(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RewindPicker), findsNothing);
    await _done(tester, daemon);
  });

  testWidgets('Esc Esc with a completion list open only closes it', (
    tester,
  ) async {
    final chat = _chat()..commands = [Command(name: 'review')];
    final (daemon, _) = await _box(tester, chat);
    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();
    expect(find.text('/review'), findsOne);
    await _esc(tester);
    await _esc(tester);
    await tester.pumpAndSettle();
    expect(find.text('/review'), findsNothing);
    expect(find.byType(RewindPicker), findsNothing);
    await _done(tester, daemon);
  });

  testWidgets('picking rewinds and fills the box, without asking again', (
    tester,
  ) async {
    final chat = _chat();
    final (daemon, rewound) = await _box(tester, chat);
    await _esc(tester);
    await _esc(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(RewindPicker),
        matching: find.byType(TextField),
      ),
      'esc',
    );
    await tester.pump();
    expect(find.text('Now the golden'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RewindPicker), findsNothing);
    expect(find.text('Rewind to here?'), findsNothing);
    expect(rewound.single.itemId, 'u2');
    expect(chat.draft.text.text, 'Make Esc Esc open it\nwith a second line');
    await _done(tester, daemon);
  });

  testWidgets('while a turn runs it says to stop it first', (tester) async {
    final chat = _chat()..busy = true;
    final (daemon, _) = await _box(tester, chat);
    await _esc(tester);
    await _esc(tester);
    await tester.pumpAndSettle();
    expect(find.text('Stop the turn first'), findsOne);
    expect(find.text('Now the golden'), findsNothing);
    // Once it has stopped, the messages show.
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Now the golden'), findsOne);
    await _done(tester, daemon);
  });

  testWidgets('golden: the rewind picker, dark', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final (daemon, _) = await _box(tester, _chat());
    await _esc(tester);
    await _esc(tester);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/rewind_picker_dark.png'),
    );
    await _done(tester, daemon);
  });
}
