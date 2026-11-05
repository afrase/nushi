import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// While a rewind or a Stop's take-back is on its way, the composer takes
// nothing and sends nothing; the message lands in it after.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _you(String id, String text) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: text,
  rewindable: true,
);

Item _agent(String id) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done.');

/// A chat of one turn, answered, that can be rewound.
ChatState _chat(String id) => ChatState(id, '/Users/me/app')
  ..agent = 'claude'
  ..loaded = true
  ..canRewind = true
  ..items.addAll([_you('u1', 'Add the login page'), _agent('a1')]);

/// A chat whose running turn the agent hasn't answered.
ChatState _unanswered() => _chat('c')
  ..busy = true
  ..started = DateTime.now()
  ..items.add(_you('u2', 'Now the tests'));

/// A box on a chat, the daemon's rewinds and stops held on [held].
class _Box {
  new(this.fake, this.daemon, this.chat, this.held, this.rewinds);

  final FakeDaemon fake;
  final Daemon daemon;
  final ChatState chat;
  final Completer<Object> held;
  final List<RewindChatRequest> rewinds; // as asked: the fake's calls wait

  Iterable<SendPromptRequest> get sent =>
      fake.calls.whereType<SendPromptRequest>();

  String get text => chat.draft.text.text;
}

Future<_Box> _box(
  WidgetTester tester, {
  ChatState? chat,
  Size size = const Size(800, 400),
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, size);
  final held = Completer<Object>();
  final rewinds = <RewindChatRequest>[];
  final fake = FakeDaemon([])
    ..answer = (input) {
      if (input is RewindChatRequest) rewinds.add(input);
      return input is RewindChatRequest || input is CancelTurnRequest
          ? held.future
          : null;
    };
  final d = await fake.connect(tester);
  final c = chat ?? _chat('c');
  d.chats[c.id] = c;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        backgroundColor: tokens.base,
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            // As the chat's view, which builds it again as it changes.
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => Composer(chat: c, daemon: d),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return _Box(fake, d, c, held, rewinds);
}

/// Starts a rewind to the chat's first message, as the transcript would.
Future<void> _rewind(WidgetTester tester, _Box b) async {
  final context = tester.element(find.byType(Composer));
  unawaited(rewindTo(context, b.daemon, b.chat, b.chat.items.first));
  await tester.pump();
}

/// Presses Stop.
Future<void> _stop(WidgetTester tester, _Box b) async {
  final context = tester.element(find.byType(Composer));
  unawaited(stopTurn(context, b.chat, b.daemon));
  await tester.pump();
}

/// The daemon answers what's held with [answer].
Future<void> _answer(WidgetTester tester, _Box b, Object answer) async {
  b.held.complete(answer);
  await tester.pump();
  await tester.pump();
}

Future<void> _done(WidgetTester tester, _Box b) async {
  b.daemon.dispose();
  await tester.pump(const Duration(seconds: 4)); // the ping's timeout
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

final _message = RewindChatResponse(
  message: QueuedMessage(text: 'Add the login page'),
);

/// ⌘V, with [text] on the clipboard.
Future<void> _paste(WidgetTester tester, String text) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData' ? {'text': text} : null,
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets(
    'while it rewinds nothing goes in or out; then the message is in the box',
    (tester) async {
      final b = await _box(tester);
      await _rewind(tester, b);

      expect(b.chat.rewinding.value, isTrue);
      expect(_field(tester).readOnly, isTrue);
      expect(find.text('Rewinding…'), findsOne);

      await tester.enterText(find.byType(TextField), 'typed');
      await _paste(tester, 'pasted');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // no recall
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // no new line
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(b.text, isEmpty);
      expect(b.sent, isEmpty);

      await tester.tap(find.byTooltip(plusTooltip));
      await tester.pump();
      expect(find.text('Mention a file'), findsNothing);

      await _answer(tester, b, _message);

      expect(b.chat.rewinding.value, isFalse);
      expect(_field(tester).readOnly, isFalse);
      expect(b.text, 'Add the login page');
      expect(_field(tester).focusNode!.hasFocus, isTrue);
      expect(
        b.chat.draft.text.selection,
        const TextSelection.collapsed(offset: 'Add the login page'.length),
      );
      expect(find.byTooltip('Send (⏎)'), findsOne);

      // Unlocked, the same keys work: the ones above did reach the box.
      await _paste(tester, ' now');
      expect(b.text, 'Add the login page now');
      await _done(tester, b);
    },
    variant: _mac,
  );

  testWidgets(
    'what is in the box stays and the message follows it; no send button',
    (tester) async {
      final b = await _box(tester);
      b.chat.draft.text.text = 'Mind the footer';
      await tester.pump();
      expect(find.byTooltip('Send (⏎)'), findsOne);
      await _rewind(tester, b);

      expect(find.text('Mind the footer'), findsOne);
      expect(find.byTooltip('Send (⏎)'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(b.sent, isEmpty);

      await _answer(tester, b, _message);
      expect(b.text, 'Mind the footer\n\nAdd the login page');
      await _done(tester, b);
    },
    variant: _mac,
  );

  testWidgets('a turn stopping: Queue, Stop and send and the pills are off', (
    tester,
  ) async {
    final b = await _box(tester, chat: _unanswered());
    b.chat
      ..queue = [QueuedMessage(id: 'q1', text: 'Then docs')]
      ..draft.text.text = 'Also the README';
    await tester.pump();
    expect(find.byTooltip('Queue (⏎)'), findsOne);
    expect(find.byTooltip('Stop and send (⌘⏎)'), findsOne);

    await _stop(tester, b);
    expect(_field(tester).readOnly, isTrue);
    expect(find.byTooltip('Queue (⏎)'), findsNothing);
    expect(find.byTooltip('Stop and send (⌘⏎)'), findsNothing);

    await tester.tap(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Send now: stop the turn and send it'));
    await tester.pump();
    expect(b.fake.calls.whereType<UnqueueRequest>(), isEmpty);
    expect(b.sent, isEmpty);

    await _answer(tester, b, CancelTurnResponse());
    await _done(tester, b);
  }, variant: _mac);

  testWidgets('a failed rewind opens the box as it was, and says why', (
    tester,
  ) async {
    final b = await _box(tester);
    b.chat.draft.text.text = 'Mind the footer';
    await _rewind(tester, b);
    expect(_field(tester).readOnly, isTrue);

    b.held.completeError(StateError('the agent quit'));
    await tester.pump();
    await tester.pump();
    expect(b.chat.rewinding.value, isFalse);
    expect(_field(tester).readOnly, isFalse);
    expect(b.text, 'Mind the footer');
    expect(find.byTooltip('Send (⏎)'), findsOne);
    expect(find.textContaining('the agent quit'), findsOne);
    await tester.pumpAndSettle(const Duration(seconds: 1)); // its snack bar
    await _done(tester, b);
  }, variant: _mac);

  testWidgets('a rewind running: a second one asks nothing', (tester) async {
    final b = await _box(tester);
    await _rewind(tester, b);
    await _rewind(tester, b);
    expect(b.rewinds, hasLength(1));
    expect(b.chat.rewinding.value, isTrue); // nor opens the box
    await _answer(tester, b, RewindChatResponse());
    await _done(tester, b);
  }, variant: _mac);

  testWidgets('two chats do not share the lock', (tester) async {
    final other = _chat('other');
    final b = await _box(tester);
    await _rewind(tester, b);
    expect(b.chat.rewinding.value, isTrue);
    expect(other.rewinding.value, isFalse);

    // The other chat's box, shown instead, stays live.
    await tester.pumpWidget(
      themed(Composer(key: UniqueKey(), chat: other, daemon: b.daemon)),
    );
    await tester.pump();
    expect(_field(tester).readOnly, isFalse);
    expect(find.text('Rewinding…'), findsNothing);

    await _answer(tester, b, _message);
    expect(other.draft.text.text, isEmpty);
    // A box that wasn't there takes it when it's next built.
    expect(b.chat.takeBack.value?.text, 'Add the login page');
    await _done(tester, b);
  }, variant: _mac);

  group('Stop', () {
    testWidgets('of an unanswered message locks the box until it is back', (
      tester,
    ) async {
      final b = await _box(tester, chat: _unanswered());
      await _stop(tester, b);
      expect(_field(tester).readOnly, isTrue);
      expect(find.text('Taking your message back…'), findsOne);

      await _answer(
        tester,
        b,
        CancelTurnResponse(message: QueuedMessage(text: 'Now the tests')),
      );
      expect(b.chat.rewinding.value, isFalse);
      expect(b.chat.stopping, isFalse);
      expect(b.text, 'Now the tests');
      await _done(tester, b);
    }, variant: _mac);

    testWidgets('of an answered message leaves the box open', (tester) async {
      final b = await _box(
        tester,
        chat: _chat('c')
          ..busy = true
          ..started = DateTime.now(),
      );
      await _stop(tester, b);
      expect(_field(tester).readOnly, isFalse);
      await _answer(tester, b, CancelTurnResponse());
      await _done(tester, b);
    }, variant: _mac);

    testWidgets('an agent that ignores it does not keep the box locked', (
      tester,
    ) async {
      final b = await _box(tester, chat: _unanswered());
      await _stop(tester, b);
      expect(_field(tester).readOnly, isTrue);
      await tester.pump(rewindLockLimit);
      await tester.pump();
      expect(_field(tester).readOnly, isFalse);

      // Late, it still lands, after what was typed since.
      b.chat.draft.text.text = 'Typed meanwhile';
      await _answer(
        tester,
        b,
        CancelTurnResponse(message: QueuedMessage(text: 'Now the tests')),
      );
      expect(b.text, 'Typed meanwhile\n\nNow the tests');
      await _done(tester, b);
    }, variant: _mac);
  });

  group('the locked box', () {
    for (final (size, name, tokens) in const [
      (Size(1700, 300), 'wide_dark', Tokens.dark),
      (Size(1700, 300), 'wide_light', Tokens.light),
      (Size(720, 300), 'narrow_dark', Tokens.dark),
      (Size(720, 300), 'narrow_light', Tokens.light),
    ]) {
      testWidgets(name, (tester) async {
        final b = await _box(tester, size: size, tokens: tokens);
        await _rewind(tester, b);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/rewind_lock_$name.png'),
        );
        await _answer(tester, b, RewindChatResponse());
        await _done(tester, b);
      }, variant: _mac);
    }
  });

  test('a message is unanswered until text or a tool call', () {
    final c = _chat('c');
    expect(unanswered(c), isFalse); // the agent's message is the last
    c.items.add(_you('u2', 'Now the tests'));
    expect(unanswered(c), isTrue);
    c.items.add(Item(id: 't', kind: ItemKind.ITEM_KIND_THOUGHT));
    expect(unanswered(c), isTrue);
    c.items.add(Item(id: 'b', kind: ItemKind.ITEM_KIND_TOOL_CALL));
    expect(unanswered(c), isFalse);
    expect(unanswered(ChatState('e', '/tmp')), isFalse);
  });
}
