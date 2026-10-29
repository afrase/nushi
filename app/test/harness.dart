import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/phone.dart';

/// The time the app sees in every test ([clock], set before each by
/// `flutter_test_config.dart`): fixed, so an age a golden shows never moves.
final fixtureNow = DateTime(2026, 10, 29, 12);

/// The test's window: [size] in logical pixels, [ratio] device pixels to
/// one, the system in [brightness] when given; as it was after the test.
void viewport(
  WidgetTester tester,
  Size size, {
  double ratio = 1,
  Brightness? brightness,
}) {
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = size * ratio;
  addTearDown(tester.view.reset);
  if (brightness == null) return;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Takes the app away and disposes [d], so its timers end with the test.
Future<void> closeView(WidgetTester tester, Daemon d) async {
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

/// Closes [phone] and takes its app away, then lets [wait] pass for the
/// timers that outlive it (a reconnect's backoff).
Future<void> endPhone(
  WidgetTester tester,
  Phone phone, {
  Duration wait = const Duration(seconds: 5),
}) async {
  await phone.close();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(wait);
}

/// A paired browser: what IndexedDB would hold.
Map<String, Object?> pairedRecord() => {
  'key': Uint8List(32)..[0] = 7,
  'name': 'iPhone',
  'relay': 'wss://nushi.aaronfrase.com',
  'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
  'daemonKey': Uint8List(32)..[0] = 9,
};

/// Lets real time pass, pumping between looks, until [done]: for work the
/// test's fake clock doesn't wait for (an isolate's). Fails after [limit].
Future<void> untilReal(
  WidgetTester tester,
  bool Function() done, {
  Duration limit = const Duration(seconds: 10),
}) async {
  const step = Duration(milliseconds: 10);
  for (var waited = Duration.zero; !done(); waited += step) {
    if (waited >= limit) fail('not done after $limit');
    await tester.runAsync(() => Future<void>.delayed(step));
    await tester.pump();
  }
}
