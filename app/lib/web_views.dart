import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';

/// Where the app's web views come from, and the default browser (ADR 0068,
/// 0094, 0097): on the Mac, WKWebViews and the Swift side
/// (`web_views_macos.dart`).
abstract interface class WebViews {
  /// A web view for a file's preview.
  PageHost page();

  /// A web view for browser tab [tab].
  BrowserHost tab(BrowserTab tab);

  /// A web view for a Mermaid file's preview.
  DiagramHost diagram();

  /// Opens [url] in the default browser: http(s) and file addresses with
  /// the app that opens https, so a file is never run by the app its type
  /// has; mail with the mail app. Any other address goes nowhere.
  Future<void> openInBrowser(Uri url);

  /// How long ago the user last pressed, let go, or hit Return, Enter or
  /// Space in a web view in the window, null if never or since the last
  /// ask (each press lets one navigation out); with [pointerOnly], null
  /// too when the last was a key. Flutter doesn't see it: the web view
  /// takes a press inside it.
  Future<Duration?> sincePress({bool pointerOnly = false});

  /// The default browser's name ("Google Chrome"), or null when the
  /// system can't say.
  Future<String?> defaultBrowserName();

  /// Removes every site's data from the store browser tabs and file
  /// previews share (cookies, storage, caches).
  Future<void> clearData();
}
