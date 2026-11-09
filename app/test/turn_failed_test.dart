// A failed turn's notice and its Try again: on the transcript's last item
// only, disabled while the chat is busy, sending the last message with its
// images and leaving the box alone; a long error wraps beside it at every
// size.
import 'dart:convert';

import 'package:connectrpc/connect.dart' as connect;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _short = 'The turn failed: API Error: Repeated 529 Overloaded errors';
const _long =
    '$_short. The service stayed at capacity through every attempt, so the '
    'request was given up on after ten tries; wait a while and send the '
    'message again, or pick another model for this chat before you do.';

/// One transparent pixel.
final _image = ImageData(
  mimeType: 'image/png',
  data: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  ),
);

Item _user(String id, String text, {List<ImageData> images = const []}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: text,
  images: images,
);

Item _notice(String id, String status, [String text = _short]) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_NOTICE, status: status, text: text);

Item _agent(String id) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'On it.');

ChatState _state(List<Item> items, {bool busy = false}) =>
    ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..busy = busy
      ..items.addAll(items);

/// The prompts the daemon was sent.
List<SendPromptRequest> _sent(FakeDaemon fake) => [
  for (final c in fake.calls)
    if (c is SendPromptRequest) c,
];

/// [state]'s items as ItemViews, in a window of [width].
Future<Daemon> _show(
  WidgetTester tester,
  FakeDaemon fake,
  ChatState state, {
  double width = 760,
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, Size(width, 340));
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 12,
            children: [
              for (final it in state.items)
                ItemView(it, state, d, live: false, still: true),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return d;
}

final Finder _button = find.widgetWithText(Button, 'Try again');

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The full window on [items], chat 'c'.
Future<(FakeDaemon, Daemon)> _window(
  WidgetTester tester,
  List<Item> items, {
  Size size = const Size(1700, 900),
}) async {
  viewport(tester, size);
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: items)
        : null);
  final d = await fake.connect(tester)
    ..select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (fake, d);
}

/// The button sits inside [width], and the long error wrapped beside it:
/// more than one line, none of it under the button.
void _wraps(WidgetTester tester, double width) {
  expect(tester.takeException(), isNull);
  final button = tester.getRect(_button);
  final text = tester.getRect(find.text(_long));
  expect(button.right, lessThanOrEqualTo(width));
  expect(text.right, lessThanOrEqualTo(button.left));
  expect(text.height, greaterThan(24));
}

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('it looks as an error does, with its button, and a long '
        'error wraps ($name)', (tester) async {
      final d = await _show(
        tester,
        FakeDaemon([]),
        _state([
          _user('u', 'Fix the login redirect'),
          _notice('e', 'error'),
          _notice('n', 'turn_failed', _long),
        ]),
        tokens: tokens,
      );
      _wraps(tester, 760);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/turn_failed_$name.png'),
      );
      await closeView(tester, d);
    });
  }

  testWidgets('it shows on the last item, not on an older failed notice', (
    tester,
  ) async {
    final d = await _show(
      tester,
      FakeDaemon([]),
      _state([
        _user('u1', 'one'),
        _notice('n1', 'turn_failed'),
        _user('u2', 'two'),
        _notice('n2', 'turn_failed'),
      ]),
    );
    expect(_button, findsOneWidget);
    final last = tester.getCenter(find.text(_short).last).dy;
    expect(tester.getCenter(_button).dy, last);
    await closeView(tester, d);

    final older = await _show(
      tester,
      FakeDaemon([]),
      _state([_user('u', 'one'), _notice('n', 'turn_failed'), _agent('a')]),
    );
    expect(find.text(_short), findsOneWidget);
    expect(_button, findsNothing);
    await closeView(tester, older);
  });

  testWidgets('the other error notices have none', (tester) async {
    for (final text in [
      'The agent quit unexpectedly. Your next message reopens the chat.',
      "The agent isn't running; send the message again to reopen the chat.",
      "Couldn't move the chat to /Users/me/other: no such folder",
      "Couldn't rewind the chat: the agent quit",
      "Couldn't hand your message to the agent; it's back in the queue: gone",
    ]) {
      final d = await _show(
        tester,
        FakeDaemon([]),
        _state([_user('u', 'one'), _notice('n', 'error', text)]),
      );
      expect(find.text(text), findsOneWidget);
      expect(_button, findsNothing);
      await closeView(tester, d);
    }
  });

  testWidgets('with nothing that can go again it has none', (tester) async {
    for (final state in [
      _state([_notice('n', 'turn_failed')]),
      _state([_user('u', 'one'), _notice('n', 'turn_failed')])..archived = true,
      // A stop of a subagent's task has nothing to send.
      _state([
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          toSubagentName: 'general-purpose',
          toSubagent: 't1',
          toSubagentStop: true,
        ),
        _notice('n', 'turn_failed'),
      ]),
      // After a replay nothing says which subagent it was for.
      _state([
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          text: 'and the tests',
          toSubagentName: 'general-purpose',
        ),
        _notice('n', 'turn_failed'),
      ]),
    ]) {
      final d = await _show(tester, FakeDaemon([]), state);
      expect(_button, findsNothing);
      await closeView(tester, d);
    }
  });

  testWidgets('it is disabled while the chat is busy', (tester) async {
    final fake = FakeDaemon([]);
    final d = await _show(
      tester,
      fake,
      _state([_user('u', 'one'), _notice('n', 'turn_failed')], busy: true),
    );
    expect(tester.widget<Button>(_button).onPressed, isNull);
    await tester.tap(_button);
    await tester.pump();
    expect(_sent(fake), isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a tap sends the last message’s text and images, once, as a '
      'plain prompt', (tester) async {
    final fake = FakeDaemon([]);
    final d = await _show(
      tester,
      fake,
      _state([
        _user('u1', 'an older message'),
        _agent('a'),
        _user('u2', 'What is on this screen?', images: [_image]),
        _notice('n', 'turn_failed'),
      ]),
    );
    await tester.tap(_button);
    await tester.pump();
    final sent = _sent(fake).single;
    expect(sent.chatId, 'c');
    expect(sent.text, 'What is on this screen?');
    expect(sent.images.single.mimeType, 'image/png');
    expect(sent.images.single.data, _image.data);
    expect(sent.queue, isFalse);
    expect(sent.now, isFalse);
    expect(sent.toSubagent, isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a message for a subagent goes to it again', (tester) async {
    final fake = FakeDaemon([]);
    final d = await _show(
      tester,
      fake,
      _state([
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          text: 'and the tests',
          toSubagentName: 'general-purpose',
          toSubagent: 't1',
        ),
        _notice('n', 'turn_failed'),
      ]),
    );
    await tester.tap(_button);
    await tester.pump();
    final sent = _sent(fake).single;
    expect((sent.text, sent.toSubagent), ('and the tests', 't1'));
    await closeView(tester, d);
  });

  testWidgets('a refused send says why', (tester) async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is SendPromptRequest
          ? throw connect.ConnectException(
              connect.Code.failedPrecondition,
              "the agent doesn't take images",
            )
          : null;
    final d = await _show(
      tester,
      fake,
      _state([
        _user('u', 'look', images: [_image]),
        _notice('n', 'turn_failed'),
      ]),
    );
    await tester.tap(_button);
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining("the agent doesn't take images"),
      findsOneWidget,
    );
    await closeView(tester, d);
  });

  testWidgets('in the window it leaves the box alone, and goes with a new '
      'item or greys with a busy chat', (tester) async {
    final (fake, d) = await _window(tester, [
      _user('u', 'Fix the login redirect'),
      _notice('n', 'turn_failed'),
    ]);
    await tester.enterText(find.byType(TextField).last, 'half a thought');
    await tester.pump();

    await tester.tap(_button);
    await tester.pump();
    expect(_sent(fake).single.text, 'Fix the login redirect');
    final box = tester.widget<TextField>(find.byType(TextField).last);
    expect(box.controller?.text, 'half a thought');

    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        status: ChatStatus(busy: true, started: Int64(1000)),
      ),
    );
    await tester.pump();
    expect(tester.widget<Button>(_button).onPressed, isNull);

    fake.emit(EventsResponse(chatId: 'c', seq: Int64(2), status: ChatStatus()));
    await tester.pump();
    expect(tester.widget<Button>(_button).onPressed, isNotNull);

    // Between turns, as a branch named late would: the chat stays idle.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(3),
        item: ItemEvent(
          item: _notice('b', 'branch_renamed', 'Branch renamed'),
          index: 2,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Branch renamed'), findsOneWidget);
    expect(_button, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  for (final width in [1700.0, 720.0]) {
    testWidgets('a long error wraps in the window at $width', (tester) async {
      final (_, d) = await _window(tester, [
        _user('u', 'Fix the login redirect'),
        _notice('n', 'turn_failed', _long),
      ], size: Size(width, 900));
      expect(_button, findsOneWidget);
      _wraps(tester, width);
      await closeView(tester, d);
    }, variant: _mac);
  }

  testWidgets('a long error wraps on the phone, and a tap sends', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), ratio: 2);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = chat('c', 'claude', 'Fix the login redirect');
    final fake = FakeDaemon([c])
      ..answer = ((input) => input is GetChatRequest
          ? GetChatResponse(
              chat: c,
              items: [
                _user('u', 'Fix the login redirect', images: [_image]),
                _notice('n', 'turn_failed', _long),
              ],
            )
          : null);
    final phone = await startPhone(tester, fake);
    await tester.tap(find.text('Fix the login redirect'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_button, findsOneWidget);
    _wraps(tester, 390);
    await tester.tap(_button);
    await tester.pump();
    expect(_sent(fake).single.images.single.data, _image.data);
    await endPhone(tester, phone);
  });
}
