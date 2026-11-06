import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';

// Where a browser tab's page may go (ADR 0094): a web page anywhere, but a
// site's page not to this Mac or the local network; mail only on a press;
// a file nowhere. `BrowserPage` asks it of each navigation.

/// What a navigation to [url] does in a browser tab, the user having last
/// pressed in a page at [pressed]: a web page stays, wherever it is, but
/// for a local one the page at [shown] may not go to ([blocksLocal]) unless
/// the user [asked] for this load (typed it, Back, Forward, Reload); a mail
/// address opens in the default app, but only right after a press, so a
/// page can't open one on its own; a file, and every other scheme, goes
/// nowhere. A frame inside the page loads anything but a file (the content
/// rules keep a local one from a site's page, `localNetworkRules`).
PageNavigation browserNavigation(
  String url, {
  required bool mainFrame,
  DateTime? pressed,
  String shown = '',
  bool asked = false,
  Set<String> allowed = const {},
}) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme == 'file') return PageNavigation.drop;
  if (!mainFrame) return PageNavigation.stay;
  if (!asked && blocksLocal(u, shown: shown, allowed: allowed)) {
    return PageNavigation.drop;
  }
  if (inBrowserTab(u)) return PageNavigation.stay;
  return u.scheme == 'mailto' &&
          pressed != null &&
          clock().difference(pressed) <= userGesture
      ? PageNavigation.open
      : PageNavigation.drop;
}

/// Whether the page at [shown] going to [url] would take a site's page
/// to this Mac or the local network (`isLocalNetwork`): it may only from a
/// page there itself or at a host of [allowed], and never from no page (a
/// new tab's first load is the user's). WebKit's content rules can't see
/// this one: a main frame's load counts as its own top-level page (a
/// probe app, 2026-11-06).
bool blocksLocal(
  Uri url, {
  required String shown,
  required Set<String> allowed,
}) =>
    isWebPage(url) && isLocalNetwork(url.host) && !reachesLocal(shown, allowed);

/// [browserNavigation], with when the user last pressed in a page, asked
/// only for a mail address, and only a pointer's press counting: people
/// type into a page, and a key there (Space, Return) is the page's
/// script's to see first. [shown], [asked] and [allowed] are passed on.
Future<PageNavigation> browserPageNavigation(
  String url, {
  required bool mainFrame,
  String shown = '',
  bool asked = false,
  Set<String> allowed = const {},
}) async {
  final asks = mainFrame && Uri.tryParse(url)?.scheme == 'mailto';
  return browserNavigation(
    url,
    mainFrame: mainFrame,
    pressed: asks ? await lastPressInPage(pointerOnly: true) : null,
    shown: shown,
    asked: asked,
    allowed: allowed,
  );
}
