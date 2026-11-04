// A failed turn that got somewhere offers Continue, which sends "Continue."
// (the agent has the message and the work), not the message again; one
// that got nowhere keeps Try again. The progress test, its edge cases, on
// a reloaded transcript and on the phone, and both notices rendered.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _failed =
    'The turn failed: session/prompt: acp: invalid request: HTTP 412 '
    'Precondition Failed: Account is suspended, possibly due to reaching the '
    'monthly spending limit. (-32603)';

final _image = ImageData(mimeType: 'image/png', data: [1, 2, 3]);

Item _user(String id, String text, {List<ImageData> images = const []}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: text,
  images: images,
);

Item _notice([String status = 'turn_failed', String text = _failed]) =>
    Item(id: 'n', kind: ItemKind.ITEM_KIND_NOTICE, status: status, text: text);

Item _agent(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

Item _tool(String id, {String parent = '', bool report = false}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  title: 'Ran 6 commands',
  status: 'completed',
  parent: parent,
  report: report,
);

ChatState _state(List<Item> items) => ChatState('c', '/Users/me/repo')
  ..agent = 'claude'
  ..items.addAll(items);

List<SendPromptRequest> _sent(FakeDaemon fake) => [
  for (final c in fake.calls)
    if (c is SendPromptRequest) c,
];

/// [state]'s items as ItemViews.
Future<Daemon> _show(
  WidgetTester tester,
  FakeDaemon fake,
  ChatState state,
) async {
  viewport(tester, const Size(760, 400));
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: Column(
          children: [
            for (final it in state.items)
              ItemView(it, state, d, live: false, still: true),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return d;
}

/// The full window on [items], chat 'c'.
Future<(FakeDaemon, Daemon)> _window(
  WidgetTester tester,
  List<Item> items, {
  Size size = const Size(1700, 900),
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  final c = chat('c', 'claude', 'Wrap the events');
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

final Finder _continue = find.widgetWithText(Button, 'Continue');
final Finder _again = find.widgetWithText(Button, 'Try again');

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The label [items] (ending with the notice) give its button, or null.
String? _label(List<Item> items, {void Function(ChatState)? also}) {
  final s = _state(items);
  also?.call(s);
  return failedTurnRetry(s, items.last)?.label;
}

/// The owner's case: a turn that ran commands, then failed.
final List<Item> _worked = [
  _user('u', 'maybe skip guild boss for now'),
  _tool('t1'),
  _notice(),
];

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  test('what the agent did after the message is progress', () {
    for (final it in [
      _agent('a', 'Skipping it.'),
      Item(id: 'a', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, images: [_image]),
      Item(id: 'th', kind: ItemKind.ITEM_KIND_THOUGHT),
      _tool('t1'),
      // A subagent started.
      Item(id: 's', kind: ItemKind.ITEM_KIND_TOOL_CALL, agent: 'Explore'),
      Item(id: 'p', kind: ItemKind.ITEM_KIND_PLAN),
      Item(id: 'pr', kind: ItemKind.ITEM_KIND_PERMISSION, status: 'pending'),
      Item(id: 'q', kind: ItemKind.ITEM_KIND_QUESTION),
    ]) {
      expect(
        _label([_user('u', 'go'), it, _notice()]),
        'Continue',
        reason: '${it.kind}',
      );
    }
    // Before a notice drawn between (the branch named), too.
    expect(
      _label([
        _user('u', 'go'),
        _tool('t1'),
        _notice('branch_renamed', 'Branch renamed'),
        _notice(),
      ]),
      'Continue',
    );
  });

  test("what isn't the turn's work leaves Try again", () {
    for (final it in [
      _notice('branch_renamed', 'Branch renamed'),
      _agent('a', '  '),
      // The failure repeated as the agent's message (Claude's API Error).
      _agent('a', 'HTTP 412 Precondition Failed: Account is suspended'),
      // A subagent started earlier: its step, and its report.
      _tool('x', parent: 'older'),
      _tool('r', report: true),
    ]) {
      expect(_label([_user('u', 'go'), it, _notice()]), 'Try again');
    }
    // Work before the last message is an earlier turn's (or before a
    // steer: the steered message is the one that goes again).
    expect(
      _label([_user('u1', 'one'), _tool('t1'), _user('u2', 'two'), _notice()]),
      'Try again',
    );
    expect(
      _label([_user('u1', 'one'), _user('u2', 'two'), _tool('t1'), _notice()]),
      'Continue',
    );
  });

  test('archived, rewinding or not last: neither', () {
    expect(_label(_worked, also: (s) => s.archived = true), isNull);
    expect(_label(_worked, also: (s) => s.rewinding.value = true), isNull);
    final s = _state([..._worked, _agent('a', 'later')]);
    expect(failedTurnRetry(s, _worked.last), isNull);
  });

  test("a message for a subagent: Try again by today's rules, Continue "
      'goes to the agent', () {
    Item msg({String call = 't1', bool stop = false}) => Item(
      id: 'u',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: stop ? '' : 'and the tests',
      toSubagentName: 'general-purpose',
      toSubagent: call,
      toSubagentStop: stop,
    );
    final again = _state([msg(), _notice()]);
    expect(failedTurnRetry(again, again.items.last)!.request.toSubagent, 't1');
    // A stop, or a replay that lost the call: nothing to send again.
    expect(_label([msg(stop: true), _notice()]), isNull);
    expect(_label([msg(call: ''), _notice()]), isNull);
    // Once the agent began passing it on, Continue is the agent's.
    for (final m in [msg(), msg(stop: true), msg(call: '')]) {
      final s = _state([m, _tool('send'), _notice()]);
      final r = failedTurnRetry(s, s.items.last)!;
      expect((r.label, r.request.toSubagent), ('Continue', ''));
    }
  });

  testWidgets('Continue sends "Continue." alone: no message, images or '
      'queue', (tester) async {
    final fake = FakeDaemon([]);
    final state = _state([
      _user('u', 'What is on this screen?', images: [_image]),
      _agent('a', 'A login form.'),
      _notice(),
    ])..queue = [QueuedMessage(id: 'q1', text: 'then the tests')];
    final d = await _show(tester, fake, state);
    expect(_again, findsNothing);
    await tester.tap(_continue);
    await tester.pump();
    final sent = _sent(fake).single;
    expect(sent.text, continuePrompt);
    expect(sent.images, isEmpty);
    expect(sent.toSubagent, isEmpty);
    // A plain message: it goes before the held queue, which the daemon
    // sends once that turn ends well (TestAResendGoesBeforeTheHeldQueue).
    expect((sent.queue, sent.now), (false, false));
    await closeView(tester, d);
  });

  testWidgets('it is disabled while the chat is busy', (tester) async {
    final fake = FakeDaemon([]);
    final d = await _show(tester, fake, _state(_worked)..busy = true);
    expect(tester.widget<Button>(_continue).onPressed, isNull);
    await closeView(tester, d);
  });

  testWidgets('a reloaded transcript (the daemon restarted) offers the same, '
      'and the button follows new items', (tester) async {
    // As a reopen shows it: the agent's ids, no times, no thought.
    final (fake, d) = await _window(tester, [
      Item(
        id: 'item-1',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'maybe skip guild boss for now',
      ),
      Item(
        id: 'toolu_01',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        title: 'grep boss',
        status: 'completed',
      ),
      _notice(),
    ]);
    expect(_continue, findsOneWidget);
    await tester.tap(_continue);
    await tester.pump();
    expect(_sent(fake).single.text, continuePrompt);

    // Continue's message, then its turn failing at once: Try again sends
    // it again.
    fake
      ..emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(1),
          item: ItemEvent(item: _user('u2', continuePrompt)),
        ),
      )
      ..emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(2),
          item: ItemEvent(item: _notice()..id = 'n2'),
        ),
      );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_continue, findsNothing);
    await tester.tap(_again);
    await tester.pump();
    expect(_sent(fake).last.text, continuePrompt);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('on the phone, Continue sends', (tester) async {
    viewport(
      tester,
      const Size(390, 844),
      ratio: 2,
      brightness: Brightness.dark,
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = chat('c', 'claude', 'Wrap the events');
    final fake = FakeDaemon([c])
      ..answer = ((input) => input is GetChatRequest
          ? GetChatResponse(chat: c, items: _worked)
          : null);
    final phone = Phone(
      PhonePlatform()..saved = pairedRecord(),
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Wrap the events'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.getRect(_continue).right, lessThanOrEqualTo(390));
    await render(tester, find.byType(PhoneApp), 'turn_continue_phone_dark');
    await tester.tap(_continue);
    await tester.pump();
    expect(_sent(fake).single.text, continuePrompt);
    await endPhone(tester, phone);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('it looks as Try again does ($name)', (tester) async {
      viewport(tester, const Size(760, 200));
      final d = await FakeDaemon([]).connect(tester);
      final state = _state(_worked);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ItemView(
                state.items.last,
                state,
                d,
                live: false,
                still: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/turn_continue_$name.png'),
      );
      await closeView(tester, d);
    });
  }

  // Both notices in the window, to look at (make renders).
  for (final width in [1700.0, 720.0]) {
    for (final (name, items) in [
      ('continue', _worked),
      ('try_again', [_user('u', 'maybe skip guild boss for now'), _notice()]),
    ]) {
      testWidgets('$name renders at $width', (tester) async {
        final (_, d) = await _window(tester, items, size: Size(width, 900));
        final button = name == 'continue' ? _continue : _again;
        expect(button, findsOneWidget);
        expect(tester.getRect(button).right, lessThanOrEqualTo(width));
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'turn_${name}_${width.toInt()}_dark',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
