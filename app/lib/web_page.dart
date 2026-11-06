import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// What draws a page (HTML, SVG, PDF) the agent wrote, from disk: on the
/// Mac a WKWebView ([WebKitPage]); tests make their own ([newPageHost]).
abstract interface class PageHost {
  /// The view; built once and kept (a web view is made once).
  Widget view(BuildContext context);

  /// Shows the file at [path] (absolute), which may read files inside
  /// [root] (the chat's folder, or the file's own).
  Future<void> load(String path, String root);

  /// Reads it again, keeping where it was scrolled to.
  Future<void> reload();

  void dispose();
}

/// Makes the [PageHost] a preview pane uses.
PageHost Function() newPageHost = WebKitPage.new;

/// Opens an address in the default browser: the Swift side (`nushi/browser`)
/// opens http(s) and file addresses with the app that opens https, so a
/// file is never run by the app its type has. Tests set their own.
Future<void> Function(Uri url) openInBrowser = (url) async {
  if (url.scheme == 'mailto') {
    await launchUrl(url);
  } else if (const {'http', 'https', 'file'}.contains(url.scheme)) {
    await const MethodChannel('nushi/browser').invokeMethod('open', '$url');
  }
};

/// How long ago the user last pressed, let go, or hit Return, Enter or
/// Space in a web view in the window, null if never or since the last ask
/// (each press lets one navigation out): the Swift side's event monitor
/// sees it, as
/// Flutter doesn't (WebKit takes a press inside its view, and the plugin
/// doesn't give WebKit's navigation type). Tests set their own.
Future<Duration?> Function() sincePressInPage = () async {
  final s = await const MethodChannel('nushi/browser')
      .invokeMethod<double>('sincePress');
  return s == null ? null : Duration(microseconds: (s * 1e6).round());
};

/// A WKWebView with only its free defaults (the owner's call):
/// no script message handlers (nothing from the page reaches Nushi), file
/// reads inside the root it's given, the network on, and a link the user
/// clicks that leaves the page opened in the default browser instead (a
/// page that leaves on its own, by script or a refresh, goes nowhere).
class WebKitPage implements PageHost {
  new() {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(nav.setOnNavigationRequest(_decide));
    unawaited(nav.setOnPageFinished(_finished));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    unawaited(_c.setJavaScriptMode(JavaScriptMode.unrestricted));
  }

  final _c = WebKitWebViewController(
    const PlatformWebViewControllerCreationParams(),
  );
  String _path = '';
  String _root = '';
  bool _loaded = false;
  num? _scrollTo;

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> load(String path, String root) {
    _path = path;
    _root = root;
    return _c.loadFileWithParams(
      WebKitLoadFileParams(absoluteFilePath: path, readAccessPath: root),
    );
  }

  @override
  Future<void> reload() async {
    if (_path.isEmpty) return;
    try {
      final y = await _c.runJavaScriptReturningResult('window.scrollY');
      if (y is num && y > 0) _scrollTo = y;
    } on Object {
      // A PDF, or a page that's gone: from the top.
    }
    // WebKit's reload checks the page's files again (its CSS too); a page
    // that never loaded (missing then) loads afresh.
    await (_loaded ? _c.reload() : load(_path, _root));
  }

  void _finished(String url) {
    _loaded = true;
    if (_scrollTo case final y?) {
      _scrollTo = null;
      unawaited(_c.runJavaScript('window.scrollTo(0, $y)').catchError((_) {}));
    }
  }

  Future<NavigationDecision> _decide(NavigationRequest r) async {
    switch (await pageNavigation(r.url, _path, mainFrame: r.isMainFrame)) {
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

/// What a navigation a page asks for does: it stays in the web view, opens
/// in the default browser, or goes nowhere.
enum PageNavigation { stay, open, drop }

/// How long after the user pressed in a page a navigation away from it
/// counts as theirs (a click on a link), as a browser's transient user
/// activation does. The plugin doesn't give WebKit's navigation type.
const userGesture = Duration(seconds: 1);

/// What a navigation to [url] does in the web view showing the file at
/// [path], the user having last pressed in it at [pressed]: one that
/// leaves the page opens in the browser only right after a press, so a
/// page the agent shows (no click, ADR 0068) can't open tabs on its own.
PageNavigation navigation(
  String url,
  String path, {
  required bool mainFrame,
  DateTime? pressed,
}) {
  if (staysInPage(url, path, mainFrame: mainFrame)) return PageNavigation.stay;
  return pressed != null && clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// [navigation], with when the user last pressed in a page from
/// [sincePressInPage], asked only for one that leaves the page.
Future<PageNavigation> pageNavigation(
  String url,
  String path, {
  required bool mainFrame,
}) async {
  if (staysInPage(url, path, mainFrame: mainFrame)) return PageNavigation.stay;
  return navigation(
    url,
    path,
    mainFrame: mainFrame,
    pressed: await lastPressInPage(),
  );
}

/// When the user last pressed in a web view, from [sincePressInPage]: null
/// if never, since the last ask, or with no answer.
Future<DateTime?> lastPressInPage() async {
  try {
    final ago = await sincePressInPage();
    return ago == null ? null : clock().subtract(ago);
  } on Object {
    return null; // no answer: no press
  }
}

/// Whether a navigation to [url] stays in the web view showing the file
/// at [path]: the page itself (a reload, an anchor in it, a query), a blank
/// page, and anything in its frames. Any other page opens in the browser.
bool staysInPage(String url, String path, {required bool mainFrame}) {
  if (!mainFrame) return true;
  final u = Uri.tryParse(url);
  if (u == null) return false;
  if (u.scheme == 'about') return true;
  return u.scheme == 'file' && u.host.isEmpty && u.path == Uri.file(path).path;
}

/// The folder a page may read files from: the chat's folder (or worktree)
/// holding [path], else the file's own folder (a file outside them that a
/// tool call wrote: the daemon's `Wrote`).
String pageRoot(String path, List<String> roots) {
  for (final r in roots) {
    if (r.isNotEmpty && path.startsWith(r.endsWith('/') ? r : '$r/')) return r;
  }
  return path.substring(0, path.lastIndexOf('/') + 1);
}

/// A page the agent wrote, in [host] (made once), following [watch]: the
/// daemon's answer says the file may be shown (it's in the chat's folder,
/// or a tool call wrote it) and where it is; the view reads it from disk,
/// past the daemon's cap too, and reads it again each time it changes.
/// Until the first answer, a note in its place; after, the page stays
/// (an agent rewriting it may leave it missing a moment).
class WebPage extends StatefulWidget {
  const new({
    required this.host,
    required this.watch,
    required this.roots,
    super.key,
  });

  final PageHost host;
  final FileWatch watch;

  /// The chat's folder and worktree.
  final List<String> roots;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  Object? _shown; // the daemon's answer last loaded

  @override
  void initState() {
    super.initState();
    widget.watch.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.watch.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final f = widget.watch.file;
    if (f == null || f.missing || identical(f, _shown)) return;
    final first = _shown == null;
    _shown = f;
    if (first) {
      unawaited(widget.host.load(f.path, pageRoot(f.path, widget.roots)));
      if (mounted) setState(() {});
    } else {
      unawaited(widget.host.reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shown == null) {
      return ListenableBuilder(
        listenable: widget.watch,
        builder: (context, _) =>
            previewStatus(context, widget.watch, capped: false) ??
            const SizedBox.shrink(),
      );
    }
    return ClearOfEdge(child: widget.host.view(context));
  }
}
