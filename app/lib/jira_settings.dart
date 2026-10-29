import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:nushi/account_rows.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

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

/// A token's expiry as typed ("2027-10-25"); null when empty or not a
/// date.
DateTime? _date(String text) => text.isEmpty ? null : DateTime.tryParse(text);

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

  /// Adds the site the form names ([text]: its address, email, API token
  /// and when the token expires), checked with Jira first.
  Future<void> _add(List<String> text) async {
    var url = text[0];
    if (url.isNotEmpty && !url.contains('://')) url = 'https://$url';
    final r = await widget.client.addJiraSite(
      AddJiraSiteRequest(
        url: url,
        email: text[1],
        token: text[2],
        expires: Int64(_date(text[3])?.millisecondsSinceEpoch ?? 0),
      ),
    );
    if (!mounted) return;
    setState(() {
      _adding = false;
      _checked[r.site.id] = 'Connected as ${r.site.name}';
    });
    unawaited(_load());
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
                _siteRow(
                  t,
                  s,
                  checked: _checked[s.id],
                  warning: expiryWarning(s, widget.now ?? clock()),
                  onAllow: () => _allow(s),
                  onRemove: () => _remove(s),
                ),
            ],
          ),
        if (_adding)
          TokenForm(
            title: 'Add a Jira Cloud site',
            fields: const [
              TokenField('Site', 'example.atlassian.net', autofocus: true),
              TokenField('Email', 'you@example.com'),
              TokenField('API token', 'classic or scoped', secret: true),
              TokenField('Expires', 'optional: 2027-10-25'),
            ],
            tokensPage: tokensPage,
            check: (text) => text[3].isNotEmpty && _date(text[3]) == null
                ? 'Expires: a date such as 2027-10-25'
                : null,
            onAdd: _add,
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

/// A site's row: its email and token's kind, who its token is (Jira was
/// asked: [checked]) or what's wrong, and when the token expires if soon.
AccountRow _siteRow(
  Tokens t,
  JiraSite s, {
  required String? checked,
  required String? warning,
  required VoidCallback onAllow,
  required VoidCallback onRemove,
}) {
  final ok = checked?.startsWith('Connected as ') ?? false;
  return AccountRow(
    title: s.id,
    lines: [
      ([s.email, if (s.scoped) 'scoped token'].join(' · '), t.textSecondary),
      if (s.needsOk)
        (needsOkStatus, t.needs)
      else if (s.problem.isNotEmpty)
        (s.problem, t.crashed)
      else
        (
          checked ?? 'Checking…',
          ok || checked == null ? t.textMuted : t.crashed,
        ),
      if (warning case final w?)
        ('$w: make a new one and add the site again.', t.needs),
    ],
    needsOk: s.needsOk,
    onAllow: onAllow,
    onRemove: onRemove,
  );
}
