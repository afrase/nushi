import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectrpc/connect.dart' show Transport;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';

import 'fake_daemon.dart';
import 'phone_native_fixture.dart';

/// The time the app sees in every test ([clock], set before each by
/// `flutter_test_config.dart`): fixed, so an age a golden shows never moves.
final fixtureNow = DateTime(2026, 10, 29, 12);

/// A test run on the Mac only.
final onMac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A test run on Linux only.
final onLinux = TargetPlatformVariant.only(TargetPlatform.linux);

/// A test run as on a phone (iOS): touch, a phone's text selection.
final onPhone = TargetPlatformVariant.only(TargetPlatform.iOS);

/// A test run on the Mac and again on Linux.
const macAndLinux = TargetPlatformVariant({
  TargetPlatform.macOS,
  TargetPlatform.linux,
});

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
/// theme of [tokens], on a Scaffold, with the window's toasts. With
/// [still], Reduce Motion is that for it (the MediaQuery's
/// disableAnimations), the window's MediaQuery otherwise kept. Without
/// [banner], no debug banner in its corner.
Widget themed(
  Widget child, {
  Tokens tokens = Tokens.dark,
  bool? still,
  bool banner = true,
}) {
  final page = Scaffold(body: child);
  return MaterialApp(
    debugShowCheckedModeBanner: banner,
    theme: NushiTheme(tokens).toThemeData(),
    builder: (context, child) => ToastHost(child: child!),
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

/// [count] frames, each [step] after the one before (none: at once): a
/// path frame by frame, or what never settles (a loop a test turns on,
/// `Shine.stopAt` null). A spinner and a turn's shine stand still in
/// tests (`flutter_test_config.dart`), so a view with one settles.
Future<void> frames(WidgetTester tester, int count, [Duration? step]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// [key] pressed with modifiers held, then settled, or one frame when
/// not [settle] (a test that looks at what the key did before it
/// settles, or pumps on its own). [cmd]
/// is the app's command key as `conventions` has it (⌘ on the Mac,
/// Control on Linux); [ctrl] is Control itself, [alt] Option (Alt).
Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool cmd = false,
  bool shift = false,
  bool alt = false,
  bool ctrl = false,
  bool settle = true,
}) async {
  final held = {
    if (ctrl) LogicalKeyboardKey.controlLeft,
    if (cmd)
      switch (conventions.commandKey) {
        CommandKey.meta => LogicalKeyboardKey.metaLeft,
        CommandKey.control => LogicalKeyboardKey.controlLeft,
      },
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (alt) LogicalKeyboardKey.altLeft,
  };
  for (final k in held) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in held.toList().reversed) {
    await tester.sendKeyUpEvent(k);
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// What the app puts on the clipboard, each text in the order copied; the
/// platform channel answers nothing else.
List<String> clipboardCopies(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  return copied;
}

/// The View menu's items in the menu bar, flattened, submenus as
/// themselves.
List<PlatformMenuItem> viewItems(WidgetTester tester) {
  final view = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == 'View');
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    _ => [m],
  };
  return view.menus.expand(items).toList();
}

/// [fixtureNow] less [d], as the daemon sends a time.
Int64 msAgo(Duration d) => Int64(fixtureNow.subtract(d).millisecondsSinceEpoch);

/// The app on [fake]'s chat `c`, connected, in a window of [size] in
/// [brightness] (the system's unless given), settled: the way most tests
/// open it. Prefs (details shown, the sidebar) stay the caller's to set,
/// since every test starts with them as at launch; a test that opens
/// another chat, or none, or doesn't settle, opens the app itself.
Future<Daemon> openApp(
  WidgetTester tester,
  FakeDaemon fake, {
  Size size = const Size(1700, 900),
  Brightness? brightness,
}) async {
  viewport(tester, size, brightness: brightness);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
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
/// a few frames, its chats' drafts kept as the phone keeps them, and no
/// native edge (`PhoneNative`: a native call fails the test, as it would
/// in the browser). The window's size and the accessibility features
/// (Reduce Motion) stay the caller's to set.
Future<Phone> startPhone(
  WidgetTester tester,
  Transport fake, {
  PhonePlatform? platform,
}) async {
  native = PhoneNative();
  late final Phone phone;
  phone = Phone(
    platform ?? (PhonePlatform()..saved = pairedRecord()),
    connectTo: (_) =>
        Daemon(transport: fake, remote: true, drafts: phone.drafts),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  await frames(tester, 8);
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

/// Whether this run writes renders (`make renders` sets NUSHI_RENDERS).
bool get rendering => rendersDir != null;

/// The themes a check runs in: dark, and light too only when [rendering].
/// A theme changes colours, not layout, so a light copy of a check proves
/// nothing the dark run didn't; only its picture differs. A test that
/// asserts a theme's colours, or compares a golden in each, loops over
/// `Brightness.values` itself.
List<Brightness> get renderThemes =>
    rendering ? Brightness.values : const [Brightness.dark];

/// Whether a test in [b] is a light copy that only a render needs: true
/// for light when not [rendering] (as [renderThemes]), for a loop that
/// also takes goldens and can't drop light as a whole.
bool lightCopy(Brightness b) => b == Brightness.light && !rendering;

/// A test that only draws pictures ([render]) and checks nothing a test
/// run without them doesn't: registered only when [rendering], so CI and
/// `make check` don't build a window for nothing, and nothing shows as
/// skipped. A check goes in an ordinary test.
void renderTest(
  String name,
  WidgetTesterCallback body, {
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  if (!rendering) {
    // A file of only these still runs its setUpAll (loadFonts), which
    // needs the binding a testWidgets would have made.
    TestWidgetsFlutterBinding.ensureInitialized();
    return;
  }
  testWidgets(name, body, variant: variant);
}

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

/// The window narrowed from [from] to [to] (each 900 high), [check]
/// run at each width laid out, as a point at a time would, at a fraction
/// of the layouts: every 8th width, then every width between two
/// whose widget tree differs (a part folded, a pane gone), where the
/// layout jumps rather than glides. Those are walked in an app [reopen]
/// builds again at [from], so every width is still reached narrowing.
/// Between two that agree the layout only glides, so what goes wrong
/// there (an overflow, a part under another) shows at the narrower one.
Future<void> narrowing(
  WidgetTester tester, {
  required double from,
  required double to,
  required void Function(double width) check,
  required Future<void> Function() reopen,
}) async {
  const height = 900.0;
  const step = 8.0;
  Future<int> at(double w) async {
    viewport(tester, Size(w, height));
    await tester.pump();
    check(w);
    return _treeShape(tester);
  }

  final jumps = <(double, double)>[];
  var wider = from;
  var shape = await at(from);
  while (wider > to) {
    final w = wider - step < to ? to : wider - step;
    final next = await at(w);
    if (next != shape && wider - w > 1) jumps.add((wider, w));
    (wider, shape) = (w, next);
  }
  if (jumps.isEmpty) return;
  await reopen();
  for (final (a, b) in jumps) {
    for (var w = a - 1; w > b; w--) {
      await at(w);
    }
  }
}

/// The widget tree's shape: each element's widget type, in order.
int _treeShape(WidgetTester tester) {
  var hash = 0;
  void visit(Element e) {
    hash = Object.hash(hash, e.widget.runtimeType);
    e.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return hash;
}

/// A chat's file tabs, as each names its file, and its browser tabs, by
/// address.
extension TabNames on ChatState {
  List<String> get fileNames => [for (final f in files.tabs.value) f.path];
  List<String> get browserNames => [
    for (final b in browser.tabs.value) b.address.value,
  ];
}

/// The label of the [Button] that has the keyboard's focus.
String? focusedButton(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  final button = find.ancestor(
    of: find.byWidget(focused.widget),
    matching: find.byType(Button),
  );
  return button.evaluate().isEmpty
      ? null
      : tester.widget<Button>(button.first).label;
}
