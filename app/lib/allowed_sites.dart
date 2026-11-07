import 'package:flutter/material.dart';

import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/settings.dart' show localNetworkSites;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The browser ⋯ menu's Manage allowed sites… (ADR 0094), drawn as Claude
// desktop's Allowed sites: a field to add one, the sites as rows to remove,
// Clear all and Done. In Nushi a site is allowed only to reach this Mac and
// the local network: no agent drives its pages.

/// What Add URL makes of [text], given the sites let through ([allowed]):
/// the host to let through, the address field's way ([addressOf]: a host,
/// a URL, `localhost:3000`) and judged as the ⋯ menu's Local network access
/// judges the page showing ([localNetworkAccess]); or why it can't be one.
/// A site already there gives its host, so adding it again changes nothing.
({String? host, String? error}) siteToAllow(String text, Set<String> allowed) {
  final u = addressOf(text);
  final access = u == null || !isWebPage(u)
      ? null
      : localNetworkAccess(u.toString(), allowed);
  return switch (access) {
    null => (host: null, error: 'That isn’t a site’s address.'),
    (fixed: true, allowed: true) => (
      host: null,
      error: 'A page on your Mac or local network always reaches it.',
    ),
    (fixed: true, allowed: false) => (
      host: null,
      error: 'This site’s address can’t be allowed.',
    ),
    _ => (host: u!.host.toLowerCase(), error: null),
  };
}

/// Manage allowed sites…: the sites whose pages in a browser tab may reach
/// this Mac and the local network (`localNetworkSites`), to add to and
/// remove from.
Future<void> showAllowedSites(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const AllowedSites(),
);

/// The Allowed sites dialog ([showAllowedSites]).
class AllowedSites extends StatefulWidget {
  const new({super.key});

  @override
  State<AllowedSites> createState() => _AllowedSitesState();
}

class _AllowedSitesState extends State<AllowedSites> {
  final _url = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    if (_url.text.trim().isEmpty) return;
    final (:host, :error) = siteToAllow(_url.text, localNetworkSites.value);
    if (host != null) {
      if (!localNetworkSites.value.contains(host)) allowLocalNetwork(host);
      _url.clear();
    }
    setState(() => _error = error);
    _focus.requestFocus();
  }

  Future<void> _clearAll() async {
    final sure = await confirm(
      context,
      'Clear all allowed sites?',
      'Their pages lose their reach to your Mac and local network until you '
          'allow them again.',
      'Clear all',
      destructive: true,
    );
    if (sure) localNetworkSites.value = const {};
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: localNetworkSites,
      builder: (context, sites, _) {
        final hosts = sites.toList()..sort();
        return nushiDialog(
          'Allowed sites',
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pages from these sites can reach your Mac and local network '
                '(a dev server, a router) from a browser tab, as local pages '
                'can. Other sites’ pages can’t.',
                style: theme.ui(t.textSecondary),
              ),
              const SizedBox(height: 18),
              Text('Add URL', style: theme.ui(t.textSecondary, size: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _url,
                focusNode: _focus,
                autofocus: true,
                style: theme.ui(t.text),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _add(),
                // Return adds and keeps the field for the next.
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: 'example.com',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: IconTap.line(
                      LineIcon.plus,
                      tooltip: 'Add',
                      size: 15,
                      padding: 4,
                      onTap: _add,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(),
                ),
              ),
              if (_error case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(e, style: theme.ui(t.crashed, size: 12)),
                ),
              const SizedBox(height: 14),
              if (hosts.isEmpty)
                Text('No sites allowed', style: theme.ui(t.textMuted))
              else
                // Scrolled past 280, or sooner in a short window.
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Column(
                        spacing: 6,
                        children: [for (final host in hosts) _SiteRow(host)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          [
            Button(
              label: 'Clear all',
              kind: ButtonKind.danger,
              onPressed: hosts.isEmpty ? null : _clearAll,
            ),
            Button(
              label: 'Done',
              kind: ButtonKind.primary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
          onClose: () => Navigator.pop(context),
          actionsAlignment: MainAxisAlignment.spaceBetween,
        );
      },
    );
  }
}

/// An allowed site: its host on a filled row, a bin at its end to take it
/// off.
class _SiteRow extends StatelessWidget {
  const new(this.host);

  final String host;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      height: 38,
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(
        color: t.hover,
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
          ),
          IconTap.line(
            LineIcon.trash,
            tooltip: 'Remove',
            onTap: () => disallowLocalNetwork(host),
          ),
        ],
      ),
    );
  }
}
