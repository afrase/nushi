import 'package:nushi/preview_entry.dart';
import 'package:nushi/tool_parts.dart' show plainPath;

// A browser tab's addresses (ADR 0094): which it loads, what the address
// field takes, and where the page is. A page chooses where it goes, so
// what the bar shows of that is guarded as a browser's is.

/// Whether [host] is this Mac itself: `localhost`, 127.0.0.0/8 or `::1`.
bool isLoopback(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '::1') return true;
  final four = h.split('.');
  return four.length == 4 &&
      four.first == '127' &&
      four.every(
        (p) => switch (int.tryParse(p)) {
          final n? => n <= 255 && '$n' == p,
          null => false,
        },
      );
}

/// Whether a browser tab shows [url] (ADR 0094): http or https to any
/// host, or a blank page. A file, a script and every other scheme don't.
bool inBrowserTab(Uri url) => switch (url.scheme) {
  'about' => url.path == 'blank',
  'http' || 'https' => url.host.isNotEmpty,
  _ => false,
};

/// Whether the page at [address] came over plain http from another machine,
/// which anyone on the way can read or change: the bar says so. This Mac's
/// own pages don't leave it.
bool notSecure(String address) {
  final u = Uri.tryParse(address);
  return u != null && u.scheme == 'http' && !isLoopback(u.host);
}

/// The page the address field's text names, or null when it names none (a
/// file, a script, a word, an empty field): the field says so, and searches
/// nothing. An http or https address is kept as typed. Without a scheme
/// it's https, but http where TLS is rare and the network is the user's
/// ([_plainHttp]): `localhost:3000`, `192.168.1.20`, `printer.local`; a
/// port alone is localhost's (`3000`, `:3000`). A word that isn't a host
/// (no dot, no port, not localhost), an email address, and a port past
/// 1–65535 name nothing.
Uri? addressOf(String text) {
  var a = text.trim();
  if (a.isEmpty || a.contains(RegExp(r'\s'))) return null;
  if (RegExp(r'^:?\d+$').hasMatch(a)) {
    a = 'localhost:${a.replaceFirst(':', '')}';
  }
  // A scheme, unless what follows its colon is a port (`localhost:3000`).
  final schemed = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(?!\d)').hasMatch(a);
  final u = Uri.tryParse(schemed ? a : 'http://$a');
  if (u == null || (u.hasPort && (u.port < 1 || u.port > 65535))) return null;
  if (schemed) return inBrowserTab(u) ? u : null;
  final host = u.host;
  if (host.isEmpty || u.userInfo.isNotEmpty) return null;
  final ported = RegExp(r':\d+$').hasMatch(a.split(RegExp('[/?#]')).first);
  if (!host.contains('.') && !host.contains(':') && !ported) {
    return host == 'localhost' ? u : null;
  }
  return _plainHttp(host) ? u : u.replace(scheme: 'https');
}

/// Whether a typed [host] gets http, not https: this Mac, an IP address,
/// a `.local` or `.localhost` name, or a single name (`devbox:8080`; one
/// gets here only with a port), where a server seldom has a certificate.
bool _plainHttp(String host) =>
    !host.contains('.') ||
    host.contains(':') || // IPv6
    RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
    host.endsWith('.local') ||
    host.endsWith('.localhost') ||
    isLoopback(host);

/// [url]'s host as people read it, its port after it (`[::1]:4000`), or ''
/// for a page without one: never a user name before it.
String hostOf(String url) {
  final u = Uri.tryParse(url);
  if (u == null || u.host.isEmpty) return '';
  final host = u.host.contains(':') ? '[${u.host}]' : u.host;
  return plainPath(u.hasPort ? '$host:${u.port}' : host);
}

/// Where a browser tab's page is, from WebKit's moves (ADR 0094). The tab's
/// address is the page on screen, never where a navigation is headed: a
/// page can start one to a site that never answers and stay up, taking
/// input, under that site's name. WebKit's own URL (the plugin's
/// onUrlChange, KVO of `WKWebView.URL`) is the navigation's as soon as it
/// starts, so it's taken only within the shown page's origin (its history,
/// a fragment); a load committing ([committed], from the Swift side) moves
/// it anywhere.
final class PageAddress {
  new(this.tab);

  final BrowserTab tab;
  Uri? _origin; // the committed page's, null before one

  /// A load committed at [url]: the page on screen is there now. A blank
  /// page (one a page opened over itself, its origin) keeps the address.
  void committed(String url) {
    final u = Uri.tryParse(url);
    if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return;
    _origin = u;
    _show(url, u);
  }

  /// WebKit's URL is [url] now: the page's own move (`pushState`, a
  /// fragment, a provisional load that failed), or a navigation starting.
  void changed(String url) {
    final u = Uri.tryParse(url);
    final at = _origin;
    if (u == null || at == null) return;
    if (u.scheme == at.scheme && u.host == at.host && u.port == at.port) {
      _show(url, u);
    }
  }

  /// Shows [url] ([u] parsed), a web page's.
  void _show(String url, Uri u) {
    if (u.scheme != 'http' && u.scheme != 'https') return;
    tab.address.value = url;
  }
}
