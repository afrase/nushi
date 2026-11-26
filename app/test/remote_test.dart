import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show Toggle;
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'harness.dart';

/// A daemon that answers a pairing with [_qr]; it records the pairing
/// answers and test pushes it gets.
FakeDaemon _daemon() =>
    FakeDaemon([])
      ..answer = (input) =>
          input is StartPairingRequest ? StartPairingResponse(qr: _qr) : null;

extension on FakeDaemon {
  Iterable<ConfirmPairingRequest> get answers => calls.whereType();
  Iterable<SendTestPushRequest> get tests => calls.whereType();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a pairing the Mac didn't start still asks Allow or Deny", (
    tester,
  ) async {
    final daemon = _daemon();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(),
      ),
    );
    addTearDown(watchPairings(navigator, NushiServiceClient(daemon)));

    remoteState.value = Remote(on: true, pairing: Pairing());
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsNothing); // no phone yet

    remoteState.value = Remote(
      on: true,
      pairing: Pairing(name: 'Phone', code: '123 456'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pair Phone?'), findsOneWidget);
    expect(find.text('123 456'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
    expect(daemon.answers.single.allow, isFalse);
    expect(find.text('Allow'), findsNothing);

    // A pairing that ends before an answer: a new code is the user's call.
    remoteState.value = Remote(
      on: true,
      pairing: Pairing(name: 'Phone', code: '654 321'),
    );
    await tester.pumpAndSettle();
    remoteState.value = Remote(on: true);
    await tester.pumpAndSettle();
    expect(find.text('This code is used up or has expired.'), findsOneWidget);
    expect(find.text('New code'), findsOneWidget);
  });

  test("the pairing link: the relay's web app, the code in the fragment", () {
    expect(
      pairingLink(_qr),
      'https://relay.example.com/#pair?'
      'r=wss%3A%2F%2Frelay.example.com&i=id&k=key&s=secret',
    );
    expect(
      pairingLink('nushi://pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a'),
      'http://127.0.0.1:8099/#pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a',
    );
  });

  testWidgets('Keeps the Mac awake is a line of its own, never run into '
      "the relay's error (issue 119)", (tester) async {
    viewport(tester, const Size(720, 560));
    await tester.pumpWidget(
      themed(RemoteSection(NushiServiceClient(_daemon())), banner: false),
    );
    remoteState.value = Remote(on: true, state: 'connected');
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Keeps the Mac awake'), findsOneWidget);
    remoteState.value = Remote(
      on: true,
      state: 'error',
      error: 'dial tcp: lookup relay.example.com: no such host',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Can't reach the relay: dial tcp: lookup relay.example.com: no such "
        'host (trying again)',
      ),
      findsOneWidget,
    );
    expect(find.text('Keeps the Mac awake'), findsOneWidget);
    await render(tester, find.byType(MaterialApp), 'remote_error_720');
    await tester.pumpWidget(const SizedBox());
  }, variant: onMac);

  testWidgets('the relay field fills when the daemon first answers; turning '
      'off sends the saved relay, not what the field holds', (tester) async {
    final daemon = _daemon()
      ..on((input) => input is SetRemoteRequest ? SetRemoteResponse() : null);
    viewport(tester, const Size(720, 560));
    await tester.pumpWidget(
      themed(RemoteSection(NushiServiceClient(daemon)), banner: false),
    );
    remoteState.value = Remote(on: true, relay: 'wss://relay.example.com');
    await tester.pumpAndSettle();
    expect(find.text('wss://relay.example.com'), findsOneWidget);
    // An edit never submitted is the user's still, not the daemon's.
    await tester.enterText(find.byType(TextField), 'wss://half');
    remoteState.value = Remote(on: true, relay: 'wss://relay.example.com');
    await tester.pumpAndSettle();
    expect(find.text('wss://half'), findsOneWidget);
    await tester.tap(find.byType(Toggle));
    await tester.pumpAndSettle();
    final sent = daemon.calls.whereType<SetRemoteRequest>().single;
    expect(sent.on, isFalse);
    expect(sent.relay, 'wss://relay.example.com');
  });

  testWidgets('Pair a phone offers Copy link', (tester) async {
    final copied = clipboardCopies(tester);
    remoteState.value = Remote(
      on: true,
      relay: 'wss://relay.example.com',
      pairing: Pairing(),
    );
    await tester.pumpWidget(
      themed(RemoteSection(NushiServiceClient(_daemon())), banner: false),
    );
    viewport(tester, const Size(720, 560));
    await tester.tap(find.text('Pair a phone'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/remote_pair_link.png'),
    );
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied.last, pairingLink(_qr));
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets("Copy link copies the daemon's link, built from the QR only "
      'for an older daemon', (tester) async {
    final copied = clipboardCopies(tester);
    const link = 'https://relay.example.com/#pair?from=daemon';
    for (final (answer, want) in [
      (StartPairingResponse(qr: _qr, link: link), link),
      (StartPairingResponse(qr: _qr), pairingLink(_qr)), // v0.53.0-beta.7
    ]) {
      remoteState.value = Remote(
        on: true,
        relay: 'wss://relay.example.com',
        pairing: Pairing(),
      );
      final daemon = FakeDaemon([])
        ..answer = (input) => input is StartPairingRequest ? answer : null;
      await tester.pumpWidget(
        themed(RemoteSection(NushiServiceClient(daemon)), banner: false),
      );
      await tester.tap(find.text('Pair a phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied.last, want);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
    }
  });

  // The section at a narrow and a wide Settings: each device's buttons at
  // the right edge, whatever the width.
  for (final (name, width, tokens) in [
    ('720_dark', 720.0, Tokens.dark),
    ('720_light', 720.0, Tokens.light),
    ('1700_dark', 1700.0, Tokens.dark),
  ]) {
    testWidgets('paired devices and notifications ($name)', (tester) async {
      viewport(tester, Size(width, 440));
      final daemon = _daemon();
      remoteState.value = Remote(
        on: true,
        relay: 'wss://relay.example.com',
        state: 'connected',
        key: List.filled(32, 9),
        devices: [
          Device(
            id: 'w',
            name: 'iPhone',
            kind: 'web',
            push: true,
            connected: true,
          ),
          Device(
            id: 'a',
            name: 'Test phone',
            // 3h before the tests' clock.
            lastSeen: Int64(
              fixtureNow
                  .subtract(const Duration(hours: 3))
                  .millisecondsSinceEpoch,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        themed(
          Padding(
            padding: const EdgeInsets.all(16),
            child: RemoteSection(NushiServiceClient(daemon)),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications on, connected'), findsOneWidget);
      expect(
        find.textContaining(keyFingerprint(List.filled(32, 9))),
        findsOneWidget,
      );
      expect(
        find.text('Notifications off, 3h ago'), // no kind, though it's ""
        findsOneWidget,
      );
      expect(find.text('Revoke'), findsNWidgets(2)); // a device's each
      for (final revoke in tester.widgetList(find.text('Revoke'))) {
        expect(
          tester.getRect(find.byWidget(revoke)).right,
          closeTo(
            width - 16 - 14 - 12,
            1,
          ), // the group's edge, a row's and the button's padding
        );
      }
      await render(tester, find.byType(MaterialApp), 'remote_devices_$name');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/remote_devices_$name.png'),
      );
      await tester.tap(find.text('Send a test notification').first);
      await tester.pump();
      expect(daemon.tests.single.deviceId, 'w');
      await tester.tap(find.text('Send a test notification').last); // off there
      await tester.pump();
      expect(daemon.tests, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

const _qr = 'nushi://pair?r=wss%3A%2F%2Frelay.example.com&i=id&k=key&s=secret';
