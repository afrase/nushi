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
Future<void> openInBrowserOrSay(BuildContext context, Uri url) =>
    openOrSay(context, () => openInBrowser(url));

/// [openInDefaultBrowser] for a web link the user clicked (Jira's,
/// GitHub's, a terminal's, the update card's, the agents' or an account's
/// page), saying why it didn't open as [openInBrowserOrSay] does.
Future<void> openLinkOrSay(BuildContext context, Uri url) =>
    openOrSay(context, () => openInDefaultBrowser(url));

/// Runs [open], the default browser opening what the user clicked, and
/// says in a snack bar under [context] why, when it throws.
Future<void> openOrSay(
  BuildContext context,
  Future<void> Function() open,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await open();
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

/// What a navigation to [url] does in the web view showing [page], the
/// user having last pressed in it at [pressed]: one that leaves the page
/// opens in the browser only right after a press, so a page the agent
/// shows (no click, ADR 0068) can't open tabs on its own.
PageNavigation navigation(
  String url,
  PageFile page, {
  required bool mainFrame,
  DateTime? pressed,
}) {
  if (staysInPage(url, page, mainFrame: mainFrame)) return PageNavigation.stay;
  return pressed != null && clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// [navigation], with when the user last pressed in a page from
/// [WebViews.sincePress], asked only for one that leaves the page.
Future<PageNavigation> pageNavigation(
  String url,
  PageFile page, {
  required bool mainFrame,
}) async {
  if (staysInPage(url, page, mainFrame: mainFrame)) return PageNavigation.stay;
  return navigation(
    url,
    page,
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

/// Whether a navigation to [url] stays in the web view showing [page]: the
/// page itself (a reload, an anchor in it, a query), a blank page, and
/// anything in its frames. Any other page opens in the browser.
bool staysInPage(String url, PageFile page, {required bool mainFrame}) {
  if (!mainFrame) return true;
  final u = Uri.tryParse(url);
  if (u == null) return false;
  if (u.scheme == 'about') return true;
  return page.isPage(u);
}

/// The file a web view shows, and which `file:` addresses are it. WebKit
/// loads a file through Foundation (`URL(fileURLWithPath:)`), which spells
/// accented letters, kana and Hangul decomposed (`re%CC%81sume%CC%81`),
/// where Dart's `Uri.file` keeps the path's own (`r%C3%A9sum%C3%A9`), and
/// Dart can't normalise Unicode to compare them. So the first main-frame
/// `file:` navigation after [loading] is taken as that load when its path
/// is the file's but for such letters, and its spelling is the page's too.
final class PageFile {
  new([this.path = '']);

  /// The file's absolute path, '' until one loads.
  String path;

  bool _loading = false; // the next main-frame file: navigation is the load
  String? _spelled; // WebKit's path for it, from that load

  /// Says the web view is about to load the file at [path].
  void loading(String path) {
    this.path = path;
    _spelled = null;
    _loading = true;
  }

  /// Whether [url], a main frame's address, is the file: as Dart spells
  /// its path, or as WebKit did when it loaded it.
  bool isPage(Uri url) {
    if (url.scheme != 'file' || url.host.isNotEmpty) return false;
    final load = _loading;
    _loading = false;
    if (url.path == Uri.file(path).path || url.path == _spelled) return true;
    if (!load || !_sameButLetters(url)) return false;
    _spelled = url.path;
    return true;
  }

  /// Whether [url]'s path has [path]'s names but for the letters past
  /// ASCII, which Foundation may spell otherwise ([_asciiPart]).
  bool _sameButLetters(Uri url) {
    final mine = Uri.file(path).pathSegments;
    final theirs = url.pathSegments;
    if (mine.length != theirs.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (_asciiPart(mine[i]) != _asciiPart(theirs[i])) return false;
    }
    return true;
  }
}

/// [name]'s ASCII, less the letter a combining accent follows: the same
/// for an é precomposed (`é` left out) and decomposed (`e` and its accent).
String _asciiPart(String name) {
  final kept = <int>[];
  int? last;
  for (final c in name.runes) {
    if (c < 0x80) {
      kept.add(c);
    } else if (c >= 0x300 && c < 0x370 && last != null && last < 0x80) {
      kept.removeLast(); // U+0300–U+036F: Combining Diacritical Marks
    }
    last = c;
  }
  return String.fromCharCodes(kept);
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
