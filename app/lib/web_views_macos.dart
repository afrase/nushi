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
/// (`macos/Runner/MainFlutterWindow.swift`).
class MacWebViews implements WebViews {
  const new();

  @override
  PageHost page() => WebKitPage();

  @override
  BrowserHost tab(BrowserTab tab) => browser.BrowserPage(tab);

  @override
  DiagramHost diagram() => WebKitDiagram();

  /// The Swift side opens http(s) and file addresses with the app that
  /// opens https.
  @override
  Future<void> openInBrowser(Uri url) async {
    if (url.scheme == 'mailto') {
      await launchUrl(url);
    } else if (const {'http', 'https', 'file'}.contains(url.scheme)) {
      await _browser.invokeMethod('open', '$url');
    }
  }

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
