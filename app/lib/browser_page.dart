import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/browser_navigation.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart' show localNetworkSites;
import 'package:nushi/web_page.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

export 'package:nushi/browser_navigation.dart';

// A browser tab's page (ADR 0094): the web view that shows it. Where it
// may go is `browser_navigation.dart`'s, its addresses
// `browser_address.dart`'s, its block on the local network
// `browser_local.dart`'s. A file's preview keeps its own rules
// (`WebKitPage`, ADR 0068).

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

  /// A local address the page tried to go to, refused ([blocksLocal]): set
  /// each time one is, for the pane to say so.
  ValueListenable<Uri?> get blockedLocal;

  /// The page as it's on screen, the part in sight only, as a PNG (the ⋯
  /// menu's Save screenshot).
  Future<Uint8List> snapshot();

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

/// Puts the content rule list `rules` (`localNetworkRules`) on the plugin's
/// web view `id`, in place of the one it had: the Swift side compiles it
/// and answers once it holds, or with an error, and the tab then loads
/// nothing. Tests set their own.
Future<void> Function(int id, String rules) blockLocalNetwork = (id, rules) =>
    _browser.invokeMethod<void>('blockLocal', {'id': id, 'rules': rules});

/// What WebKit told of the main frame's navigation to `url` in the
/// plugin's web view `id` as it decided on it (`CommitWatch`), taken once:
/// its kind and whether it's a redirect, or null when it told nothing (the
/// navigation is then judged as the page's own). Tests set their own.
Future<MainNavigation?> Function(int id, String url) mainNavigation =
    (id, url) async {
      final told = await _browser.invokeMethod<Map<Object?, Object?>>(
        'navigation',
        {'id': id, 'url': url},
      );
      return switch (told) {
        {'type': final int type} => (
          type: type,
          redirect: told['redirect'] as bool?,
        ),
        _ => null,
      };
    };

/// The address of the history item `by` steps from the page in the
/// plugin's web view `id` (-1 Back, 1 Forward, 0 the page itself, which
/// Reload loads), or null when there's none. Tests set their own.
Future<String?> Function(int id, int by) historyItem = (id, by) =>
    _browser.invokeMethod<String>('historyItem', {'id': id, 'by': by});

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
final defaultBrowser = ValueNotifier<String?>(null);

/// Asks the Swift side for the default browser's name, the app that opens
/// https, which a browser tab's button opens its page in (`openInBrowser`).
/// Tests set their own.
Future<String?> Function() defaultBrowserName = () =>
    _browser.invokeMethod<String>('browserName');

/// Sets [defaultBrowser] afresh: the user may have changed it meanwhile.
Future<void> lookUpDefaultBrowser() async {
  try {
    defaultBrowser.value = await defaultBrowserName();
  } on Object {
    defaultBrowser.value = null; // "your browser"
  }
}

/// The page in sight in the plugin's web view `id` as a PNG: WebKit's
/// `takeSnapshot`, on the Swift side (`BrowserData`). Tests set their own.
Future<Uint8List> Function(int id) pageSnapshot = (id) async {
  final png = await _browser.invokeMethod<Uint8List>('snapshot', id);
  if (png == null) throw StateError('The page gave no picture');
  return png;
};

/// Removes every site's data from WebKit's default store, the one browser
/// tabs and file previews share (cookies, storage, caches), on the Swift
/// side (`BrowserData`): the ⋯ menu's Clear browsing data. Tests set their
/// own.
Future<void> Function() clearBrowsingData = () =>
    _browser.invokeMethod<void>('clearData');

const _browser = MethodChannel('nushi/browser');
final _commits = <int, ValueChanged<String>>{};

Future<void> _committed(MethodCall call) async {
  if (call.method != 'committed') return;
  if (call.arguments case {'id': final int id, 'url': final String url}) {
    _commits[id]?.call(url);
  }
}

/// A WKWebView for a browser tab: web pages only ([browserNavigation]),
/// no window a script opens by itself (a link with a target loads in the
/// tab), and like a file's preview no script message handlers, so nothing
/// from the page reaches Nushi. It shares WebKit's default data store with
/// file previews (docs/security.md). It tells [tab] its address (as a load
/// commits, [PageAddress]) and title as the page moves, and loads nothing
/// if it can't see the commits or block the local network
/// ([blockLocalNetwork]) before its first load.
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
            .then((_) => _block())
          // Its error is open's to meet, not the zone's.
          ..ignore();
    localNetworkSites.addListener(_sitesChanged);
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
  final _blocked = ValueNotifier<Uri?>(null);
  final _source = NavigationSource();
  bool _loaded = false;
  bool _gone = false; // disposed: the view's last callbacks change nothing

  @override
  ValueListenable<bool> get canBack => _canBack;
  @override
  ValueListenable<bool> get canForward => _canForward;
  @override
  ValueListenable<PageFailure?> get failed => _failed;
  @override
  ValueListenable<Uri?> get blockedLocal => _blocked;

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
    _source.asked(NavigationSource.typed, '$url');
    await _c.loadRequest(LoadRequestParams(uri: url));
  }

  static const _unwatched =
      'Nushi couldn’t follow this tab’s page, or keep it off your local '
      'network, so it loads nothing.';

  @override
  Future<Uint8List> snapshot() async {
    await _ready;
    return await pageSnapshot(_id!);
  }

  @override
  Future<void> reload() async {
    if (!_loaded) {
      if (Uri.tryParse(tab.address.value) case final url?) await open(url);
      return;
    }
    await _step(0, _c.reload);
  }

  @override
  Future<void> back() => _step(-1, _c.goBack);

  @override
  Future<void> forward() => _step(1, _c.goForward);

  /// Back, Forward or Reload ([by] -1, 1 or 0), asked by the user: the load
  /// of the history item it goes to may go to a local address
  /// ([NavigationSource]). With no item to go to, Back and Forward do
  /// nothing; when WebKit can't say which, the load goes unasked.
  Future<void> _step(int by, Future<void> Function() go) async {
    String? to;
    if (_id case final id?) {
      try {
        to = await historyItem(id, by);
      } on Object {
        to = null;
      }
    }
    if (_gone) return;
    _source.asked(
      by == 0 ? NavigationSource.reload : NavigationSource.step,
      to,
    );
    if (to == null && by != 0) return;
    await go();
  }

  /// Puts the local network's block on the web view (`localNetworkRules`),
  /// with the sites let through as they are now.
  Future<void> _block() =>
      blockLocalNetwork(_id!, localNetworkRules(localNetworkSites.value));

  /// The sites let reach the local network changed: the rules follow. If
  /// they can't, the page goes, rather than keep the rules it had.
  void _sitesChanged() => unawaited(
    _ready.then((_) => _block()).catchError((Object _) {
      if (_gone) return;
      unawaited(
        _c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))),
      );
      _failed.value = (code: 0, reason: _unwatched, url: tab.address.value);
    }),
  );

  /// A load committed at [url] (the Swift side's [watchCommits]).
  void _commit(String url) {
    if (_gone) return;
    _page.committed(url);
    _source.committed(url);
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
    _source.flight = ''; // no redirect of it follows
    if (e.errorCode == 102 || _gone) return; // 102: "interrupted by policy"
    _failed.value = (
      code: e.errorCode,
      reason: e.description,
      url: e.url ?? tab.address.value,
    );
  }

  Future<NavigationDecision> _decide(NavigationRequest r) async {
    MainNavigation? nav;
    if (_id case final id? when r.isMainFrame) {
      try {
        nav = await mainNavigation(id, r.url);
      } on Object {
        nav = null; // judged as the page's own
      }
    }
    final allowed = localNetworkSites.value;
    final (:asked, :from) = r.isMainFrame
        ? _source.take(r.url, nav, allowed: allowed)
        : (asked: false, from: '');
    final url = Uri.tryParse(r.url);
    switch (await browserPageNavigation(
      r.url,
      mainFrame: r.isMainFrame,
      from: from,
      asked: asked,
      allowed: allowed,
    )) {
      case PageNavigation.stay:
        if (r.isMainFrame) _source.flight = r.url;
        return NavigationDecision.navigate;
      case PageNavigation.open:
        if (url != null) unawaited(openInBrowser(url).catchError((_) {}));
      case PageNavigation.drop:
        if (url != null &&
            r.isMainFrame &&
            !asked &&
            !_gone &&
            blocksLocal(url, from: from, allowed: allowed)) {
          // Set again even for the same address: the pane says so each time.
          _blocked
            ..value = null
            ..value = url;
        }
    }
    return NavigationDecision.prevent;
  }

  @override
  void dispose() {
    _gone = true;
    localNetworkSites.removeListener(_sitesChanged);
    if (_id case final id?) forgetCommits(id);
    _canBack.dispose();
    _canForward.dispose();
    _failed.dispose();
    _blocked.dispose();
    // The view goes with its widget; the page stops with it.
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}
