import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  'relay': 'wss://relay.example.com',
  'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
  'daemonKey': Uint8List(32)..[0] = 9,
};

/// The folder `NUSHI_RENDERS` names, where [render] writes; null without it.
final String? rendersDir = switch (Platform.environment['NUSHI_RENDERS']) {
  final dir? when dir.isNotEmpty => dir,
  _ => null,
};

/// Writes what [of] shows (the window: `find.byType(NushiApp)`) as
/// `<name>.png` to [rendersDir], to look at a view at full size; nothing
/// without it. A render is never compared or committed: only the views
/// AGENTS.md lists keep a window golden.
Future<void> render(WidgetTester tester, Finder of, String name) async {
  final dir = rendersDir;
  if (dir == null) return;
  final capture = captureImage(of.evaluate().single);
  await tester.runAsync(() async {
    final image = await capture;
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// Every text shown inside the window's [width]: none runs off its right
/// edge (a row too wide for a narrow window, or one pushed past it).
void expectTextInside(WidgetTester tester, double width) {
  for (final e in find.byType(RichText).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.hasSize) continue;
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    expect(right, lessThanOrEqualTo(width + 0.5), reason: '${e.widget}');
  }
}

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
