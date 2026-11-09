import 'package:flutter/foundation.dart';

import 'package:nushi/browser_page.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the app's web views come from, and the default browser (ADR 0068,
/// 0094, 0097): on the Mac, WKWebViews and the Swift side
/// (`web_views_macos.dart`); on Linux, none, a page's placeholder that
/// opens it in the default browser (`outside_page.dart`, ADR 0104).
abstract interface class WebViews {
  /// Whether pages show in the app's own web views: on the Mac; on Linux
  /// they open in the default browser (ADR 0104).
  bool get embedded;

  /// A web view for a file's preview.
  PageHost page();

  /// A web view for browser tab [tab].
  BrowserHost tab(BrowserTab tab);

  /// A web view for a Mermaid file's preview, or null where there's none
  /// to draw it in (Linux): the file shows its source.
  DiagramHost? diagram();

  /// Opens [url], an http(s) or file address ([openInBrowser] lets no
  /// other through), with the app that opens https, so a file is never
  /// run by the app its type has. Throws when it can't (no default
  /// browser), a [BrowserError] where the platform has words for why.
  Future<void> openWithBrowser(Uri url);

  /// Opens [url], a mailto: address, with the mail app.
  Future<void> openMail(Uri url);

  /// Opens [url], a web link the user clicked (http or https, a
  /// `webLink`), in the default browser as the platform opens links: on
  /// the Mac through url_launcher (Launch Services), on Linux through the
  /// runner, whose launch gives the browser none of Nushi's variables
  /// (ADR 0104). Linux's opens nothing else. Throws when nothing opened, a
  /// [BrowserError] where the platform has words for why, which the click
  /// says in a snack bar (`openLinkOrSay`).
  Future<void> openLink(Uri url);

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

/// Whether the app's own web views show pages, as a widget reads it: the
/// phone's web app, which shares the widgets but has no native edge, has
/// frames of its own instead.
bool get webEmbedded => !kIsWeb && native.web.embedded;

/// Opens [url], a web link the user clicked (Jira's, GitHub's, a
/// terminal's, the agents' or an account's page), in the default browser:
/// the platform's [WebViews.openLink], or, in the phone's web app, which
/// has no native edge, a new tab (url_launcher). Throws as
/// [WebViews.openLink] does; a click goes through `openLinkOrSay`, which
/// says why.
Future<void> openInDefaultBrowser(Uri url) async {
  if (kIsWeb) {
    await launchUrl(url);
  } else {
    await native.web.openLink(url);
  }
}

/// Why the default browser didn't open a page, in words to show as they
/// are ("No default browser is set…").
class BrowserError implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}
