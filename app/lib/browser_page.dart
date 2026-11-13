import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/browser_navigation.dart';
import 'package:nushi/native.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart' show localNetworkSites;
import 'package:nushi/web_views.dart';

export 'package:nushi/browser_navigation.dart';

// A browser tab's page (ADR 0094): what shows it. Where it may go is
// `browser_navigation.dart`'s, its addresses `browser_address.dart`'s,
// its block on the local network `browser_local.dart`'s; the Mac's web
// view `browser_page_macos.dart`'s. A file's preview keeps its own rules
// (`web_page.dart`, ADR 0068).

/// What draws a browser tab's page: on the Mac a WKWebView
/// (`browser_page_macos.dart`); [WebViews.tab] makes one.
abstract interface class BrowserHost {
  /// The view; built once and kept (a web view is made once).
  Widget view(BuildContext context);

  /// Loads [url], a page for the tab ([inBrowserTab]).
  Future<void> open(Uri url);

  /// Loads the page again (the tab's address, if it never loaded).
  Future<void> reload();

  Future<void> back();
  Future<void> forward();

  /// Whether Back and Forward have a page to go to.
  ValueListenable<bool> get canBack;
  ValueListenable<bool> get canForward;

  /// Why the page didn't load (null while it loads, or did).
  ValueListenable<PageFailure?> get failed;

  /// A local address the page tried to go to, refused ([blocksLocal]): set
  /// each time one is, for the pane to say so.
  ValueListenable<Uri?> get blockedLocal;

  /// The page as it's on screen, the part in sight only, as a PNG (the ⋯
  /// menu's Save screenshot).
  Future<Uint8List> snapshot();

  void dispose();
}

/// Why a page didn't load: what went wrong, the web view's words, and
/// the address that failed (not the tab's, which stays on the page last
/// shown).
typedef PageFailure = ({PageFailureKind kind, String reason, String url});

/// What went wrong with a page that didn't load.
enum PageFailureKind {
  /// The server's certificate isn't valid (a bad date, untrusted, an
  /// unknown root, not yet valid).
  badCertificate,

  /// No secure connection (a client certificate rejected or asked for
  /// too).
  insecure,

  /// Anything else: the host can't be reached.
  unreachable,
}

/// What the pane says of a page at [where] (its host) that didn't load
/// for [kind]: a certificate the web view refused, which has no way past
/// it (ADR 0094), else that the host can't be reached.
String failedHeading(PageFailureKind kind, String where) {
  if (where.isEmpty) return 'The page didn’t load';
  return switch (kind) {
    PageFailureKind.badCertificate => '$where’s certificate isn’t valid',
    PageFailureKind.insecure => 'Can’t connect securely to $where',
    PageFailureKind.unreachable => 'Can’t reach $where',
  };
}

/// Lets pages at [host] reach this Mac and the local network from a
/// browser tab ([localNetworkSites]); the tabs' rules follow at once. A
/// host a rule can't hold safely ([allowableHost]) is refused.
bool allowLocalNetwork(String host) {
  final h = host.toLowerCase();
  if (!allowableHost(h)) return false;
  localNetworkSites.value = {...localNetworkSites.value, h};
  return true;
}

/// Takes [host] off the sites let reach the local network.
void disallowLocalNetwork(String host) =>
    localNetworkSites.value = {...localNetworkSites.value}
      ..remove(host.toLowerCase());

/// The default browser's name ("Google Chrome"), as the bar's button
/// names it: null until [lookUpDefaultBrowser] has it, or when the Mac
/// can't say.
final ValueNotifier<String?> defaultBrowser = runValue(null);

/// Removes every site's data from the web views' store
/// ([WebViews.clearData]): the ⋯ menu's Clear browsing data.
Future<void> clearBrowsingData() => native.web.clearData();

/// Sets [defaultBrowser] afresh: the user may have changed it meanwhile.
Future<void> lookUpDefaultBrowser() async {
  try {
    defaultBrowser.value = await native.web.defaultBrowserName();
  } on Object {
    defaultBrowser.value = null; // "your browser"
  }
}
