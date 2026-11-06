import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// A browser tab's page (ADR 0094): what it may load, what the address field
// takes, and the web view that shows it. A file's preview keeps its own
// rules (`WebKitPage`, ADR 0068).

/// What draws a browser tab's page: on the Mac a WKWebView ([BrowserPage]);
/// tests make their own ([newBrowserHost]).
abstract interface class BrowserHost {
  /// The view; built once and kept (a web view is made once).
  Widget view(BuildContext context);

  /// Loads [url], a local page ([isLocalPage]).
  Future<void> open(Uri url);

  /// Loads the page again (the tab's address, if it never loaded).
  Future<void> reload();

  Future<void> back();
  Future<void> forward();

  /// Whether Back and Forward have a page to go to.
  ValueListenable<bool> get canBack;
  ValueListenable<bool> get canForward;

  /// Why the page didn't load ('' while it loads, or did).
  ValueListenable<String> get failed;

  void dispose();
}

/// Makes the [BrowserHost] for a browser tab's view.
BrowserHost Function(BrowserTab tab) newBrowserHost = BrowserPage.new;

/// Whether [host] is this Mac itself: `localhost`, 127.0.0.0/8 or `::1`.
bool isLoopback(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '::1') return true;
  final four = h.split('.');
  return four.length == 4 &&
      four.first == '127' &&
      four.every(
        (p) => switch (int.tryParse(p)) {
          final n? => n <= 255 && '$n' == p,
          null => false,
        },
      );
}

/// Whether a browser tab shows [url] (ADR 0094): http or https to this Mac
/// ([isLoopback]), or a blank page. Any other site is for the browser.
bool isLocalPage(Uri url) => switch (url.scheme) {
  'about' => url.path == 'blank',
  'http' || 'https' => isLoopback(url.host),
  _ => false,
};

/// What a navigation to [url] does in a browser tab, the user having last
/// pressed in a page at [pressed]: a local page stays; another site or a
/// mail address opens in the default browser, but only right after a press,
/// so a page can't open the browser on its own; a file, and every other
/// scheme, goes nowhere. A frame inside the page loads anything but a file.
PageNavigation browserNavigation(
  String url, {
  required bool mainFrame,
  DateTime? pressed,
}) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme == 'file') return PageNavigation.drop;
  if (!mainFrame || isLocalPage(u)) return PageNavigation.stay;
  return _elsewhere(u) &&
          pressed != null &&
          clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// Whether the default browser may take [url]: another site, or mail.
bool _elsewhere(Uri url) => switch (url.scheme) {
  'http' || 'https' => url.host.isNotEmpty,
  'mailto' => true,
  _ => false,
};

/// [browserNavigation], with when the user last pressed in a page, asked
/// only for one the browser may take, and only a pointer's press counting:
/// people type into a local page, and a key there (Space, Return) is the
/// page's script's to see first.
Future<PageNavigation> browserPageNavigation(
  String url, {
  required bool mainFrame,
}) async {
  final u = Uri.tryParse(url);
  final asks = mainFrame && u != null && !isLocalPage(u) && _elsewhere(u);
  return browserNavigation(
    url,
    mainFrame: mainFrame,
    pressed: asks ? await lastPressInPage(pointerOnly: true) : null,
  );
}

/// What the address field's text names: a local page for the tab (here),
/// another site for the default browser (not here), or nothing either may
/// open (null: a file, a script, an empty field). Without a scheme it's
/// http (`localhost:3000`); a port alone is localhost's (`3000`, `:3000`).
/// A port past 1–65535 names nothing.
({Uri url, bool here})? addressOf(String text) {
  var a = text.trim();
  if (a.isEmpty) return null;
  if (RegExp(r'^:?\d+$').hasMatch(a)) {
    a = 'localhost:${a.replaceFirst(':', '')}';
  }
  // A scheme, unless what follows its colon is a port (`localhost:3000`).
  final schemed = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(?!\d)').hasMatch(a);
  final u = Uri.tryParse(schemed ? a : 'http://$a');
  if (u == null || (u.hasPort && (u.port < 1 || u.port > 65535))) return null;
  if (isLocalPage(u)) return (url: u, here: true);
  if ((u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty) {
    return (url: u, here: false);
  }
  return null;
}

/// A WKWebView for a browser tab: local pages only ([browserNavigation]),
/// no window a script opens by itself (a link with a target loads in the
/// tab), and like a file's preview no script message handlers, so nothing
/// from the page reaches Nushi. It shares WebKit's default data store with
/// file previews (docs/security.md). It tells [tab] its address and title
/// as the page moves.
class BrowserPage implements BrowserHost {
  new(this.tab) {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(nav.setOnNavigationRequest(_decide));
    unawaited(
      nav.setOnPageStarted((_) {
        if (!_gone) _failed.value = '';
      }),
    );
    unawaited(nav.setOnPageFinished((_) => unawaited(_moved())));
    unawaited(nav.setOnUrlChange((c) => unawaited(_moved(c.url))));
    unawaited(nav.setOnWebResourceError(_error));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    // The camera and microphone, refused: the plugin's default asks macOS,
    // and Nushi declares neither (docs/security.md).
    unawaited(_c.setOnPlatformPermissionRequest((r) => unawaited(r.deny())));
    // Also where the plugin sets javaScriptCanOpenWindowsAutomatically.
    unawaited(_c.setJavaScriptMode(JavaScriptMode.unrestricted));
  }

  final BrowserTab tab;
  final _c = WebKitWebViewController(
    WebKitWebViewControllerCreationParams(
      javaScriptCanOpenWindowsAutomatically: false,
    ),
  );
  final _canBack = ValueNotifier<bool>(false);
  final _canForward = ValueNotifier<bool>(false);
  final _failed = ValueNotifier<String>('');
  bool _loaded = false;
  bool _gone = false; // disposed: the view's last callbacks change nothing

  @override
  ValueListenable<bool> get canBack => _canBack;
  @override
  ValueListenable<bool> get canForward => _canForward;
  @override
  ValueListenable<String> get failed => _failed;

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> open(Uri url) {
    if (!isLocalPage(url)) return Future.value();
    _loaded = true;
    tab.address.value = '$url';
    return _c.loadRequest(LoadRequestParams(uri: url));
  }

  @override
  Future<void> reload() async {
    if (_loaded) return await _c.reload();
    if (Uri.tryParse(tab.address.value) case final url?) await open(url);
  }

  @override
  Future<void> back() => _c.goBack();

  @override
  Future<void> forward() => _c.goForward();

  /// The page moved (a link, Back, a script's history): its address and
  /// title to the tab, and what Back and Forward can do.
  Future<void> _moved([String? to]) async {
    if (_gone) return;
    final String? url;
    final String? title;
    final bool back;
    final bool forward;
    try {
      url = to ?? await _c.currentUrl();
      title = await _c.getTitle();
      back = await _c.canGoBack();
      forward = await _c.canGoForward();
    } on Object {
      return; // the view is gone
    }
    if (_gone) return;
    if (url != null && url != 'about:blank') tab.address.value = url;
    tab.title.value = title ?? '';
    _canBack.value = back;
    _canForward.value = forward;
  }

  void _error(WebResourceError e) {
    // A load this tab stopped (a navigation dropped, or one in its place)
    // isn't the page failing.
    if (!(e.isForMainFrame ?? true) || e.errorCode == -999) return;
    if (e.errorCode == 102 || _gone) return; // 102: "interrupted by policy"
    _failed.value = e.description;
  }

  Future<NavigationDecision> _decide(NavigationRequest r) async {
    switch (await browserPageNavigation(r.url, mainFrame: r.isMainFrame)) {
      case PageNavigation.stay:
        return NavigationDecision.navigate;
      case PageNavigation.open:
        if (Uri.tryParse(r.url) case final url?) {
          unawaited(openInBrowser(url).catchError((_) {}));
        }
      case PageNavigation.drop:
    }
    return NavigationDecision.prevent;
  }

  @override
  void dispose() {
    _gone = true;
    _canBack.dispose();
    _canForward.dispose();
    _failed.dispose();
    // The view goes with its widget; the page stops with it.
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}
