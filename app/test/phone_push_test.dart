import 'dart:convert';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/subscription.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The phone's notifications as the daemon holds them: the switch reads On
// only while the daemon has the browser's subscription.

const _vapid =
    'BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIg'
    'Dll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8';

final _sub = PushSub(
  'https://web.push.apple.com/QGuQyav',
  Uint8List(65)..[0] = 4,
  Uint8List(16),
);

/// A daemon with a VAPID key whose SetPushSubscription fails while
/// [failing] says so.
FakeDaemon _fake(bool Function() failing) =>
    FakeDaemon(const [])
      ..answer = (input) => switch (input) {
        GetPushKeyRequest() => GetPushKeyResponse(key: _vapid),
        SetPushSubscriptionRequest() when failing() => throw ConnectException(
          Code.unavailable,
          'the link dropped',
        ),
        _ => null,
      };

void main() {
  testWidgets('turned on, a subscription the daemon never got is turned '
      'off again', (tester) async {
    var failing = true;
    final fake = _fake(() => failing);
    final platform = PhonePlatform()
      ..saved = pairedRecord()
      ..sub = _sub;
    final phone = await startPhone(tester, fake, platform: platform);
    expect(await phone.setPush(on: true), contains('the link dropped'));
    expect((phone.push, platform.push), (PushState.off, PushState.off));
    failing = false;
    expect(await phone.setPush(on: true), isNull);
    expect(phone.push, PushState.on);
    await endPhone(tester, phone);
  });

  testWidgets('turned off, it reads Off though the daemon was not told', (
    tester,
  ) async {
    final fake = _fake(() => true);
    final platform = PhonePlatform()..saved = pairedRecord();
    final phone = await startPhone(tester, fake, platform: platform);
    platform.push = phone.push = PushState.on;
    expect(await phone.setPush(on: false), contains('the link dropped'));
    expect(phone.push, PushState.off);
    await endPhone(tester, phone);
  });

  testWidgets("each connection sends the browser's subscription again", (
    tester,
  ) async {
    final fake = _fake(() => false);
    final platform = PhonePlatform()
      ..saved = pairedRecord()
      ..push = PushState.on
      ..subscribedKey = base64Url.decode(base64Url.normalize(_vapid))
      ..sub = _sub;
    final phone = await startPhone(tester, fake, platform: platform);
    final sent = fake.calls.whereType<SetPushSubscriptionRequest>().single;
    expect(sent.endpoint, _sub.endpoint);
    expect(sent.p256dh, _sub.p256dh);
    expect(sent.auth, _sub.auth);
    expect(phone.push, PushState.on);
    await endPhone(tester, phone);
  });
}
