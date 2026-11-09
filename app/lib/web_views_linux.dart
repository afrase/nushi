import 'package:flutter/services.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/outside_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';
import 'package:url_launcher/url_launcher.dart';

const _browser = MethodChannel('nushi/browser');

/// Linux's web views, none (ADR 0104): a file's preview and a browser tab
/// are placeholders (`outside_page.dart`) whose button opens the page in the
/// default browser, through the runner's `nushi/browser`
/// (`linux/runner/gio.cc`: GIO's app for https, never `xdg-open`). A
/// Mermaid file shows its source.
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

  @override
  Future<void> openMail(Uri url) => launchUrl(url);

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
