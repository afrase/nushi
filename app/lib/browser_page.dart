import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/web_page.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// A browser tab's page (ADR 0094): where it may go, and the web view that
// shows it; its addresses are `browser_address.dart`'s. A file's preview
// keeps its own rules (`WebKitPage`, ADR 0068).

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
/// -1202 for a certificate it doesn't trust), its words, and the address
/// that failed (not the tab's, which stays on the page last shown).
typedef PageFailure = ({int code, String reason, String url});

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

/// Has the Swift side tell `onCommit` the address of each load that
/// commits in the plugin's web view `id` (`webViewIdentifier`), until
/// [forgetCommits]: the plugin passes on no commit, only WebKit's URL,
/// which is a navigation's from its start ([PageAddress]).
Future<void> Function(int id, ValueChanged<String> onCommit) watchCommits =
    (id, onCommit) async {
      if (_commits.isEmpty) _browser.setMethodCallHandler(_committed);
      _commits[id] = onCommit;
      await _browser.invokeMethod<void>('watchCommits', id);
    };

/// Stops telling a web view's commits ([watchCommits]).
void forgetCommits(int id) => _commits.remove(id);

const _browser = MethodChannel('nushi/browser');
final _commits = <int, ValueChanged<String>>{};

Future<void> _committed(MethodCall call) async {
  if (call.method != 'committed') return;
  if (call.arguments case {'id': final int id, 'url': final String url}) {
    _commits[id]?.call(url);
  }
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

/// A WKWebView for a browser tab: web pages only ([browserNavigation]),
/// no window a script opens by itself (a link with a target loads in the
/// tab), and like a file's preview no script message handlers, so nothing
/// from the page reaches Nushi. It shares WebKit's default data store with
/// file previews (docs/security.md). It tells [tab] its address (as a load
/// commits, [PageAddress]) and title as the page moves, and loads nothing
/// if it can't see the commits.
class BrowserPage implements BrowserHost {
  new(this.tab) : _page = PageAddress(tab) {
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
    unawaited(
      nav.setOnUrlChange((c) {
        if (_gone) return;
        if (c.url case final url?) _page.changed(url);
        unawaited(_moved());
      }),
    );
    unawaited(nav.setOnWebResourceError(_error));
    // No setOnSSlAuthError: a certificate WebKit doesn't trust fails the
    // page (WebKit's default handling), with no way past it (ADR 0094).
    // The camera and microphone, refused: the plugin's default asks macOS,
    // and Nushi declares neither (docs/security.md).
    unawaited(_c.setOnPlatformPermissionRequest((r) => unawaited(r.deny())));
    // The Swift side stands in front of the plugin's navigation delegate,
    // so it goes on once that's set; the native view exists once a call to
    // it has come back. setJavaScriptMode is also where the plugin sets
    // javaScriptCanOpenWindowsAutomatically.
    _ready =
        _c
            .setPlatformNavigationDelegate(nav)
            .then((_) => _c.setJavaScriptMode(JavaScriptMode.unrestricted))
            .then((_) => watchCommits(_id = _c.webViewIdentifier, _commit))
          // Its error is open's to meet, not the zone's.
          ..ignore();
  }

  final BrowserTab tab;
  final PageAddress _page;
  late final Future<void> _ready;
  int? _id; // the plugin's for the web view, once watched
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
  Future<void> open(Uri url) async {
    if (!inBrowserTab(url)) return;
    _loaded = true;
    // What the user asked for shows at once, as in a browser.
    tab.address.value = '$url';
    try {
      await _ready;
    } on Object {
      if (!_gone) {
        _failed.value = (code: 0, reason: _unwatched, url: '$url');
      }
      return;
    }
    await _c.loadRequest(LoadRequestParams(uri: url));
  }

  static const _unwatched =
      'Nushi couldn’t follow this tab’s page, so it loads nothing.';

  @override
  Future<void> reload() async {
    if (_loaded) return await _c.reload();
    if (Uri.tryParse(tab.address.value) case final url?) await open(url);
  }

  @override
  Future<void> back() => _c.goBack();

  @override
  Future<void> forward() => _c.goForward();

  /// A load committed at [url] (the Swift side's [watchCommits]).
  void _commit(String url) {
    if (_gone) return;
    _page.committed(url);
    unawaited(_moved());
  }

  /// The page moved (a link, Back, a script's history): its title to the
  /// tab, and what Back and Forward can do.
  Future<void> _moved() async {
    if (_gone) return;
    final String? title;
    final bool back;
    final bool forward;
    try {
      title = await _c.getTitle();
      back = await _c.canGoBack();
      forward = await _c.canGoForward();
    } on Object {
      return; // the view is gone
    }
    if (_gone) return;
    tab.title.value = title ?? '';
    _canBack.value = back;
    _canForward.value = forward;
  }

  void _error(WebResourceError e) {
    // A load this tab stopped (a navigation dropped, or one in its place)
    // isn't the page failing.
    if (!(e.isForMainFrame ?? true) || e.errorCode == -999) return;
    if (e.errorCode == 102 || _gone) return; // 102: "interrupted by policy"
    _failed.value = (
      code: e.errorCode,
      reason: e.description,
      url: e.url ?? tab.address.value,
    );
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
    if (_id case final id?) forgetCommits(id);
    _canBack.dispose();
    _canForward.dispose();
    _failed.dispose();
    // The view goes with its widget; the page stops with it.
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}
