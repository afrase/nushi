// The phone's web app's client logic in a browser (ADR 0054), end to end:
// the browser's WebSocket to a real nushi-relay (which takes this page's
// origin only because it serves a web app at it), Noise in dart2js, the
// device key and pairing in IndexedDB, the Daemon on the relay, and Web
// Push's subscription kept with the device. The Mac's side runs in the VM
// (mac_side.dart). Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/platform.dart';
import 'package:web/web.dart' as web;

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 400; i++) {
    if (ok()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('waited too long');
}

/// A zone whose calls' failures after their connection ended are expected.
final Zone _dying = Zone.current.fork(
  specification: ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stack) {
      if (!'$error'.contains('forcefully terminated')) {
        parent.handleUncaughtError(zone, error, stack);
      }
    },
  ),
);

void main() {
  // Links end on the way (as when the page goes): what was in flight on
  // them fails then, in _dying.
  test(
    'pair, chat, answer, subscribe, come back, forget',
    () => _dying.run(() async {
      final mac = spawnHybridUri(
        'mac_side.dart',
        message: web.window.location.origin,
      );
      final from = StreamQueue(mac.stream);
      Future<Map<String, Object?>> next() async {
        final m = (await from.next as Map).cast<String, Object?>();
        if (m['error'] case final e?) fail('the Mac side: $e');
        return m;
      }

      final setup = await next();
      final platform = PhonePlatform();
      await platform.clear();
      final phone = Phone(platform, sameRelay: false);
      await phone.start();
      expect(phone.paired, isNull);

      // Pairing: the code on the phone is the one the Mac allows.
      final paired = phone.pair(setup['link']! as String, 'Test browser');
      await _until(() => phone.pairing != null);
      mac.sink.add({'do': 'confirm', 'code': phone.pairing!.code});
      expect((await next())['allowed'], isTrue);
      await paired;
      final daemon = phone.daemon!;
      await _until(() => daemon.connected);

      // A chat, a prompt, a permission card answered.
      await daemon.startChat(setup['folder']! as String, 'claude');
      final chat = daemon.selected!;
      await daemon.client.sendPrompt(
        SendPromptRequest(chatId: chat.id, text: 'permission please'),
      );
      await _until(() => chat.waiting);
      final card = chat.items.lastWhere(
        (i) => i.kind == ItemKind.ITEM_KIND_PERMISSION,
      );
      await daemon.client.answerPermission(
        AnswerPermissionRequest(
          chatId: chat.id,
          itemId: card.id,
          optionId: 'allow',
        ),
      );
      await _until(
        () => chat.items.any((i) => i.text.contains('Permission: selected')),
      );

      // Notifications: the browser's subscription, kept with the device;
      // one off the allowlist is refused.
      await expectLater(
        daemon.client.setPushSubscription(
          SetPushSubscriptionRequest(
            endpoint: 'https://evil.example.com/push',
            p256dh: _p256,
            auth: List.filled(16, 1),
          ),
        ),
        throwsA(anything),
      );
      await daemon.client.setPushSubscription(
        SetPushSubscriptionRequest(
          endpoint: 'https://web.push.apple.com/QGuQyav',
          p256dh: _p256,
          auth: List.filled(16, 1),
        ),
      );
      await daemon.client.setDeviceView(SetDeviceViewRequest(chatId: chat.id));
      mac.sink.add({'do': 'devices'});
      final devices = await next();
      expect(devices['file'], contains('"kind": "web"'));
      expect(devices['file'], contains('web.push.apple.com'));
      expect(devices['remote'], contains('"push":true'));

      // The app comes back: its key and pairing from IndexedDB.
      await phone.close();
      final again = Phone(PhonePlatform(), sameRelay: false);
      await again.start();
      expect(again.paired?.id, phone.paired!.id);
      await _until(() => again.daemon!.connected);
      await _until(() => again.daemon!.chats.containsKey(chat.id));

      // Forget this Mac: nothing kept.
      await again.forget();
      final empty = Phone(PhonePlatform());
      await empty.start();
      expect(empty.paired, isNull);

      mac.sink.add({'do': 'done'});
      await next();
    }),
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

// RFC 8291's browser key: a P-256 point.
final _p256 = [
  0x04,
  0x25,
  0x71,
  0xb2,
  0xbe,
  0xcd,
  0xfd,
  0xe3,
  0x60,
  0x55,
  0x1a,
  0xaf,
  0x1e,
  0xd0,
  0xf4,
  0xcd,
  0x36,
  0x6c,
  0x11,
  0xce,
  0xbe,
  0x55,
  0x5f,
  0x89,
  0xbc,
  0xb7,
  0xb1,
  0x86,
  0xa5,
  0x33,
  0x39,
  0x17,
  0x31,
  0x68,
  0xec,
  0xe2,
  0xeb,
  0xe0,
  0x18,
  0x59,
  0x7b,
  0xd3,
  0x04,
  0x79,
  0xb8,
  0x6e,
  0x3c,
  0x8f,
  0x8e,
  0xce,
  0xd5,
  0x77,
  0xca,
  0x59,
  0x18,
  0x7e,
  0x92,
  0x46,
  0x99,
  0x0d,
  0xb6,
  0x82,
  0x00,
  0x8b,
  0x0e,
];
