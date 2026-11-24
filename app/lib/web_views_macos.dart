import 'package:flutter/services.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/browser_page_macos.dart' as browser;
import 'package:nushi/diagram_page.dart';
import 'package:nushi/diagram_page_macos.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_page_macos.dart';
import 'package:nushi/web_views.dart';
import 'package:url_launcher/url_launcher.dart';

const _browser = MethodChannel('nushi/browser');

/// The Mac's web views, WKWebViews, and its default browser, through the
/// Swift side's `nushi/browser` channel
/// (`macos/Runner/Browser.swift`).
class MacWebViews implements WebViews {
  const new();

  @override
  bool get embedded => true;

  @override
  PageHost page() => WebKitPage();

  @override
  BrowserHost tab(BrowserTab tab) => browser.BrowserPage(tab);

  @override
  DiagramHost diagram() => WebKitDiagram();

  /// The Swift side opens it with the app that opens https, refusing any
  /// scheme but http, https and file, and says why it couldn't:
  /// `no-browser` when nothing opens https, `failed` (with macOS's reason)
  /// or `refused` otherwise, as Linux's runner does.
  @override
  Future<void> openWithBrowser(Uri url) async {
    try {
      await _browser.invokeMethod<void>('open', '$url');
    } on PlatformException catch (e) {
      throw BrowserError(switch (e.code) {
        'no-browser' =>
          'No default browser is set: choose one in your system’s settings.',
        _ => 'Couldn’t open your browser: ${e.message ?? e.code}',
      });
    }
  }

  @override
  Future<void> openMail(Uri url) => launchUrl(url);

  /// The Swift side's event monitor sees the presses (the plugin doesn't
  /// give WebKit's navigation type either).
  @override
  Future<Duration?> sincePress({bool pointerOnly = false}) async {
    final s = await _browser.invokeMethod<double>(
      'sincePress',
      pointerOnly ? 'pointer' : null,
    );
    return s == null ? null : Duration(microseconds: (s * 1e6).round());
  }

  @override
  Future<String?> defaultBrowserName() => browser.defaultBrowserName();

  @override
  Future<void> clearData() => browser.clearData();
}
