import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connectrpc/connect.dart' show Transport;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';

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

/// [child] as a test shows a widget on its own: in a plain app in the
/// theme of [tokens], on a Scaffold. With [still], Reduce Motion is that
/// for it (the MediaQuery's disableAnimations), the window's MediaQuery
/// otherwise kept.
Widget themed(Widget child, {Tokens tokens = Tokens.dark, bool? still}) {
  final page = Scaffold(body: child);
  return MaterialApp(
    theme: NushiTheme(tokens).toThemeData(),
    home: still == null
        ? page
        : Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: still),
              child: page,
            ),
          ),
  );
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

/// A phone on [platform] (paired, as [pairedRecord] has it, unless given)
/// whose daemon answers through [fake], its app shown, started and pumped
/// a few frames. The window's size and the accessibility features (Reduce
/// Motion) stay the caller's to set.
Future<Phone> startPhone(
  WidgetTester tester,
  Transport fake, {
  PhonePlatform? platform,
}) async {
  final phone = Phone(
    platform ?? (PhonePlatform()..saved = pairedRecord()),
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  return phone;
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
/// AGENTS.md lists keep a window golden. It draws shadows as the app does:
/// a test paints each as a solid block (`debugDisableShadows`, which keeps
/// goldens the same from machine to machine), and a render is looked at,
/// so the window is painted again with real ones for the capture, then as
/// it was.
Future<void> render(WidgetTester tester, Finder of, String name) async {
  final dir = rendersDir;
  if (dir == null) return;
  await withRealShadows(tester, () async {
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
  });
}

/// Runs [body] with shadows drawn as the app draws them, then puts them
/// back as they were: for a picture that's looked at, never compared (a
/// render, the README's screenshots).
Future<void> withRealShadows(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final solid = debugDisableShadows;
  await _repaint(tester, solidShadows: false);
  try {
    await body();
  } finally {
    await _repaint(tester, solidShadows: solid);
  }
}

/// Paints everything on screen again with shadows solid or real: a shadow
/// is drawn as its box paints, and nothing else says it changed.
Future<void> _repaint(WidgetTester tester, {required bool solidShadows}) async {
  if (debugDisableShadows == solidShadows) return;
  debugDisableShadows = solidShadows;
  void again(RenderObject o) {
    o
      ..markNeedsPaint()
      ..visitChildren(again);
  }

  tester.binding.renderViews.forEach(again);
  await tester.pump();
}

/// Every text shown inside the window's [width]: none runs off its right
/// edge (a row too wide for a narrow window, or one pushed past it).
void expectTextInside(WidgetTester tester, double width) {
  for (final e in find.byType(RichText).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.hasSize) continue;
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    // An inline widget past its line's ellipsis is cut, and has no place.
    if (right.isNaN) continue;
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

/// A chat's preview tabs by name: a file's as its tab names it, a browser
/// tab's address.
extension PreviewNames on ChatState {
  List<String> get previewNames => [
    for (final e in previewTabs.value)
      switch (e) {
        PreviewFile(:final path) => path,
        final BrowserTab b => b.address.value,
      },
  ];
}
