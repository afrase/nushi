import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/remote.dart' show keyFingerprint;

import 'fake_daemon.dart';

final List<Chat> _chats = [
  chat(
    'a',
    'claude',
    'Fix the flaky relay test',
    status: ChatStatus(busy: true, started: _started),
  ),
  chat(
    'b',
    'codex',
    'Review the Noise channel',
    age: 5,
    status: ChatStatus(busy: true, started: _started, waiting: true),
  ),
  chat('c', 'claude', 'Web Push from the daemon', age: 30),
  chat(
    'd',
    'pig',
    'Notes for the README',
    folder: '/Users/me/notes',
    age: 60,
    status: ChatStatus(asleep: true),
  ),
];

final Int64 _started = Int64(
  DateTime(2026, 10, 25, 11, 58).millisecondsSinceEpoch,
);

/// RFC 8291's application server key, as a daemon's VAPID key.
const _vapid =
    'BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIg'
    'Dll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8';

/// A paired browser: what IndexedDB would hold.
Map<String, Object?> _paired() => {
  'key': Uint8List(32)..[0] = 7,
  'name': 'iPhone',
  'relay': 'wss://nushi.taile2d635.ts.net',
  'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
  'daemonKey': Uint8List(32)..[0] = 9,
};

/// The question chat "b" waits on.
GetChatResponse _question() => GetChatResponse(
  chat: _chats[1],
  status: _chats[1].status,
  items: [
    Item(
      id: 'u',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: 'Review the Noise channel, then ask me which part first',
    ),
    Item(
      id: 'm',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'I read `noiseconn` and `packages/noise`. One thing first:',
    ),
    Item(
      id: 'q',
      kind: ItemKind.ITEM_KIND_QUESTION,
      status: 'pending',
      fields: [
        Field(
          id: 'question_0',
          title: 'Part',
          description: 'Which part should I review first?',
          type: FieldType.FIELD_TYPE_CHOICE,
          options: [
            Option(id: 'h', name: 'The handshake'),
            Option(id: 'r', name: 'Rekeying'),
            Option(id: 'p', name: 'Pairing'),
          ],
        ),
      ],
    ),
  ],
);

/// The phone app on [fake], paired if [paired], on a phone-sized screen.
Future<(Phone, PhonePlatform)> _app(
  WidgetTester tester,
  FakeDaemon fake, {
  bool paired = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 760),
}) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2;
  tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final platform = PhonePlatform()..saved = paired ? _paired() : null;
  final phone = Phone(
    platform,
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  return (phone, platform);
}

/// Ends the phone's link, and its timers, before the test ends.
Future<void> _end(WidgetTester tester, Phone phone) async {
  await phone.close();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(loadFonts);

  for (final b in Brightness.values) {
    final name = b.name;

    testWidgets('the chats, grouped by folder, with their states ($name)', (
      tester,
    ) async {
      final (phone, _) = await _app(tester, FakeDaemon(_chats), brightness: b);
      expect(find.text('running'), findsOneWidget);
      expect(find.text('needs you'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(find.text('asleep'), findsOneWidget);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_chats_$name.png'),
      );
      await _end(tester, phone);
    });

    testWidgets('a chat with its question card ($name)', (tester) async {
      final fake = FakeDaemon(_chats)
        ..answer = (input) => input is GetChatRequest ? _question() : null;
      final (phone, platform) = await _app(tester, fake, brightness: b);
      await tester.tap(find.text('Review the Noise channel'));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionCard), findsOneWidget);
      expect(
        fake.calls.whereType<SetDeviceViewRequest>().last.chatId,
        'b',
        reason: 'the daemon knows the chat shows: no push for it',
      );
      expect(platform.closed, ['b'], reason: 'its notifications go');
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_question_$name.png'),
      );
      // Answering it is a tap, with a target a finger finds (44 points).
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Rekeying'),
                    matching: find.byType(GestureDetector),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('Rekeying'));
      await tester.pump();
      final answered = fake.calls.whereType<AnswerQuestionRequest>().single;
      expect(answered.itemId, 'q');
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<SetDeviceViewRequest>().last.chatId, '');
      await _end(tester, phone);
    });

    testWidgets('pairing: the link, then the code ($name)', (tester) async {
      final (phone, platform) = await _app(
        tester,
        FakeDaemon(_chats),
        paired: false,
        brightness: b,
      );
      platform
        ..iPhone = true
        ..installed = true;
      await tester.pump();
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_pair_$name.png'),
      );
      phone
        ..pairing = PairingCode('491 207')
        ..notifyListeners();
      await tester.pump();
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_pair_code_$name.png'),
      );
      await _end(tester, phone);
    });

    testWidgets('Settings ($name)', (tester) async {
      final fake = FakeDaemon(_chats)
        ..answer = (input) =>
            input is GetPushKeyRequest ? GetPushKeyResponse(key: _vapid) : null;
      final (phone, _) = await _app(tester, fake, brightness: b);
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_settings_$name.png'),
      );
      await _end(tester, phone);
    });
  }

  // The screens at real sizes: iPhones (the safe area's height: 844 and 932
  // less the status bar and the home indicator), one on its side, and an
  // iPad's width. The bar's buttons sit at its right edge, the composer at
  // the bottom, and nothing overflows (an overflow fails the test).
  for (final (name, size) in [
    ('390', const Size(390, 763)),
    ('430', const Size(430, 851)),
    ('landscape', const Size(750, 369)),
    ('820', const Size(820, 1140)),
  ]) {
    testWidgets('at $name: the chats and a chat', (tester) async {
      final fake = FakeDaemon(_chats)
        ..answer = (input) => input is GetChatRequest ? _question() : null;
      final (phone, _) = await _app(tester, fake, size: size);
      final settings = tester.getRect(find.bySemanticsLabel('Settings'));
      expect(settings.right, closeTo(size.width - 4, 1));
      expect(settings.top, greaterThanOrEqualTo(0));
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_chats_at_$name.png'),
      );
      await tester.tap(find.text('Review the Noise channel'));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.byType(TextField).last);
      expect(box.bottom, lessThanOrEqualTo(size.height));
      expect(box.bottom, greaterThan(size.height - 120));
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_question_at_$name.png'),
      );
      await _end(tester, phone);
    });
  }

  testWidgets('notifications on and off: the subscription to the daemon', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats)
      ..answer = (input) =>
          input is GetPushKeyRequest ? GetPushKeyResponse(key: _vapid) : null;
    final (phone, platform) = await _app(tester, fake);
    platform.sub = PushSub(
      'https://web.push.apple.com/QGuQyav',
      Uint8List(65)..[0] = 4,
      Uint8List(16),
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final on = fake.calls.whereType<SetPushSubscriptionRequest>().single;
    expect(on.endpoint, 'https://web.push.apple.com/QGuQyav');
    expect(on.auth, hasLength(16));
    expect(phone.push, PushState.on);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<SetPushSubscriptionRequest>().last.endpoint,
      '',
    );
    expect(phone.push, PushState.off);
    await _end(tester, phone);
  });

  testWidgets('a link that isn’t a pairing link is refused', (tester) async {
    final (phone, _) = await _app(tester, FakeDaemon(_chats), paired: false);
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/?s=1',
    );
    await tester.pump();
    await tester.tap(find.text('Pair'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.textContaining("isn't a Nushi pairing link"), findsOneWidget);
    expect(phone.paired, isNull);
    await _end(tester, phone);
  });

  testWidgets('a link for another relay is refused, saying so', (tester) async {
    final (phone, _) = await _app(tester, FakeDaemon(_chats), paired: false);
    final k = 'A' * 43;
    await tester.enterText(
      find.byType(TextField).first,
      'https://evil.example.com/#pair?r=wss%3A%2F%2Fevil.example.com'
      '&i=abcdefghijklmnopqrstuv&k=$k&s=$k',
    );
    await tester.pump();
    await tester.tap(find.text('Pair'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.textContaining('for the relay at evil.example.com'), findsOne);
    expect(phone.paired, isNull);
    await _end(tester, phone);
  });

  testWidgets('a subscription made with an old VAPID key is turned off', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats)
      ..answer = (input) =>
          input is GetPushKeyRequest ? GetPushKeyResponse(key: _vapid) : null;
    final platform = PhonePlatform()
      ..saved = _paired()
      ..push = PushState.on
      ..subscribedKey = Uint8List(65);
    final phone = Phone(
      platform,
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(phone.push, PushState.off);
    await _end(tester, phone);
  });

  testWidgets('Forget this Mac forgets the key and the pairing', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats);
    final (phone, platform) = await _app(tester, fake);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text(keyFingerprint(Uint8List(32)..[0] = 9)),
      findsOneWidget,
      reason: "the Mac's key, as the Mac shows it",
    );
    await tester.tap(find.text('Forget this Mac'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(platform.saved, isNull);
    expect(platform.wasReset, isTrue, reason: 'caches and the worker too');
    expect(phone.daemon, isNull);
    expect(fake.calls.whereType<UnpairThisDeviceRequest>(), hasLength(1));
    expect(find.text('Pair with a Mac'), findsOneWidget);
    // Pairing is the root again: nothing to go back to.
    expect(find.bySemanticsLabel('Back'), findsNothing);
    await _end(tester, phone);
  });

  testWidgets('paired, the chats are the root: no back, whatever comes', (
    tester,
  ) async {
    final (phone, _) = await _app(
      tester,
      FakeDaemon(_chats),
      paired: false,
      size: const Size(390, 844),
    );
    expect(find.text('Pair with a Mac'), findsOneWidget);
    // Paired (as pair() ends): the chats take pairing's place.
    phone.platform.saved = _paired();
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('Chats'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.canPop(), isFalse);
    // A route the browser pushes (its history) doesn't stack a screen.
    await tester.binding.handlePushRoute('/');
    await tester.pump();
    expect(nav.canPop(), isFalse);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    // Back from the chats doesn't reach pairing.
    expect(await nav.maybePop(), isFalse);
    await tester.pump();
    expect(find.text('Pair with a Mac'), findsNothing);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_root_390.png'),
    );
    await _end(tester, phone);
  });

  testWidgets('a newer version waits: Reload brings it in', (tester) async {
    final (phone, platform) = await _app(tester, FakeDaemon(_chats));
    expect(find.text('Nushi was updated'), findsNothing);
    platform.updateReady.value = true;
    await tester.pump();
    expect(find.text('Nushi was updated'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    expect(platform.updated, isTrue);
    await _end(tester, phone);
  });
}
