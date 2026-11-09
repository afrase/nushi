import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/web_page.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// A file's preview on the Mac (ADR 0068): a WKWebView, and the Swift
// side's `nushi/browser` channel (`macos/Runner/MainFlutterWindow.swift`).

/// Has a web view (by the plugin's `webViewIdentifier`) send and keep no
/// cookies: the Swift side adds a content rule list to it. WebKit takes a
/// `file:` page's frames and requests as first party, and file previews
/// share WebKit's store with browser tabs, so without it a page the agent
/// wrote would carry what a tab signed in to (docs/security.md).
Future<void> Function(int id) blockCookies = (id) =>
    const MethodChannel('nushi/browser').invokeMethod<void>('noCookies', id);

/// A preview's web view's loads, held until its cookies are off: none
/// before `made` (a call to the native view that has come back, so it
/// exists) and [blockCookies] for the web view the plugin numbers `id`, and
/// none at all if they can't be.
final class CookielessLoads {
  new(Future<void> made, int Function() id)
    : _ready = made.then((_) => blockCookies(id()))
        // Its error is load's to meet, not the zone's.
        ..ignore();

  final Future<void> _ready;

  /// Runs [load] once the cookies are off; throws, loading nothing, if
  /// they can't be.
  Future<void> load(Future<void> Function() load) async {
    await _ready;
    await load();
  }
}

/// A WKWebView with only its free defaults (the owner's call), and no
/// cookies ([blockCookies]): no script message handlers (nothing from the
/// page reaches Nushi), file reads inside the root it's given, the network
/// on, and a link the user clicks that leaves the page opened in the
/// default browser instead (a page that leaves on its own, by script or a
/// refresh, goes nowhere).
class WebKitPage implements PageHost {
  new() {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(nav.setOnNavigationRequest(_decide));
    unawaited(nav.setOnPageFinished(_finished));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    _loads = CookielessLoads(
      _c.setJavaScriptMode(JavaScriptMode.unrestricted),
      () => _c.webViewIdentifier,
    );
  }

  final _c = WebKitWebViewController(
    const PlatformWebViewControllerCreationParams(),
  );
  late final CookielessLoads _loads;
  final _page = PageFile();
  String _root = '';
  bool _loaded = false;
  num? _scrollTo;

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> load(String path, String root) async {
    _page.path = path;
    _root = root;
    await _loads.load(() {
      _page.loading(path);
      return _c.loadFileWithParams(
        WebKitLoadFileParams(absoluteFilePath: path, readAccessPath: root),
      );
    });
  }

  @override
  Future<void> reload() async {
    if (_page.path.isEmpty) return;
    try {
      final y = await _c.runJavaScriptReturningResult('window.scrollY');
      if (y is num && y > 0) _scrollTo = y;
    } on Object {
      // A PDF, or a page that's gone: from the top.
    }
    // WebKit's reload checks the page's files again (its CSS too); a page
    // that never loaded (missing then) loads afresh.
    await (_loaded ? _c.reload() : load(_page.path, _root));
  }

  void _finished(String url) {
    _loaded = true;
    if (_scrollTo case final y?) {
      _scrollTo = null;
      unawaited(_c.runJavaScript('window.scrollTo(0, $y)').catchError((_) {}));
    }
  }

  Future<NavigationDecision> _decide(NavigationRequest r) async {
    switch (await pageNavigation(r.url, _page, mainFrame: r.isMainFrame)) {
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
    // The view goes with its widget; the page stops with it.
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}
