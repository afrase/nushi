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

  void dispose();
}

/// Why a page didn't load: WebKit's error code (`NSURLErrorDomain`'s, as
/// -1202 for a certificate it doesn't trust) and its words.
typedef PageFailure = ({int code, String reason});

/// What the pane says of a page at [where] (its host) that didn't load
/// with WebKit's [code]: a certificate WebKit refused, which has no way
/// past it (ADR 0094), else that the host can't be reached.
String failedHeading(int code, String where) {
  if (where.isEmpty) return 'The page didn’t load';
  return switch (code) {
    // NSURLErrorServerCertificate…: bad date, untrusted, unknown root, not
    // yet valid.
    -1201 || -1202 || -1203 || -1204 => '$where’s certificate isn’t valid',
    // NSURLErrorSecureConnectionFailed, and a client certificate rejected
    // or asked for.
    -1200 || -1205 || -1206 => 'Can’t connect securely to $where',
    _ => 'Can’t reach $where',
  };
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

/// Whether a browser tab shows [url] (ADR 0094): http or https to any
/// host, or a blank page. A file, a script and every other scheme don't.
bool inBrowserTab(Uri url) => switch (url.scheme) {
  'about' => url.path == 'blank',
  'http' || 'https' => url.host.isNotEmpty,
  _ => false,
};

/// Whether the page at [address] came over plain http from another machine,
/// which anyone on the way can read or change: the bar says so. This Mac's
/// own pages don't leave it.
bool notSecure(String address) {
  final u = Uri.tryParse(address);
  return u != null && u.scheme == 'http' && !isLoopback(u.host);
}

/// What a navigation to [url] does in a browser tab, the user having last
/// pressed in a page at [pressed]: a web page stays, wherever it is; a mail
/// address opens in the default app, but only right after a press, so a
/// page can't open one on its own; a file, and every other scheme, goes
/// nowhere. A frame inside the page loads anything but a file.
PageNavigation browserNavigation(
  String url, {
  required bool mainFrame,
  DateTime? pressed,
}) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme == 'file') return PageNavigation.drop;
  if (!mainFrame || inBrowserTab(u)) return PageNavigation.stay;
  return u.scheme == 'mailto' &&
          pressed != null &&
          clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// [browserNavigation], with when the user last pressed in a page, asked
/// only for a mail address, and only a pointer's press counting: people
/// type into a page, and a key there (Space, Return) is the page's
/// script's to see first.
Future<PageNavigation> browserPageNavigation(
  String url, {
  required bool mainFrame,
}) async {
  final asks = mainFrame && Uri.tryParse(url)?.scheme == 'mailto';
  return browserNavigation(
    url,
    mainFrame: mainFrame,
    pressed: asks ? await lastPressInPage(pointerOnly: true) : null,
  );
}

/// The page the address field's text names, or null when it names none (a
/// file, a script, a word, an empty field): the field says so, and searches
/// nothing. An http or https address is kept as typed. Without a scheme
/// it's https, but http where TLS is rare and the network is the user's
/// ([_plainHttp]): `localhost:3000`, `192.168.1.20`, `printer.local`; a
/// port alone is localhost's (`3000`, `:3000`). A word that isn't a host
/// (no dot, no port, not localhost), an email address, and a port past
/// 1–65535 name nothing.
Uri? addressOf(String text) {
  var a = text.trim();
  if (a.isEmpty || a.contains(RegExp(r'\s'))) return null;
  if (RegExp(r'^:?\d+$').hasMatch(a)) {
    a = 'localhost:${a.replaceFirst(':', '')}';
  }
  // A scheme, unless what follows its colon is a port (`localhost:3000`).
  final schemed = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(?!\d)').hasMatch(a);
  final u = Uri.tryParse(schemed ? a : 'http://$a');
  if (u == null || (u.hasPort && (u.port < 1 || u.port > 65535))) return null;
  if (schemed) return inBrowserTab(u) ? u : null;
  final host = u.host;
  if (host.isEmpty || u.userInfo.isNotEmpty) return null;
  final ported = RegExp(r':\d+$').hasMatch(a.split(RegExp('[/?#]')).first);
  if (!host.contains('.') && !host.contains(':') && !ported) {
    return host == 'localhost' ? u : null;
  }
  return _plainHttp(host) ? u : u.replace(scheme: 'https');
}

/// Whether a typed [host] gets http, not https: this Mac, an IP address,
/// a `.local` or `.localhost` name, or a single name (`devbox:8080`; one
/// gets here only with a port), where a server seldom has a certificate.
bool _plainHttp(String host) =>
    !host.contains('.') ||
    host.contains(':') || // IPv6
    RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
    host.endsWith('.local') ||
    host.endsWith('.localhost') ||
    isLoopback(host);

/// A WKWebView for a browser tab: web pages only ([browserNavigation]),
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
        if (!_gone) _failed.value = null;
      }),
    );
    unawaited(nav.setOnPageFinished((_) => unawaited(_moved())));
    unawaited(nav.setOnUrlChange((c) => unawaited(_moved(c.url))));
    unawaited(nav.setOnWebResourceError(_error));
    // No setOnSSlAuthError: a certificate WebKit doesn't trust fails the
    // page (WebKit's default handling), with no way past it (ADR 0094).
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
  final _failed = ValueNotifier<PageFailure?>(null);
  bool _loaded = false;
  bool _gone = false; // disposed: the view's last callbacks change nothing

  @override
  ValueListenable<bool> get canBack => _canBack;
  @override
  ValueListenable<bool> get canForward => _canForward;
  @override
  ValueListenable<PageFailure?> get failed => _failed;

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> open(Uri url) {
    if (!inBrowserTab(url)) return Future.value();
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
    _failed.value = (code: e.errorCode, reason: e.description);
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
