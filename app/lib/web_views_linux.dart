import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';
import 'package:url_launcher/url_launcher.dart';

/// Linux's web views, none yet: pages open in the default browser through
/// the runner's `nushi/browser` (`linux/runner/gio.cc`) later (ADR 0102).
/// Until then a preview or tab that needs a web view can't be made, and an
/// address opens nowhere.
class LinuxWebViews implements WebViews {
  const new();

  @override
  PageHost page() => throw UnsupportedError('no web views on Linux yet');

  @override
  BrowserHost tab(BrowserTab tab) =>
      throw UnsupportedError('no web views on Linux yet');

  @override
  DiagramHost diagram() => throw UnsupportedError('no web views on Linux yet');

  @override
  Future<void> openWithBrowser(Uri url) async {}

  @override
  Future<void> openMail(Uri url) => launchUrl(url);

  @override
  Future<Duration?> sincePress({bool pointerOnly = false}) async => null;

  @override
  Future<String?> defaultBrowserName() async => null;

  @override
  Future<void> clearData() async {}
}
