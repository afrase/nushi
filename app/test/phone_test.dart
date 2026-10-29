import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/scanner.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/remote.dart' show keyFingerprint, remoteState;

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
  chat('c', 'claude', 'Web Push from the daemon', age: 30)..unseen = true,
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
  'relay': 'wss://nushi.aaronfrase.com',
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
  Map<String, Object?>? record,
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
  final platform = PhonePlatform()
    ..saved = record ?? (paired ? _paired() : null);
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
      expect(find.text('working'), findsOneWidget);
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

  // UX review, findings 17 and 18.
  testWidgets('the chats that need you are a group at the top', (tester) async {
    final (phone, _) = await _app(tester, FakeDaemon(_chats));
    final heading = tester.getRect(find.text('Needs you'));
    final waiting = tester.getRect(find.text('Review the Noise channel'));
    final working = tester.getRect(find.text('Fix the flaky relay test'));
    expect(heading.top, lessThan(waiting.top));
    expect(waiting.top, lessThan(working.top));
    expect(find.text('Review the Noise channel'), findsOne); // moved, once
    await _end(tester, phone);
  });

  testWidgets("a permission's long option wraps on the phone, whole; a "
      "question's options have no digits", (tester) async {
    const long =
        "Yes, and don't ask again for make in this folder and its "
        'subfolders';
    final fake = FakeDaemon(_chats)
      ..answer = (input) => input is GetChatRequest
          ? GetChatResponse(
              chat: _chats[1],
              status: _chats[1].status,
              items: [
                Item(
                  id: 'p',
                  kind: ItemKind.ITEM_KIND_PERMISSION,
                  status: 'pending',
                  title: 'make check',
                  options: [
                    Option(id: 'y', name: 'Yes'),
                    Option(id: 'a', name: long),
                    Option(id: 'n', name: 'No'),
                  ],
                ),
              ],
            )
          : null;
    final (phone, _) = await _app(tester, fake);
    await tester.tap(find.text('Review the Noise channel'));
    await tester.pumpAndSettle();
    final text = find.text(long);
    expect(tester.widget<Text>(text).maxLines, 3);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(text).height, greaterThan(20)); // two lines
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_permission_390.png'),
    );
    await _end(tester, phone);
  });

  testWidgets('an expired chat is read-only, with a new chat in its folder', (
    tester,
  ) async {
    final expired = chat(
      'e',
      'claude',
      'Move the session store',
      status: ChatStatus(reopenFailed: true, sessionGone: true),
    );
    final fake = FakeDaemon([expired])
      ..answer = (input) => input is GetChatRequest
          ? GetChatResponse(
              chat: expired,
              status: expired.status,
              items: [
                Item(
                  id: 'u',
                  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                  text: 'Move the session store into its own package.',
                ),
              ],
            )
          : null;
    final (phone, _) = await _app(tester, fake);
    await tester.tap(find.text('Move the session store'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Read-only: Nushi’s copy of the transcript.'), findsOne);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_expired_390.png'),
    );
    await tester.tap(find.text('New chat here'));
    await tester.pumpAndSettle();
    // The New chat screen, its folder first.
    expect(find.text('Folder'), findsOne);
    expect(
      tester.getRect(find.textContaining('nushi', findRichText: true)).top,
      lessThan(
        tester
            .getRect(find.textContaining('No folder', findRichText: true))
            .top,
      ),
    );
    await _end(tester, phone);
  });

  // UX review, finding 19.
  testWidgets("the chat's ⋯: its folder, branch and model; Rename and "
      'Archive', (tester) async {
    final fake = FakeDaemon(_chats)
      ..answer = (input) => switch (input) {
        GetChatRequest() => GetChatResponse(
          chat: _chats[0],
          status: _chats[0].status,
          config: [
            ConfigOption(
              id: 'model',
              category: 'model',
              current: 'opus',
              values: [ConfigValue(value: 'opus', name: 'Opus 5.5')],
            ),
          ],
        ),
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'relay-fix',
        ),
        _ => null,
      };
    final (phone, _) = await _app(tester, fake);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('relay-fix'), findsOne);
    expect(find.text('Opus 5.5'), findsWidgets); // the box's picker too
    expect(find.text('nushi  /Users/me'), findsOne);
    expect(find.text('Pin'), findsOne); // the daemon keeps pins (API 90)
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_chat_sheet_390.png'),
    );
    await tester.tap(find.text('Rename…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Relay test fixed');
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<RenameChatRequest>().single.title,
      'Relay test fixed',
    );
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<ArchiveChatRequest>().single.chatId, 'a');
    await _end(tester, phone);
  });

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
      find.byType(TextField).last,
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
      find.byType(TextField).last,
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

  testWidgets('Forget this Mac that fails on the way keeps the pairing', (
    tester,
  ) async {
    // A key as X25519 keeps it (clamped): the record is this one's.
    final (phone, platform) = await _app(
      tester,
      FakeDaemon(_chats),
      record: {
        ..._paired(),
        'key': Uint8List(32)
          ..[0] = 8
          ..[31] = 64,
      },
    );
    platform.clearFails = StateError('storage');
    await expectLater(phone.forget(), throwsStateError);
    // Not forgotten: what keeps the pairing current still writes it (the
    // daemon's new id here), not shut off for the rest of the session.
    remoteState.value = Remote(rendezvous: 'moved');
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(platform.saved?['daemon'], 'moved');
    await _end(tester, phone);
  });

  testWidgets('a notification for a chat that is gone opens nothing', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats);
    final (phone, _) = await _app(tester, fake);
    expect(phone.daemon!.chatsListed, isTrue);
    phone.opening.value = 'gone';
    await tester.pump();
    expect(phone.opening.value, isNull, reason: 'not among the chats listed');
    // Chat events after it: each one used to double the daemon's
    // listeners (2^n calls; the page froze).
    for (var i = 0; i < 40; i++) {
      fake.emit(EventsResponse(chat: _chats[0]));
      await tester.pump();
    }
    expect(find.text('Chats'), findsOneWidget);
    // A chat that is there still opens.
    phone.opening.value = 'b';
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);
    expect(phone.opening.value, isNull);
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

  testWidgets('Scan: the camera reads the Mac’s code, then pairing starts', (
    tester,
  ) async {
    final (phone, platform) = await _app(
      tester,
      FakeDaemon(_chats),
      paired: false,
    );
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();
    expect(find.text('Scan the Mac’s code'), findsOneWidget);
    final scanner = Scanner.last!..see('https://example.com/');
    await tester.pump();
    await tester.pump();
    expect(find.text("That isn't a Nushi pairing code."), findsOneWidget);
    // A Nushi code (for another relay here, so pairing stops at once,
    // saying why: it was tried with what the camera read).
    scanner.see(
      'https://other.example/#pair?r=wss%3A%2F%2Fother.example&i=abc'
      '&k=${'A' * 43}&s=${'A' * 43}',
    );
    await tester.pumpAndSettle();
    expect(scanner.stopped, isTrue, reason: 'the camera is off');
    expect(find.text('Scan the Mac’s code'), findsNothing);
    expect(
      find.textContaining('This link is for the relay at'),
      findsOneWidget,
    );
    expect(phone.daemon, isNull);
    expect(platform.saved?['daemon'], isNull);
    await _end(tester, phone);
  });

  testWidgets('Scan: the camera refused says so', (tester) async {
    Scanner.refuse = 'Nushi may not use the camera.';
    addTearDown(() => Scanner.refuse = null);
    final (phone, _) = await _app(tester, FakeDaemon(_chats), paired: false);
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();
    expect(find.text('Nushi may not use the camera.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await tester.pumpAndSettle();
    expect(Scanner.last!.stopped, isTrue);
    await _end(tester, phone);
  });

  testWidgets('back from a chat: the chats have no back button', (
    tester,
  ) async {
    final fake = FakeDaemon(_chats)
      ..answer = (input) => input is GetChatRequest ? _question() : null;
    final (phone, _) = await _app(tester, fake);
    await tester.tap(find.text('Review the Noise channel'));
    await tester.pumpAndSettle();
    // The chats rebuild underneath while the chat shows (an event).
    phone.daemon!.notifyListeners();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    await _end(tester, phone);
  });
}
