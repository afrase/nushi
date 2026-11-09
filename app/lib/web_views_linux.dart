import 'package:flutter/services.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/outside_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';

const _browser = MethodChannel('nushi/browser');

/// Linux's web views, none (ADR 0104): a file's preview and a browser tab
/// are placeholders (`outside_page.dart`) whose button opens the page in the
/// default browser, through the runner's `nushi/browser`
/// (`linux/runner/gio.cc`: GIO's app for https, never `xdg-open`). A
/// Mermaid file shows its source. Links and mail go through the runner
/// too, never url_launcher, so the app they start gets none of Nushi's
/// variables.
class LinuxWebViews implements WebViews {
  const new();

  @override
  bool get embedded => false;

  @override
  PageHost page() => OutsidePage();

  @override
  BrowserHost tab(BrowserTab tab) => OutsideTab(tab);

  @override
  DiagramHost? diagram() => null;

  /// The runner refuses any scheme but http, https and file, as the Mac's
  /// does, and says why it couldn't open one: `no-browser` when nothing
  /// opens https, `failed` (with GIO's reason) or `refused` otherwise.
  /// A runner without the channel (not implemented) opened nothing too.
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
    } on MissingPluginException {
      throw const BrowserError('Couldn’t open your browser.');
    }
  }

  /// The runner's default app for mailto:, which refuses any other
  /// scheme; an error has words to show, as [openWithBrowser]'s.
  @override
  Future<void> openMail(Uri url) async {
    try {
      await _browser.invokeMethod<void>('openMail', '$url');
    } on PlatformException catch (e) {
      throw BrowserError(switch (e.code) {
        'no-mail-app' =>
          'No default mail app is set: choose one in your system’s settings.',
        _ => 'Couldn’t open your mail app: ${e.message ?? e.code}',
      });
    } on MissingPluginException {
      throw const BrowserError('Couldn’t open your mail app.');
    }
  }

  /// The browser that opens https, as [openWithBrowser], with its errors,
  /// for http and https alone (never a file, whatever a caller passes).
  @override
  Future<void> openLink(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw const BrowserError('Only a web link opens in the browser.');
    }
    await openWithBrowser(url);
  }

  /// No web view takes presses.
  @override
  Future<Duration?> sincePress({bool pointerOnly = false}) async => null;

  @override
  Future<String?> defaultBrowserName() =>
      _browser.invokeMethod<String>('browserName');

  /// The browser keeps its own data.
  @override
  Future<void> clearData() async {}
}
