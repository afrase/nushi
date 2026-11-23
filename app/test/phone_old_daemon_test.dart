// The phone against a daemon below the app's floor (ADR 0004): never
// blocked, a bar under the connection's saying to update it on the Mac,
// and a call the old daemon lacks failing with those words, at iPhone
// sizes upright and on its side.
import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _words = 'Open Nushi on your Mac to update its daemon';

/// iPhones: the screen and its insets (the notch's side on its side).
const _phones = {
  '390': (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  '430': (Size(430, 932), EdgeInsets.only(top: 59, bottom: 34)),
  'landscape': (
    Size(844, 390),
    EdgeInsets.only(left: 47, right: 47, bottom: 21),
  ),
};

/// A daemon at [api] whose PinChats it doesn't know (Unimplemented, as a
/// daemon older than a call answers it).
FakeDaemon _daemon(int api) =>
    FakeDaemon([
        chat('a', 'claude', 'Fix the flaky relay test'),
        chat('b', 'codex', 'Review the Noise channel', age: 5),
      ])
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(apiVersion: api),
        PinChatsRequest() => throw connect.ConnectException(
          connect.Code.unimplemented,
          'nushi.v1.NushiService/PinChats is not implemented',
        ),
        _ => null,
      };

Future<Phone> _app(
  WidgetTester tester,
  FakeDaemon fake, {
  String phone = '390',
  Brightness b = Brightness.dark,
}) async {
  final (size, pad) = _phones[phone]!;
  final insets = FakeViewPadding(
    left: pad.left * 2,
    top: pad.top * 2,
    right: pad.right * 2,
    bottom: pad.bottom * 2,
  );
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2
    ..padding = insets
    ..viewPadding = insets;
  tester.platformDispatcher
    ..platformBrightnessTestValue = b
    ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final p = await startPhone(tester, fake);
  await tester.pumpAndSettle();
  return p;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('below the floor the phone says to update the daemon on the '
      'Mac, and works on', (tester) async {
    final p = await _app(tester, _daemon(apiFloor - 1));
    expect(find.byType(OldDaemonBar), findsOne);
    expect(find.text(_words), findsOne);
    // Never blocked: the chats are there, and open.
    expect(find.text('Fix the flaky relay test'), findsOne);
    final bar = tester.getRect(find.text(_words));
    final heading = tester.getRect(find.text('Chats').first);
    expect(bar.top, greaterThan(heading.bottom)); // under the header
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    expect(find.text(_words), findsOne); // in the chat too
    await endPhone(tester, p);
  }, variant: onPhone);

  for (final api in [apiFloor, apiVersion]) {
    testWidgets('a daemon at API $api, at or above the floor, gets no bar', (
      tester,
    ) async {
      final p = await _app(tester, _daemon(api));
      expect(find.text('Fix the flaky relay test'), findsOne);
      expect(find.text(_words), findsNothing);
      await endPhone(tester, p);
    }, variant: onPhone);
  }

  // Between the floor and the app's own API a call can still be missing:
  // it says the same, with no bar; a daemon as new as the app keeps its
  // own words for an Unimplemented (a call its system lacks).
  for (final (api, says) in [
    (apiFloor - 1, _words),
    (apiFloor, _words),
    (apiVersion, 'nushi.v1.NushiService/PinChats is not implemented'),
  ]) {
    testWidgets('a call a daemon at API $api lacks fails as "$says"', (
      tester,
    ) async {
      final p = await _app(tester, _daemon(api));
      final context = tester.element(find.text('Fix the flaky relay test'));
      await tryOrShow(
        context,
        () => p.daemon!.client.pinChats(PinChatsRequest()),
      );
      await tester.pump();
      expect(find.text(says), findsWidgets);
      await tester.pump(const Duration(seconds: 10)); // the toast goes
      await endPhone(tester, p);
    }, variant: onPhone);
  }

  testWidgets('the Mac never says it: its daemon updates with the app', (
    tester,
  ) async {
    final fake = _daemon(apiFloor);
    final d = Daemon(transport: fake);
    await d.ping();
    expect(
      errorText(connect.ConnectException(connect.Code.unimplemented, 'no')),
      'no',
    );
    d.dispose();
  });

  for (final phone in _phones.keys) {
    for (final b in renderThemes) {
      testWidgets('the bar ($phone, ${b.name})', (tester) async {
        final p = await _app(tester, _daemon(apiFloor - 1), phone: phone, b: b);
        final (size, pad) = _phones[phone]!;
        final bar = tester.getRect(find.byType(OldDaemonBar));
        // Across the screen, inside its safe area.
        expect(bar.left, pad.left);
        expect(bar.right, size.width - pad.right);
        expect(bar.top, greaterThanOrEqualTo(pad.top));
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(PhoneApp),
          'phone_old_daemon_${phone}_${b.name}',
        );
        await endPhone(tester, p);
      }, variant: onPhone);
    }
  }
}
