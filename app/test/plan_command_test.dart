import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Claude's /plan, which the daemon runs in claude's place (claude refuses
// it headless) and lists with claude's own commands.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// /plan as the daemon lists it in a Claude chat (internal/claude).
final _plan = Command(
  name: 'plan',
  description: 'Switch to plan mode; with a description, start planning it',
  hint: '[description]',
);

/// The box of an idle Claude chat with claude's /compact and the daemon's
/// /plan; the daemon says it ran each prompt that starts with /plan.
Future<(FakeDaemon, Daemon, ChatState)> _box(WidgetTester tester) async {
  final fake = FakeDaemon([])
    ..answer = (input) => input is SendPromptRequest
        ? SendPromptResponse(ranCommand: input.text.startsWith('/plan'))
        : null;
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/x')
    ..agent = 'claude'
    ..loaded = true
    ..commands = [Command(name: 'compact', description: 'Compact'), _plan];
  d.chats['c'] = chat;
  await tester.pumpWidget(themed(Composer(chat: chat, daemon: d)));
  await tester.pump();
  return (fake, d, chat);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('/plan is offered with its description, and picked', (
    tester,
  ) async {
    final (_, d, _) = await _box(tester);
    await tester.enterText(find.byType(TextField), '/pl');
    await tester.pump();
    expect(find.textContaining('/plan', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Switch to plan mode', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('/compact', findRichText: true), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '/plan ',
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('a /plan the daemon ran leaves no message waiting for its echo', (
    tester,
  ) async {
    final (fake, d, chat) = await _box(tester);
    await tester.enterText(find.byType(TextField), '/plan');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // the choices
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fake.calls.whereType<SendPromptRequest>().single.text, '/plan');
    expect(chat.outbox.sending, isEmpty);

    // Any other message waits for its echo, as before.
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(chat.outbox.sending.map((it) => it.text), ['hello']);
    d.dispose();
  }, variant: _mac);

  // What /plan leaves in the transcript, as the daemon sends it: its notice
  // line, muted as the agent's own notices, then the description it sent.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final width in [720.0, 1700.0]) {
      testWidgets("/plan's notices (${width.round()}, $name)", (tester) async {
        viewport(tester, Size(width, 200));
        final chat = ChatState('c', '/x')..agent = 'claude';
        final d = await FakeDaemon([]).connect(tester);
        final items = [
          Item(
            id: 'item-1',
            kind: ItemKind.ITEM_KIND_NOTICE,
            status: 'command',
            text: 'Enabled plan mode',
          ),
          Item(
            id: 'item-2',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Add a dark theme',
          ),
          Item(
            id: 'item-3',
            kind: ItemKind.ITEM_KIND_NOTICE,
            status: 'command',
            text: 'Already in plan mode.',
          ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (final it in items)
                      ItemView(it, chat, d, live: false, still: false),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Enabled plan mode'), findsOneWidget);
        final icons = tester.widgetList<Icon>(find.byIcon(Icons.info_outline));
        expect(icons.map((i) => i.color), [tokens.textMuted, tokens.textMuted]);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(Scaffold),
          'plan_notices_${width.round()}_$name',
        );
        d.dispose();
      });
    }
  }
}
