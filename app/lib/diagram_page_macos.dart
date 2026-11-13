import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/mermaid.dart' show cssColor;
import 'package:nushi/mermaid_macos.dart' show diagramPage;
import 'package:nushi/web_page.dart' show PageFile;
import 'package:nushi/web_page_macos.dart' show CookielessLoads, blockCookies;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The app's mermaid.html in a WKWebView, its script the pinned
/// mermaid.min.js beside it, and nothing else: any other navigation is
/// refused (Mermaid's strict level has no links or clicks anyway), and
/// like a file's preview it sends and keeps no cookies ([blockCookies]).
/// Closed, it loads nothing more and its page stops: about:blank is the
/// one navigation let through then.
class WebKitDiagram implements DiagramHost {
  new() {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(
      nav.setOnNavigationRequest(
        (r) => diagramNavigation(
          Uri.tryParse(r.url),
          _page,
          loaded: _loaded,
          gone: _gone,
        ),
      ),
    );
    unawaited(nav.setOnPageFinished(_finished));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    unawaited(_load());
  }

  final _c = WebKitWebViewController(
    const PlatformWebViewControllerCreationParams(),
  );
  late final CookielessLoads _loads = CookielessLoads(
    _c.setJavaScriptMode(JavaScriptMode.unrestricted),
    () => _c.webViewIdentifier,
  );
  final _page = PageFile();
  bool _loaded = false;
  bool _gone = false; // disposed: its page would run unseen
  String? _pending; // the script to run once loaded

  Future<void> _load() => _loads.load(() async {
    final page = await diagramPage();
    if (page.isEmpty || _gone) return;
    _page.loading(page);
    await _c.loadFileWithParams(
      WebKitLoadFileParams(
        absoluteFilePath: page,
        readAccessPath: page.substring(0, page.lastIndexOf('/')),
      ),
    );
  });

  void _finished(String url) {
    if (_gone) return; // about:blank, or a page that slipped through
    _loaded = true;
    if (_pending case final js?) {
      _pending = null;
      unawaited(_c.runJavaScript(js).catchError((_) {}));
    }
  }

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> show(
    String source, {
    required bool dark,
    required Color background,
    required Color foreground,
  }) async {
    final opts = {
      'dark': dark,
      'background': cssColor(background),
      'foreground': cssColor(foreground),
      'center': true,
    };
    // Its promise isn't a result WebKit hands back.
    final js = 'show(${jsonEncode(source)}, ${jsonEncode(opts)}); void 0';
    if (_gone) return;
    if (!_loaded) {
      _pending = js;
      return;
    }
    await _c.runJavaScript(js);
  }

  @override
  void dispose() {
    // The view goes with its widget; the page stops with about:blank (the
    // filter lets it through now), and a load still waiting on the
    // cookies never starts.
    _gone = true;
    _pending = null;
    _loads.stop();
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse(_blank))));
  }
}

const _blank = 'about:blank';

/// What a diagram's view does with a navigation to [url]: its own page
/// ([page]) loads once, while the view is open; once it's [gone], only
/// about:blank, which stops the page (a filter that refused it left the
/// diagram running unseen).
NavigationDecision diagramNavigation(
  Uri? url,
  PageFile page, {
  required bool loaded,
  required bool gone,
}) => switch (url) {
  final url? when gone && '$url' == _blank => NavigationDecision.navigate,
  final url? when !gone && !loaded && page.isPage(url) =>
    NavigationDecision.navigate,
  _ => NavigationDecision.prevent,
};
