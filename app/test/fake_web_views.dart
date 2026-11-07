import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/web_views_macos.dart';

/// The web views as a test has them (ADR 0097): what it sets, and the
/// Mac's for the rest, whose channels tests leave unanswered.
class FakeWebViews implements WebViews {
  /// Makes a file preview's host.
  PageHost Function()? newPage;

  /// Makes a browser tab's host.
  BrowserHost Function(BrowserTab tab)? newTab;

  /// Makes a Mermaid file's host.
  DiagramHost Function()? newDiagram;

  /// Opens an address in the default browser.
  Future<void> Function(Uri url)? open;

  /// Says how long ago the user pressed in a page.
  Future<Duration?> Function({bool pointerOnly})? since;

  /// Names the default browser.
  Future<String?> Function()? browserName;

  /// Clears the web views' data.
  Future<void> Function()? clear;

  static const _mac = MacWebViews();

  @override
  PageHost page() => newPage?.call() ?? _mac.page();

  @override
  BrowserHost tab(BrowserTab tab) => newTab?.call(tab) ?? _mac.tab(tab);

  @override
  DiagramHost diagram() => newDiagram?.call() ?? _mac.diagram();

  @override
  Future<void> openInBrowser(Uri url) =>
      open?.call(url) ?? _mac.openInBrowser(url);

  @override
  Future<Duration?> sincePress({bool pointerOnly = false}) =>
      since?.call(pointerOnly: pointerOnly) ??
      _mac.sincePress(pointerOnly: pointerOnly);

  @override
  Future<String?> defaultBrowserName() =>
      browserName?.call() ?? _mac.defaultBrowserName();

  @override
  Future<void> clearData() => clear?.call() ?? _mac.clearData();
}

/// The test's [FakeWebViews], put in the Mac's place the first time it's
/// asked for (each test starts from the Mac's).
FakeWebViews fakeWebViews() => switch (native.web) {
  final FakeWebViews f => f,
  _ => native.web = FakeWebViews(),
};
