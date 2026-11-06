import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';

// Where a browser tab's page may go (ADR 0094): a web page anywhere, but a
// site's page not to this Mac or the local network; mail only on a press;
// a file nowhere. `BrowserPage` asks it of each navigation.

/// What a navigation to [url] does in a browser tab, the user having last
/// pressed in a page at [pressed]: a web page stays, wherever it is, but
/// to a local one the address it comes [from] may not send it
/// ([blocksLocal]) unless the user [asked] for this load (typed it, Back,
/// Forward, Reload; [NavigationSource] says which); a mail
/// address opens in the default app, but only right after a press, so a
/// page can't open one on its own; a file, and every other scheme, goes
/// nowhere. A frame inside the page loads anything but a file (the content
/// rules keep a local one from a site's page, `localNetworkRules`).
PageNavigation browserNavigation(
  String url, {
  required bool mainFrame,
  DateTime? pressed,
  String from = '',
  bool asked = false,
  Set<String> allowed = const {},
}) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme == 'file') return PageNavigation.drop;
  if (!mainFrame) return PageNavigation.stay;
  if (!asked && blocksLocal(u, from: from, allowed: allowed)) {
    return PageNavigation.drop;
  }
  if (inBrowserTab(u)) return PageNavigation.stay;
  return u.scheme == 'mailto' &&
          pressed != null &&
          clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// Whether a navigation to [url] from the address [from] (the page on
/// screen, or the address a server redirected from) would take a site's
/// page to this Mac or the local network (`isLocalNetwork`): it may only
/// from an address there itself or at a host of [allowed], and never from
/// no page (a new tab's first load is the user's). WebKit's content rules
/// can't see this one: a main frame's load counts as its own top-level
/// page (a probe app, 2026-11-06).
bool blocksLocal(
  Uri url, {
  required String from,
  required Set<String> allowed,
}) =>
    isWebPage(url) && isLocalNetwork(url.host) && !reachesLocal(from, allowed);

/// [browserNavigation], with when the user last pressed in a page, asked
/// only for a mail address, and only a pointer's press counting: people
/// type into a page, and a key there (Space, Return) is the page's
/// script's to see first. [from], [asked] and [allowed] are passed on.
Future<PageNavigation> browserPageNavigation(
  String url, {
  required bool mainFrame,
  String from = '',
  bool asked = false,
  Set<String> allowed = const {},
}) async {
  final asks = mainFrame && Uri.tryParse(url)?.scheme == 'mailto';
  return browserNavigation(
    url,
    mainFrame: mainFrame,
    pressed: asks ? await lastPressInPage(pointerOnly: true) : null,
    from: from,
    asked: asked,
    allowed: allowed,
  );
}

/// What WebKit says of a main frame's navigation as it's decided on
/// (`CommitWatch` in `MainFlutterWindow.swift`): its `WKNavigationType`'s
/// raw value ([NavigationSource]'s `typed`, `step`, `reload`) and whether
/// it's a server's redirect of the navigation before it.
typedef MainNavigation = ({int type, bool redirect});

/// Who sent a browser tab's main frame where, for its block on the local
/// network (ADR 0094): whether the user asked for a navigation, and the
/// address it comes from. The user's ask is bound to the load it names
/// (the address typed, or the history item Back, Forward or Reload goes
/// to, and WebKit's kind for it), so a page's script that navigates while
/// it waits can't take it; a redirect comes from the address that
/// redirected, not the page still on screen, which is the last committed
/// one, not an address typed and still loading.
final class NavigationSource {
  /// `WKNavigationType`'s raw values: a load the app asked for (and a
  /// script's `location`, and a server's redirect), Back or Forward, a
  /// reload, and a form sent again by either.
  static const typed = -1;
  static const step = 2;
  static const reload = 3;
  static const resent = 4;

  ({Set<int> types, String url, DateTime at})? _ask;
  String _page = ''; // the committed page's address

  /// The main frame's navigation let go last, until it commits or fails
  /// ('' then): a redirect next comes from it.
  String flight = '';

  /// The user asked for a load of [url] (null: one that goes nowhere,
  /// which takes back any ask before it), of WebKit's [type].
  void asked(int type, String? url) => _ask = url == null
      ? null
      : (
          types: {type, if (type == step || type == reload) resent},
          url: url,
          at: clock(),
        );

  /// A load committed at [url]: the page on screen is there now. Only a
  /// web page's counts: a blank page keeps the address of the one that
  /// opened it, as `PageAddress` does.
  void committed(String url) {
    flight = '';
    final u = Uri.tryParse(url);
    if (u != null && (u.scheme == 'http' || u.scheme == 'https')) _page = url;
  }

  /// For a main frame's navigation to [url], told [nav] (null when WebKit
  /// told nothing): whether the user asked for it, taking the ask, and
  /// the address it comes from. Without WebKit's word it's no ask and no
  /// redirect: the page on screen sent it.
  ({bool asked, String from}) take(String url, MainNavigation? nav) {
    final ask = _ask;
    final asked =
        ask != null &&
        nav != null &&
        !nav.redirect &&
        ask.types.contains(nav.type) &&
        sameAddress(ask.url, url) &&
        clock().difference(ask.at) <= userGesture;
    if (asked) _ask = null;
    final redirect = nav != null && nav.redirect && flight.isNotEmpty;
    return (asked: asked, from: redirect ? flight : _page);
  }
}

/// Whether [a] and [b] are the same address as WebKit writes it: its host
/// in lower case, an empty path as `/`, a default port dropped.
bool sameAddress(String a, String b) {
  String? plain(String s) {
    final u = Uri.tryParse(s);
    return u?.replace(path: u.path.isEmpty ? '/' : u.path).toString();
  }

  final x = plain(a);
  return x != null && x == plain(b);
}
