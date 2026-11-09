import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/web_views.dart';

/// What draws a page (HTML, SVG, PDF) the agent wrote, from disk: on the
/// Mac a WKWebView (`web_page_macos.dart`); [WebViews.page] makes one.
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

/// Opens [url] in the default browser: http(s) and file addresses with
/// the app that opens https ([WebViews.openWithBrowser]), so a file is
/// never run by the app its type has; mail with the mail app
/// ([WebViews.openMail]). Any other address goes nowhere.
Future<void> openInBrowser(Uri url) async {
  if (url.scheme == 'mailto') {
    await native.web.openMail(url);
  } else if (const {'http', 'https', 'file'}.contains(url.scheme)) {
    await native.web.openWithBrowser(url);
  }
}

/// [openInBrowser] for the user's click, saying in a snack bar why the page
/// didn't open (no default browser, ADR 0104) rather than doing nothing.
Future<void> openInBrowserOrSay(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await openInBrowser(url);
  } on Object catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_browserFailure(e))));
  }
}

/// What a snack bar says of [e], the default browser's failure to open a
/// page: a [BrowserError]'s own words, else the platform's reason.
String _browserFailure(Object e) => switch (e) {
  BrowserError(:final message) => message,
  PlatformException(:final message?) => 'Couldn’t open your browser: $message',
  _ => 'Couldn’t open your browser.',
};

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
/// [WebViews.sincePress], asked only for one that leaves the page.
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

/// When the user last pressed in a web view, from [WebViews.sincePress]: null
/// if never, since the last ask, or with no answer; with [pointerOnly], a
/// key's press counts for nothing.
Future<DateTime?> lastPressInPage({bool pointerOnly = false}) async {
  try {
    final ago = await native.web.sincePress(pointerOnly: pointerOnly);
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
