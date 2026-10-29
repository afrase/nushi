import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where Atlassian makes API tokens.
final Uri tokensPage = Uri.parse(
  'https://id.atlassian.com/manage-profile/security/api-tokens',
);

/// How a token's expiry reads, if it's close: "Expires in 3 days",
/// "Expired"; null when it's far off or not known.
String? expiryWarning(JiraSite site, DateTime now) {
  if (site.expires == 0) return null;
  final days = DateTime.fromMillisecondsSinceEpoch(site.expires.toInt())
      .difference(now)
      .inHours;
  if (days < 0) return 'The token has expired';
  if (days < 24) return 'The token expires today';
  if (days < 14 * 24) {
    final d = (days / 24).ceil();
    return 'The token expires in $d day${d == 1 ? '' : 's'}';
  }
  return null;
}

/// Settings › Jira: the sites added, each with who its token is (asked of
/// Jira when the page opens) or what's wrong; Add a site; Remove.
class JiraPage extends StatefulWidget {
  const new(this.client, {super.key, this.now});

  final NushiServiceClient client;

  /// The time expiry is measured from (tests); now when null.
  final DateTime? now;

  @override
  State<JiraPage> createState() => _JiraPageState();
}

class _JiraPageState extends State<JiraPage> {
  List<JiraSite>? _sites;
  String? _error; // why the sites couldn't be listed
  final _checked = <String, String>{}; // site id -> "Connected as …" or why not
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(check: true));
  }

  Future<void> _load({bool check = false}) async {
    final ListJiraSitesResponse r;
    try {
      r = await widget.client.listJiraSites(ListJiraSitesRequest());
    } on Object catch (e) {
      // The daemon restarting, say: what went wrong, not a blank page.
      if (mounted) setState(() => _error = errorText(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      _sites = r.sites;
      _error = null;
      _adding = _adding || r.sites.isEmpty;
    });
    if (check) {
      for (final s in r.sites.where((s) => s.problem.isEmpty)) {
        unawaited(_check(s.id));
      }
    }
  }

  Future<void> _check(String id) async {
    String said;
    try {
      final r = await widget.client.checkJiraSite(
        CheckJiraSiteRequest(site: id),
      );
      said = 'Connected as ${r.name}';
    } on Object catch (e) {
      said = errorText(e);
    }
    if (mounted) setState(() => _checked[id] = said);
  }

  Future<void> _remove(JiraSite s) async {
    if (!await confirm(
          context,
          'Remove ${s.id}?',
          'Nushi forgets the site and deletes its token from the keychain.',
          'Remove',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    await tryOrShow(context, () async {
      await widget.client.removeJiraSite(RemoveJiraSiteRequest(site: s.id));
      await _load();
    });
  }

  Future<void> _allow(JiraSite s) => tryOrShow(context, () async {
    await widget.client.allowJiraToken(AllowJiraTokenRequest(site: s.id));
    await _load();
    unawaited(_check(s.id));
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final error = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: theme.ui(t.crashed, size: 12)),
          );
    final sites = _sites;
    if (sites == null) {
      if (error == null) return const SizedBox(height: 40);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          error,
          RunButton(label: 'Try again', run: () => _load(check: true)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?error,
        if (sites.isNotEmpty)
          SettingsGroup(
            title: 'Sites',
            children: [
              for (final s in sites)
                _SiteRow(
                  s,
                  checked: _checked[s.id],
                  warning: expiryWarning(s, widget.now ?? clock()),
                  onAllow: () => _allow(s),
                  onRemove: () => _remove(s),
                ),
            ],
          ),
        if (_adding)
          _AddSite(
            widget.client,
            onAdded: (site) {
              setState(() {
                _adding = false;
                _checked[site.id] = 'Connected as ${site.name}';
              });
              unawaited(_load());
            },
            onCancel: sites.isEmpty
                ? null
                : () => setState(() => _adding = false),
          )
        else
          Row(
            children: [
              Button(
                label: 'Add a site',
                icon: Icons.add,
                onPressed: () => setState(() => _adding = true),
              ),
            ],
          ),
        if (sites.isEmpty && !_adding)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No Jira sites.',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const new(
    this.site, {
    required this.checked,
    required this.warning,
    required this.onAllow,
    required this.onRemove,
  });

  final JiraSite site;
  final String? checked;
  final String? warning;
  final VoidCallback onAllow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final s = site;
    final ok = checked?.startsWith('Connected as ') ?? false;
    final status = s.needsOk
        ? 'This build of Nushi needs your OK to read the token: macOS asks '
              'for your password.'
        : s.problem.isNotEmpty
        ? s.problem
        : checked ?? 'Checking…';
    final statusColor = s.needsOk
        ? t.needs
        : s.problem.isNotEmpty || !(ok || checked == null)
        ? t.crashed
        : t.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.id, style: theme.ui(t.text, weight: FontWeight.w600)),
                Text(
                  [s.email, if (s.scoped) 'scoped token'].join(' · '),
                  style: theme.ui(t.textSecondary, size: 12),
                ),
                Text(status, style: theme.ui(statusColor, size: 12)),
                if (warning case final w?)
                  Text(
                    '$w: make a new one and add the site again.',
                    style: theme.ui(t.needs, size: 12),
                  ),
              ],
            ),
          ),
          if (s.needsOk)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Button(label: 'Allow…', onPressed: onAllow),
            ),
          Button(
            label: 'Remove',
            kind: ButtonKind.destructive,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The form for a site: its address, the email and an API token, and when
/// the token expires if known (Atlassian shows it when it makes one).
class _AddSite extends StatefulWidget {
  const new(this.client, {required this.onAdded, required this.onCancel});

  final NushiServiceClient client;
  final void Function(JiraSite) onAdded;
  final VoidCallback? onCancel;

  @override
  State<_AddSite> createState() => _AddSiteState();
}

class _AddSiteState extends State<_AddSite> {
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _expires = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_url, _email, _token, _expires]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    var url = _url.text.trim();
    if (url.isNotEmpty && !url.contains('://')) url = 'https://$url';
    final expires = _expires.text.trim();
    final date = expires.isEmpty ? null : DateTime.tryParse(expires);
    if (expires.isNotEmpty && date == null) {
      setState(() => _error = 'Expires: a date such as 2027-10-25');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.client.addJiraSite(
        AddJiraSiteRequest(
          url: url,
          email: _email.text.trim(),
          token: _token.text.trim(),
          expires: Int64(date?.millisecondsSinceEpoch ?? 0),
        ),
      );
      _token.clear();
      widget.onAdded(r.site);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final mono = theme.code(t.text, size: 12);
    Widget field(
      String label,
      TextEditingController c,
      String hint, {
      bool secret = false,
      bool autofocus = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: theme.ui(t.textSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: c,
              obscureText: secret,
              autofocus: autofocus,
              enabled: !_busy,
              style: mono,
              decoration: InputDecoration(hintText: hint, isDense: true),
              onSubmitted: (_) => _add(),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: box(t.borderSubtle, fill: t.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a Jira Cloud site',
            style: theme.ui(t.text, weight: FontWeight.w600),
          ),
          field('Site', _url, 'example.atlassian.net', autofocus: true),
          field('Email', _email, 'you@example.com'),
          field('API token', _token, 'classic or scoped', secret: true),
          field('Expires', _expires, 'optional: 2027-10-25'),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              LinkText(
                'Make a token',
                size: 12,
                onTap: () => unawaited(launchUrl(tokensPage)),
              ),
              const Spacer(),
              if (widget.onCancel case final cancel?)
                Button(label: 'Cancel', onPressed: _busy ? null : cancel),
              const SizedBox(width: 6),
              Button(
                label: _busy ? 'Checking…' : 'Add',
                kind: ButtonKind.primary,
                onPressed: _busy ? null : _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
