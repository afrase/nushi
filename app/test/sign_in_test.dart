import 'dart:async';

import 'package:connectrpc/connect.dart';
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
import 'package:nushi/sidebar.dart';
import 'package:nushi/sign_in.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Codex's way to sign in, as the daemon offers it.
final _chatGpt = Option(
  id: 'chat-gpt',
  name: 'ChatGPT',
  description: 'Use ChatGPT to authenticate',
);

final _signIn = AgentSignIn(agent: 'codex', methods: [_chatGpt]);

const _refused =
    "couldn't start Codex: it isn't signed in. Run codex login in a "
    'terminal, then start the chat again.';

/// The notice a chat whose agent isn't signed in shows as it wakes.
final _notice = Item(
  id: 'n',
  kind: ItemKind.ITEM_KIND_NOTICE,
  status: 'reopen_failed',
  text: "Couldn't reopen the chat: $_refused",
  options: [_chatGpt],
);

/// The sidebar, Codex's chat the newest, so New chat starts on Codex.
Future<(FakeDaemon, Daemon)> _sidebar(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([chat('b', 'codex', 'Newer', age: 1)]);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(
      Row(
        children: [
          SizedBox(width: 260, child: Sidebar(daemon: d)),
          const Spacer(),
        ],
      ),
      tokens: tokens,
      banner: false,
    ),
  );
  return (fake, d);
}

/// New chat, Enter: Codex's start, refused for want of a sign-in, with
/// the ways to sign in unless not [offered].
Future<void> _startRefused(
  WidgetTester tester,
  FakeDaemon fake, {
  bool offered = true,
}) async {
  fake
    ..startError = _refused
    ..startSignIn = offered ? _signIn : null;
  await tester.tap(find.text('New chat'));
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

final Finder _button = find.widgetWithText(Button, 'Sign in with ChatGPT');

Button _buttonOf(WidgetTester tester) => tester.widget<Button>(_button);

ChatState _codexChat() => ChatState('c', '/Users/me/repo')
  ..agent = 'codex'
  ..title = 'Fix the login redirect'
  ..reopenFailed = true;

void main() {
  setUpAll(loadFonts);

  test('a refused start says the ways to sign in; another says none', () {
    final e = ConnectException(
      Code.failedPrecondition,
      _refused,
      details: [ErrorDetail('nushi.v1.AgentSignIn', _signIn.writeToBuffer())],
    );
    expect(agentSignIn(e)?.methods.single.id, 'chat-gpt');
    expect(agentSignIn(ConnectException(Code.failedPrecondition, 'x')), isNull);
    expect(agentSignIn(StateError('x')), isNull);
    expect(signInLabel(_chatGpt), 'Sign in with ChatGPT');
    expect(signInLabel(Option(name: 'Sign in to Acme')), 'Sign in to Acme');
  });

  testWidgets('a new chat whose agent isn’t signed in offers to sign in; '
      'signed in, it starts', (tester) async {
    final (fake, d) = await _sidebar(tester);
    final gate = fake.signInGate = Completer();
    await _startRefused(tester, fake);
    expect(find.text("Codex isn't signed in"), findsOneWidget);
    expect(
      find.textContaining('Your browser will open', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Or run codex login in a terminal.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining("couldn't start"), findsNothing); // no toast

    final at = tester.getRect(_button);
    await tester.tap(_button);
    await tester.pump();
    expect(fake.signIns.single.agent, 'codex');
    expect(fake.signIns.single.methodId, 'chat-gpt');
    expect(
      find.text('Waiting for you to finish in the browser…'),
      findsOneWidget,
    );
    // It stays where it was pressed, off while the browser has it.
    expect(tester.getRect(_button), at);
    expect(_buttonOf(tester).onPressed, isNull);

    fake.startError = null;
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(find.text("Codex isn't signed in"), findsNothing);
    expect([for (final s in fake.started) s.agent], ['codex', 'codex']);
    expect(d.cantStart, isEmpty);
    d.dispose();
  });

  testWidgets('a sign-in that fails says why and offers it again', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    final gate = fake.signInGate = Completer();
    await _startRefused(tester, fake);
    final at = tester.getRect(_button);
    await tester.tap(_button);
    await tester.pump();
    gate.complete("Codex didn't sign in: Sign-in did not complete");
    await tester.pumpAndSettle();
    expect(
      find.text("Codex didn't sign in: Sign-in did not complete"),
      findsOneWidget,
    );
    expect(
      find.text('Waiting for you to finish in the browser…'),
      findsNothing,
    );
    expect(tester.getRect(_button), at);
    expect(_buttonOf(tester).onPressed, isNotNull);
    expect(fake.started, hasLength(1)); // nothing started again

    // Closed, and the next start refused: its dialog starts afresh.
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    await _startRefused(tester, fake);
    expect(find.text("Codex isn't signed in"), findsOneWidget);
    expect(find.textContaining("Codex didn't sign in"), findsNothing);
    d.dispose();
  });

  testWidgets('Cancel while waiting stops the sign-in and closes, quietly', (
    tester,
  ) async {
    final (fake, d) = await _sidebar(tester);
    fake.signInGate = Completer();
    await _startRefused(tester, fake);
    await tester.tap(_button);
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(fake.cancelled.whereType<SignInAgentRequest>(), hasLength(1));
    expect(find.text("Codex isn't signed in"), findsNothing);
    expect(d.signInOf('codex').waiting, isNull);
    expect(d.signInOf('codex').failed, isNull);
    expect(find.textContaining('canceled'), findsNothing);
    expect(fake.started, hasLength(1));
    d.dispose();
  });

  testWidgets('a start refused without ways to sign in is the toast, as '
      'before', (tester) async {
    final (fake, d) = await _sidebar(tester);
    await _startRefused(tester, fake, offered: false);
    expect(find.text("Codex isn't signed in"), findsNothing);
    expect(find.text(_refused), findsOneWidget);
    expect(fake.signIns, isEmpty);
    d.dispose();
  });

  testWidgets('a chat that couldn’t reopen offers to sign in; signed in, it '
      'reopens', (tester) async {
    final fake = FakeDaemon([]);
    final gate = fake.signInGate = Completer();
    final d = await fake.connect(tester);
    final chat = _codexChat();
    await tester.pumpWidget(
      themed(ItemView(_notice, chat, d, live: false, still: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text("Codex isn't signed in"), findsOneWidget);
    expect(find.textContaining('reopen this chat'), findsOneWidget);
    expect(find.widgetWithText(Button, 'Cancel'), findsNothing);

    final at = tester.getRect(_button);
    await tester.tap(_button);
    await tester.pump();
    expect(tester.getRect(_button), at);
    expect(find.widgetWithText(Button, 'Cancel'), findsOneWidget);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(
      [
        for (final c in fake.calls)
          if (c is ReopenChatRequest) c.chatId,
      ],
      ['c'],
    );
    expect(find.widgetWithText(Button, 'Cancel'), findsNothing);
    d.dispose();
  });

  /// A chat's card beside a launcher of the new-chat dialog, the card's
  /// sign-in started and waiting, the dialog then opened over it; what
  /// the dialog answered goes in [answers].
  Future<(FakeDaemon, Daemon, Completer<String?>)> cardThenDialog(
    WidgetTester tester,
    List<bool> answers,
  ) async {
    viewport(tester, const Size(900, 700));
    final fake = FakeDaemon([]);
    final gate = fake.signInGate = Completer<String?>();
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            ItemView(_notice, _codexChat(), d, live: false, still: true),
            Builder(
              builder: (context) => Button(
                label: 'New chat',
                onPressed: () async =>
                    answers.add(await signInDialog(context, d, _signIn)),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_button);
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, 'New chat'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    return (fake, d, gate);
  }

  testWidgets('a dialog opened while a card signs in learns it worked', (
    tester,
  ) async {
    final answers = <bool>[];
    final (fake, d, gate) = await cardThenDialog(tester, answers);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(answers, [true]);
    expect(find.byType(Dialog), findsNothing);
    expect(fake.signIns, hasLength(1)); // no second login
    d.dispose();
  });

  testWidgets('closing that dialog leaves the card’s sign-in running', (
    tester,
  ) async {
    final answers = <bool>[];
    final (fake, d, gate) = await cardThenDialog(tester, answers);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(Button, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(answers, [false]);
    expect(fake.cancelled.whereType<SignInAgentRequest>(), isEmpty);
    expect(d.signInOf('codex').waiting, 'chat-gpt');
    gate.complete(null);
    await tester.pumpAndSettle();
    d.dispose();
  });

  // The phone, as an app that doesn't know the ways to sign in, keeps a
  // failed reopen's plain notice and its Try again.
  testWidgets('the phone keeps the plain notice', (tester) async {
    final fake = FakeDaemon([]);
    final d = Daemon(transport: fake, remote: true);
    await tester.pumpWidget(
      themed(ItemView(_notice, _codexChat(), d, live: false, still: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text("Codex isn't signed in"), findsNothing);
    expect(find.textContaining("Couldn't reopen the chat"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final state in ['offer', 'waiting', 'failed']) {
      testWidgets('the card, $state ($name)', (tester) async {
        viewport(tester, const Size(640, 220));
        final fake = FakeDaemon([]);
        final gate = fake.signInGate = Completer();
        final d = await fake.connect(tester);
        await tester.pumpWidget(
          themed(
            Padding(
              padding: const EdgeInsets.all(16),
              child: ItemView(
                _notice,
                _codexChat(),
                d,
                live: false,
                still: true,
              ),
            ),
            tokens: tokens,
            banner: false,
          ),
        );
        await tester.pumpAndSettle();
        if (state != 'offer') {
          await tester.tap(_button);
          await tester.pump();
        }
        if (state == 'failed') {
          gate.complete("Codex didn't sign in: Sign-in did not complete");
        }
        await tester.pump();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/sign_in_card_${state}_$name.png'),
        );
        if (!gate.isCompleted) gate.complete(null);
        await tester.pumpAndSettle();
        d.dispose();
      });
    }

    testWidgets('the dialog ($name)', (tester) async {
      viewport(tester, const Size(700, 400));
      final (fake, d) = await _sidebar(tester, tokens: tokens);
      await _startRefused(tester, fake);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/sign_in_dialog_$name.png'),
      );
      d.dispose();
    });
  }

  // The window, wide and narrow: a chat that couldn't reopen, its card
  // waiting on the browser, and a new chat's dialog over it.
  for (final (what, size) in [
    ('wide', const Size(1700, 900)),
    ('narrow', const Size(720, 800)),
  ]) {
    for (final b in renderThemes) {
      testWidgets('the window, $what (${b.name})', (tester) async {
        viewport(tester, size, brightness: b);
        final c = chat('c', 'codex', 'Fix the login redirect');
        final fake = FakeDaemon([c])
          ..answer = (input) => switch (input) {
            GetChatRequest() => GetChatResponse(
              chat: c,
              items: [
                userSays('u1', 'Why does the redirect keep the query string?'),
                agentSays(
                  'a1',
                  'So the page you asked for opens after you sign in.',
                ),
                userSays('u2', 'Make it drop the tracking parameters.'),
                _notice,
              ],
              status: ChatStatus(reopenFailed: true),
              seq: Int64(1),
            ),
            _ => null,
          };
        final gate = fake.signInGate = Completer();
        final d = await fake.connect(tester)
          ..select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await frames(tester, 8, const Duration(milliseconds: 100));
        expect(find.text("Codex isn't signed in"), findsOneWidget);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'sign_in_card_${what}_${b.name}',
        );
        // A new chat's start, refused: the dialog over the window.
        fake
          ..startError = _refused
          ..startSignIn = _signIn;
        await press(tester, LogicalKeyboardKey.keyN, cmd: true, settle: false);
        await frames(tester, 4, const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await frames(tester, 6, const Duration(milliseconds: 100));
        expect(find.byType(Dialog), findsOneWidget);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'sign_in_dialog_${what}_${b.name}',
        );
        await tester.tap(find.widgetWithText(Button, 'Cancel'));
        await frames(tester, 6, const Duration(milliseconds: 100));
        await tester.tap(_button);
        await frames(tester, 2, const Duration(milliseconds: 100));
        await render(
          tester,
          find.byType(NushiApp),
          'sign_in_card_waiting_${what}_${b.name}',
        );
        gate.complete("Codex didn't sign in: Sign-in did not complete");
        await frames(tester, 2, const Duration(milliseconds: 100));
        await render(
          tester,
          find.byType(NushiApp),
          'sign_in_card_failed_${what}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
