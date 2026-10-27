import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart' show loadFonts;

/// A daemon that records the pairing answers and test pushes it gets.
class _Daemon implements Transport {
  final answers = <ConfirmPairingRequest>[];
  final tests = <SendTestPushRequest>[];

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    if (input is ConfirmPairingRequest) answers.add(input);
    if (input is SendTestPushRequest) tests.add(input);
    final out = input is StartPairingRequest
        ? StartPairingResponse(qr: _qr)
        : spec.outputFactory();
    return UnaryResponse(spec, Headers(), out as O, Headers());
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) => throw UnimplementedError();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a pairing the Mac didn't start still asks Allow or Deny", (
    tester,
  ) async {
    final daemon = _Daemon();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(),
      ),
    );
    watchPairings(navigator, NushiServiceClient(daemon));

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
      'https://nushi.aaronfrase.com/#pair?'
      'r=wss%3A%2F%2Fnushi.aaronfrase.com&i=id&k=key&s=secret',
    );
    expect(
      pairingLink('nushi://pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a'),
      'http://127.0.0.1:8099/#pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a',
    );
  });

  testWidgets('Pair a phone offers Copy link', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    remoteState.value = Remote(
      on: true,
      relay: 'wss://nushi.aaronfrase.com',
      pairing: Pairing(),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: RemoteSection(NushiServiceClient(_Daemon()))),
      ),
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(720, 560);
    addTearDown(tester.view.reset);
    await tester.tap(find.text('Pair a phone'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/remote_pair_link.png'),
    );
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, pairingLink(_qr));
    expect(find.text('Copied'), findsOneWidget);
  });

  // The section at a narrow and a wide Settings: each device's buttons at
  // the right edge, whatever the width.
  for (final (name, width, tokens) in [
    ('720_dark', 720.0, Tokens.dark),
    ('720_light', 720.0, Tokens.light),
    ('1700_dark', 1700.0, Tokens.dark),
  ]) {
    testWidgets('paired devices, kinds and notifications ($name)', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(width, 320);
      addTearDown(tester.view.reset);
      final daemon = _Daemon();
      remoteState.value = Remote(
        on: true,
        relay: 'wss://nushi.aaronfrase.com',
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
            // 3h ago, whenever the test runs.
            lastSeen: Int64(
              DateTime.now()
                  .subtract(const Duration(hours: 3))
                  .millisecondsSinceEpoch,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RemoteSection(NushiServiceClient(daemon)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Web · notifications on · connected'),
        findsOneWidget,
      );
      expect(
        find.textContaining(keyFingerprint(List.filled(32, 9))),
        findsOneWidget,
      );
      expect(
        find.textContaining('iPhone app · notifications off'),
        findsOneWidget,
      );
      for (final revoke in tester.widgetList(find.text('Revoke'))) {
        expect(
          tester.getRect(find.byWidget(revoke)).right,
          closeTo(width - 16 - 9, 6),
        );
      }
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

const _qr =
    'nushi://pair?r=wss%3A%2F%2Fnushi.aaronfrase.com&i=id&k=key&s=secret';
