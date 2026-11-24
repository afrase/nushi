import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:nushi/account_rows.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/run_state.dart';
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
  const new(this.daemon, {super.key, this.onSites});

  final Daemon daemon;

  /// Told each listing of the sites (Settings' nav marks Jira by it).
  final ValueChanged<List<JiraSite>>? onSites;
  NushiServiceClient get client => daemon.client;

  @override
  State<JiraPage> createState() => _JiraPageState();
}

class _JiraPageState extends State<JiraPage> {
  List<JiraSite>? _sites;
  String? _error; // why the sites couldn't be listed
  final _checked = <String, _SiteCheck>{}; // site id -> what Jira said
  bool _adding = false;

  // The sites asked for while the daemon was gone.
  late final _again = LoadAgain(widget.daemon, () {
    if (mounted) unawaited(_load(check: true));
  });

  @override
  void initState() {
    super.initState();
    unawaited(_load(check: true));
  }

  @override
  void dispose() {
    _again.cancel();
    super.dispose();
  }

  Future<void> _load({bool check = false}) async {
    _again.cancel();
    final ListJiraSitesResponse r;
    try {
      r = await widget.client.listJiraSites(ListJiraSitesRequest());
    } on Object catch (e) {
      // The daemon restarting, say: what went wrong, not a blank page;
      // asked again once it is back.
      if (mounted) {
        setState(() => _error = errorText(e));
        _again.failed(e);
      }
      return;
    }
    final ids = {for (final s in r.sites) s.id};
    _jiraWorks.removeWhere((id, _) => !ids.contains(id));
    if (!mounted) return;
    widget.onSites?.call(r.sites);
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
    _SiteCheck said;
    try {
      final r = await widget.client.checkJiraSite(
        CheckJiraSiteRequest(site: id),
      );
      said = (who: r.name, error: null);
      _jiraWorks[id] = true;
    } on Object catch (e) {
      said = (who: null, error: errorText(e));
      _jiraWorks[id] = false;
    }
    if (!mounted) return;
    setState(() => _checked[id] = said);
    // The nav's dot follows what Jira said, not only the listing.
    if (_sites case final sites?) widget.onSites?.call(sites);
  }

  Future<void> _remove(JiraSite s) async {
    if (!await confirm(
          context,
          'Remove ${s.id}?',
          'Nushi forgets the site and deletes its token from the '
              '${conventions.keyring}.',
          'Remove',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    final toasts = Toasts.maybeOf(context);
    await tryOrShow(context, () async {
      final r = await widget.client.removeJiraSite(
        RemoveJiraSiteRequest(site: s.id),
      );
      await _load();
      sayTokenKept(toasts, r.tokenKept);
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
      _checked[r.site.id] = (who: r.site.name, error: null);
    });
    _jiraWorks[r.site.id] = true;
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
        SettingsGroup(
          title: 'Sites',
          actions: [
            if (!_adding)
              Button(
                label: 'Add a site',
                icon: Icons.add,
                onPressed: () => setState(() => _adding = true),
              ),
          ],
          empty: 'No Jira sites',
          children: [
            for (final s in sites)
              _siteRow(
                t,
                s,
                checked: _checked[s.id],
                warning: expiryWarning(s, clock()),
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
          ),
      ],
    );
  }
}

/// Whether any of [sites] has a token that works: Settings' nav dot.
bool jiraConnected(Iterable<JiraSite> sites) => sites.any(
  (s) => s.problem.isEmpty && !s.needsOk && (_jiraWorks[s.id] ?? false),
);

/// Whether Jira, asked this launch (Settings › Jira checks each site as it
/// opens), said who a site's token is: Settings' nav dot, known without
/// asking Jira again.
bool get jiraConnectedKnown => _jiraWorks.values.any((on) => on);

/// Each site checked this launch: whether Jira took its token.
final Map<String, bool> _jiraWorks = runMap();

/// What Jira said when a site's token was checked: who the token is, or
/// why it was refused.
typedef _SiteCheck = ({String? who, String? error});

/// A site's row: who its token is (Jira was asked: [checked]) and its
/// email, or what's wrong, and when the token expires if soon; "Connected"
/// once Jira said who; Remove behind ⋯.
AccountRow _siteRow(
  Tokens t,
  JiraSite s, {
  required _SiteCheck? checked,
  required String? warning,
  required VoidCallback onAllow,
  required VoidCallback onRemove,
}) {
  final who = checked?.who;
  final ok = who != null;
  return AccountRow(
    icon: Icons.task_alt,
    title: s.id,
    lines: [
      (
        [?who, s.email, if (s.scoped) 'scoped token'].join(' · '),
        t.textSecondary,
      ),
      if (s.needsOk)
        (needsOkStatus, t.needs)
      else if (s.problem.isNotEmpty)
        (s.problem, t.crashed)
      else if (!ok)
        (
          checked?.error ?? 'Checking…',
          checked == null ? t.textMuted : t.crashed,
        ),
      if (warning case final w?)
        ('$w: make a new one and add the site again.', t.needs),
    ],
    state: switch (s) {
      _ when s.needsOk => null, // Allow… says it
      _ when ok => ('Connected', NoteTone.done),
      _ when s.problem.isNotEmpty || checked != null => (
        'Not connected',
        NoteTone.crashed,
      ),
      _ => null,
    },
    needsOk: s.needsOk,
    onAllow: onAllow,
    more: [MenuEntry('Remove site…', danger: true, onPick: onRemove)],
  );
}
