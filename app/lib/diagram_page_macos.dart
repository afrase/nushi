import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/mermaid.dart' show cssColor;
import 'package:nushi/mermaid_macos.dart' show diagramPage;
import 'package:nushi/web_page_macos.dart' show CookielessLoads, blockCookies;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The app's mermaid.html in a WKWebView, its script the pinned
/// mermaid.min.js beside it, and nothing else: any other navigation is
/// refused (Mermaid's strict level has no links or clicks anyway), and
/// like a file's preview it sends and keeps no cookies ([blockCookies]).
class WebKitDiagram implements DiagramHost {
  new() {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(
      nav.setOnNavigationRequest(
        (r) => !_loaded && r.url == Uri.file(_page).toString()
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    );
    unawaited(nav.setOnPageFinished(_finished));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    unawaited(_load());
  }

  final _c = WebKitWebViewController(
    const PlatformWebViewControllerCreationParams(),
  );
  String _page = '';
  bool _loaded = false;
  String? _pending; // the script to run once loaded

  Future<void> _load() =>
      CookielessLoads(
        _c.setJavaScriptMode(JavaScriptMode.unrestricted),
        () => _c.webViewIdentifier,
      ).load(() async {
        _page = await diagramPage();
        if (_page.isEmpty) return;
        await _c.loadFileWithParams(
          WebKitLoadFileParams(
            absoluteFilePath: _page,
            readAccessPath: _page.substring(0, _page.lastIndexOf('/')),
          ),
        );
      });

  void _finished(String url) {
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
    if (!_loaded) {
      _pending = js;
      return;
    }
    await _c.runJavaScript(js);
  }

  @override
  void dispose() {
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}
