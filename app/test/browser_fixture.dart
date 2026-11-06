import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/web_page.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The browser tab's tests' fakes and helpers (ADR 0094): a page host that
// loads nothing, the app with a chat to open tabs in, and the address field.

/// The tests' platform: browser tabs are the Mac's.
final macOnly = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A page host that loads nothing: it says what it was asked and plays a
/// page's part (its address, a title, Back once it moved). What WebKit says
/// as a page moves goes through the app's own [PageAddress], as
/// `BrowserPage`'s does: [urlChanged] and [committed].
class FakeBrowserHost implements BrowserHost {
  new(this.tab) : _page = PageAddress(tab);

  final BrowserTab tab;
  final PageAddress _page;
  final opened = <Uri>[];
  int reloads = 0;
  final _back = ValueNotifier<bool>(false);
  final _forward = ValueNotifier<bool>(false);

  /// Why the page didn't load, as a test says.
  final failure = ValueNotifier<PageFailure?>(null);

  /// A local address the page went for, refused, as a test says.
  final blocked = ValueNotifier<Uri?>(null);

  @override
  ValueListenable<Uri?> get blockedLocal => blocked;

  @override
  ValueListenable<bool> get canBack => _back;
  @override
  ValueListenable<bool> get canForward => _forward;
  @override
  ValueListenable<PageFailure?> get failed => failure;

  @override
  Widget view(BuildContext context) => const _Page();

  @override
  Future<void> open(Uri url) async {
    opened.add(url);
    tab.address.value = '$url';
    committed('$url');
    tab.title.value = 'Tea shop · dev';
    _back.value = opened.length > 1;
  }

  /// WebKit's URL moved to [url] (a navigation starting, or the page's own
  /// history).
  void urlChanged(String url) => _page.changed(url);

  /// A load committed at [url].
  void committed(String url) => _page.committed(url);

  @override
  Future<void> reload() async => reloads++;

  /// How many times the page's picture was taken.
  int snapshots = 0;

  @override
  Future<Uint8List> snapshot() async {
    snapshots++;
    return fakePng;
  }

  @override
  Future<void> back() async {}

  @override
  Future<void> forward() async {}

  @override
  void dispose() {}
}

/// A page's picture as the fakes take it: a PNG of one white pixel.
final Uint8List fakePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/'
  'PchI7wAAAABJRU5ErkJggg==',
);

/// A page as a dev server might draw it: a heading and a line on white.
class _Page extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFFFFF),
    // Cut at the pane's bottom, as a page is.
    child: SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              'Tea shop',
              style: TextStyle(fontSize: 28, color: Color(0xFF1B1B1F)),
            ),
            Text(
              'Fresh leaves, roasted this morning.',
              style: TextStyle(fontSize: 14, color: Color(0xFF55555F)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The default browser's name the fakes give, as the Mac's might.
const browserName = 'Google Chrome';

/// What the fakes' Mac says the default browser is from now on, until the
/// test ends ([browserName] at first; null: it can't say).
void defaultBrowserNameIs(String? name) => _browserName = name;
String? _browserName = browserName;

/// The hosts made, and the addresses sent to the default browser, while
/// the test runs; the default browser is [browserName].
({List<FakeBrowserHost> hosts, List<Uri> opened}) browserFakes() {
  final hosts = <FakeBrowserHost>[];
  final opened = <Uri>[];
  final (wasHost, wasOpen, wasName) = (
    newBrowserHost,
    openInBrowser,
    defaultBrowserName,
  );
  newBrowserHost = (tab) {
    final h = FakeBrowserHost(tab);
    hosts.add(h);
    return h;
  };
  openInBrowser = (url) async => opened.add(url);
  defaultBrowserName = () async => _browserName;
  addTearDown(() {
    newBrowserHost = wasHost;
    openInBrowser = wasOpen;
    defaultBrowserName = wasName;
    defaultBrowser.value = null;
    _browserName = browserName;
  });
  return (hosts: hosts, opened: opened);
}

/// The app on chat c (d beside it), at [width].
Future<Daemon> browserApp(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final fake =
      FakeDaemon([
          chat('c', 'claude', 'Build the tea shop'),
          chat('d', 'codex', 'Fix the cart', age: 5),
        ])
        ..answer = ((input) =>
            input is GetChatRequest ? GetChatResponse() : null)
        // A file's preview: its text, the stream open until the test ends.
        ..streams = (input) {
          if (input is! WatchChatFileRequest) return null;
          const text = '# The plan\n\nBrew, then pour.\n';
          final s = StreamController<WatchChatFileResponse>()
            ..add(
              WatchChatFileResponse(
                path: '/Users/me/nushi/${input.path}',
                data: utf8.encode(text),
                size: Int64(text.length),
              ),
            );
          addTearDown(s.close);
          return s.stream;
        };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> pressMeta(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

Finder get addressField => find.descendant(
  of: find.byType(BrowserBar),
  matching: find.byType(TextField),
);

/// The address field's box, its border and fill: where it lies.
Finder get addressBox => find.byKey(BrowserBar.fieldKey);

Future<void> typeAddress(WidgetTester tester, String text) async {
  await tester.enterText(addressField, text);
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pumpAndSettle();
}

EditableTextState addressEditable(WidgetTester tester) =>
    tester.state<EditableTextState>(
      find.descendant(of: addressField, matching: find.byType(EditableText)),
    );
