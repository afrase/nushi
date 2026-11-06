import 'dart:convert';

// A browser tab's block on this Mac and the local network (ADR 0094): a
// page whose top-level address isn't there itself may load nothing from
// there, so a site can't reach a dev server, a router or a printer
// through the tab. WebKit has no private-network check of its own; a
// content rule list on the tab's web view stands in for one
// (`LocalNetwork` in MainFlutterWindow.swift), and the tab's navigation
// rule keeps the page itself from going there (`browserNavigation`).

/// Whether [host] (a URL's, IPv6 without its brackets) is this Mac or the
/// local network: loopback (`localhost` and `*.localhost`, 127.0.0.0/8,
/// `::1`), 0.0.0.0/8 and `::` (which reach this Mac), the private ranges
/// 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16, link-local 169.254.0.0/16
/// and fe80::/10, unique local fc00::/7, an IPv4 address in IPv6
/// (`::ffff:…`), and a `.local` name. A trailing dot counts as none. A
/// name that resolves there (DNS) isn't seen: only what the address says.
bool isLocalNetwork(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h.isEmpty) return false;
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  if (h.contains(':')) return _localSix(h);
  final four = _ipv4(h);
  if (four == null) return false;
  final [a, b, ..._] = four;
  return a == 127 ||
      a == 0 ||
      a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254);
}

/// [h]'s four numbers, if it's a dotted IPv4 address.
List<int>? _ipv4(String h) {
  final parts = h.split('.');
  if (parts.length != 4) return null;
  final n = [for (final p in parts) int.tryParse(p)];
  if (n.any((x) => x == null || x > 255) ||
      parts.any((p) => p.isEmpty || !RegExp(r'^\d+$').hasMatch(p))) {
    return null;
  }
  return n.cast<int>();
}

/// Whether the IPv6 address [h] is local: `::1`, `::`, an IPv4 one
/// (`::ffff:…`), or its first group in fc00::/7 or fe80::/10.
bool _localSix(String h) {
  if (h == '::1' || h == '::' || h.startsWith('::ffff:')) return true;
  final first = int.tryParse(h.split(':').first, radix: 16);
  if (first == null || h.startsWith(':')) return false;
  return (first & 0xfe00) == 0xfc00 || (first & 0xffc0) == 0xfe80;
}

/// Whether a site may go on the list of those whose pages reach the local
/// network ([localNetworkRules]): a host name or IPv4 address, lowercase,
/// nothing a rule's pattern would read as more than the host.
bool allowableHost(String host) =>
    RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*$').hasMatch(host);

/// The start of a pattern for an address at a host, any scheme (http,
/// https, ws, wss), a user name or not. WebKit's `url-filter` is a small
/// regular language (no `|`, no `\d`), so each kind of host is its own
/// pattern, each ending where the host does: a port, the path, or a
/// trailing dot before them.
const _at = '^[^:]+://([^/]*@)?';
const _end = r'\.?[:/]';
const _n = '[0-9]+';

/// The local network's hosts as `url-filter` patterns ([isLocalNetwork]'s,
/// on the addresses WebKit gives, which spell an IPv4 address dotted and an
/// IPv6 one compressed, in lowercase).
const localNetworkPatterns = [
  '${_at}localhost$_end',
  '$_at[^/:@]*\\.localhost$_end',
  '$_at[^/:@]*\\.local$_end',
  '${_at}127\\.$_n\\.$_n\\.$_n$_end',
  '${_at}0\\.$_n\\.$_n\\.$_n$_end',
  '${_at}10\\.$_n\\.$_n\\.$_n$_end',
  '${_at}172\\.1[6-9]\\.$_n\\.$_n$_end',
  '${_at}172\\.2[0-9]\\.$_n\\.$_n$_end',
  '${_at}172\\.3[01]\\.$_n\\.$_n$_end',
  '${_at}192\\.168\\.$_n\\.$_n$_end',
  '${_at}169\\.254\\.$_n\\.$_n$_end',
  '$_at\\[::1\\]',
  '$_at\\[::\\]',
  '$_at\\[::ffff:',
  '$_at\\[f[cd][0-9a-f][0-9a-f]:',
  '$_at\\[fe[89ab][0-9a-f]:',
];

/// The content rule list (WebKit's JSON) a browser tab's web view carries:
/// a block of every load of a local address (a frame, a script, an image,
/// fetch and XHR, a WebSocket, a main frame's too) unless the page on top
/// is local itself, or at one of [allowed] (hosts the user let through,
/// [allowableHost]; others are left out). A page at a local address keeps
/// the whole network, as a dev server's needs.
String localNetworkRules(Iterable<String> allowed) {
  final hosts = {
    for (final h in allowed)
      if (allowableHost(h)) h,
  }.toList()..sort();
  final tops = [
    ...localNetworkPatterns,
    for (final h in hosts) '$_at${h.replaceAll('.', r'\.')}$_end',
  ];
  return jsonEncode([
    for (final p in localNetworkPatterns)
      {
        'trigger': {'url-filter': p, 'unless-top-url': tops},
        'action': {'type': 'block'},
      },
  ]);
}

/// Whether a page at [address] may reach the local network: one there
/// itself, or at a host of [allowed].
bool reachesLocal(String address, Set<String> allowed) {
  final u = Uri.tryParse(address);
  if (u == null || u.host.isEmpty) return false;
  return isLocalNetwork(u.host) || allowed.contains(u.host.toLowerCase());
}
