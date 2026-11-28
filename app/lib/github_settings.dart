import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/account_rows.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_asks_settings.dart';
import 'package:nushi/github_findings_settings.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Where GitHub makes tokens.
final Uri githubTokensPage = Uri.parse('https://github.com/settings/tokens');

/// Where a token comes from, as Settings says it.
String tokenSource(GitHubHost h) => switch (h.source) {
  'gh' => "gh's login",
  'token' => 'a pasted token',
  final s => s, // what an older daemon named (an environment variable's name)
};

/// A token's kind, as Settings says it.
String tokenKind(String kind) => switch (kind) {
  'oauth' => 'OAuth token',
  'classic' => 'classic token',
  'fine-grained' => 'fine-grained token: no Checks, one owner',
  'app' => "a GitHub App's token",
  _ => '',
};

/// What's left of a host's rate limits: REST, GraphQL and search.
String budgetLine(GitHubHost h, DateTime now) {
  String one(String name, String label) {
    final b = h.budget.where((b) => b.name == name).firstOrNull;
    if (b == null || b.limit == 0) return '';
    return '$label ${b.remaining} of ${b.limit}';
  }

  final parts = [
    one('core', 'REST'),
    one('graphql', 'GraphQL'),
    one('search', 'search'),
  ].where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final reset = h.budget
      .where((b) => b.name == 'graphql')
      .map((b) => DateTime.fromMillisecondsSinceEpoch(b.resetMs.toInt()))
      .firstOrNull;
  final mins = reset?.difference(now).inMinutes;
  return 'Left this hour: ${parts.join(', ')}'
      '${mins != null && mins >= 0 ? ' (GraphQL resets in ${mins}m)' : ''}';
}

/// Settings › GitHub: an account row for each host gh is signed in to or
/// given a token, who its token is (gh's login, or a pasted one, in the
/// keychain) and what's left of its rate limits (shared with gh in a
/// terminal and agents that run gh), its kind and scopes behind ⋯; Add a
/// token, for a host
/// without gh, or instead of gh's. Then review bots and the reply cards'
/// asks.
class GitHubPage extends StatefulWidget {
  const new(this.daemon, {super.key, this.onHosts});

  final Daemon daemon;

  /// Told each listing of the hosts (Settings' nav marks GitHub by it).
  final ValueChanged<List<GitHubHost>>? onHosts;
  NushiServiceClient get client => daemon.client;

  @override
  State<GitHubPage> createState() => _GitHubPageState();
}

class _GitHubPageState extends State<GitHubPage> {
  List<GitHubHost>? _hosts;
  String? _error;
  bool _adding = false;

  // The hosts asked for while the daemon was gone.
  late final _again = LoadAgain(widget.daemon, () {
    if (mounted) unawaited(_load());
  });

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _again.cancel();
    super.dispose();
  }

  /// Lists the hosts through the daemon's one owner of them, so the GitHub
  /// views know a host added, removed or allowed here at once.
  Future<void> _load() async {
    _again.cancel();
    final owner = GitHubHosts.of(widget.daemon);
    await owner.load();
    final failed = owner.error;
    if (failed == null) keepGitHubLogins(owner.hosts ?? const []);
    if (!mounted) return;
    if (failed case final e?) {
      setState(() {
        _hosts = const [];
        _error = errorText(e);
      });
      _again.failed(e);
      return;
    }
    final hosts = owner.hosts ?? const <GitHubHost>[];
    widget.onHosts?.call(hosts);
    setState(() {
      _hosts = hosts;
      _error = null;
      _adding = _adding || hosts.isEmpty;
    });
  }

  Future<void> _remove(GitHubHost h) async {
    if (!await confirm(
          context,
          'Remove the token for ${h.host}?',
          'Nushi deletes it from the ${conventions.keyring}, and uses '
              "gh's login for ${h.host} if gh has one.",
          'Remove',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    final toasts = Toasts.maybeOf(context);
    await tryOrShow(context, () async {
      final r = await widget.client.removeGitHubToken(
        RemoveGitHubTokenRequest(host: h.host),
      );
      await _load();
      sayTokenKept(toasts, r.tokenKept);
    });
  }

  Future<void> _allow(GitHubHost h) => tryOrShow(context, () async {
    await widget.client.allowGitHubToken(AllowGitHubTokenRequest(host: h.host));
    await _load();
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final hosts = _hosts;
    if (hosts == null) return const SizedBox(height: 40);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: 'Accounts',
          actions: [
            if (!_adding)
              Button(
                label: 'Add a token',
                icon: Icons.add,
                onPressed: () => setState(() => _adding = true),
              ),
          ],
          footer: const Text(
            'Asked only while a GitHub view shows; writes only what you '
            'send.',
          ),
          children: [
            for (final h in hosts)
              _hostRow(
                t,
                h,
                now: clock(),
                onAllow: () => _allow(h),
                onRemove: () => _remove(h),
              ),
            if (hosts.isEmpty)
              const SettingsRow(
                'No GitHub account',
                description: 'Run gh auth login in a terminal, or add a token.',
              ),
          ],
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        if (_adding) ...[
          TokenForm(
            title: 'Add a GitHub token',
            note:
                "Used for its host instead of gh's login, until removed. A "
                'classic token with repo and read:org covers what Nushi '
                'does.',
            fields: const [
              TokenField('Host', 'github.com', text: 'github.com'),
              TokenField(
                'Token',
                'ghp_… or github_pat_…',
                secret: true,
                autofocus: true,
              ),
            ],
            tokensPage: githubTokensPage,
            onAdd: (text) async {
              await widget.client.addGitHubToken(
                AddGitHubTokenRequest(host: text[0], token: text[1]),
              );
              if (!mounted) return;
              setState(() => _adding = false);
              unawaited(_load());
            },
            onCancel: hosts.isEmpty
                ? null
                : () => setState(() => _adding = false),
          ),
          const SizedBox(height: 24),
        ],
        const FindingsGroup(),
        const CardAsksGroup(),
      ],
    );
  }
}

/// Whether any of [hosts] is signed in and works: Settings' nav dot.
bool githubConnected(Iterable<GitHubHost> hosts) => hosts.any(githubHostWorks);

/// A host's row: who its token is and where it's from, or what's wrong;
/// "Signed in" once GitHub said who; under it, a muted line of what's left
/// of its rate limits this hour, which people check; its token's kind and
/// scopes, the jargon, behind ⋯, with Remove for a pasted token.
AccountRow _hostRow(
  Tokens t,
  GitHubHost h, {
  required DateTime now,
  required VoidCallback onAllow,
  required VoidCallback onRemove,
}) {
  final who = h.login.isEmpty
      ? null
      : '${h.login}${h.name.isEmpty ? '' : ' (${h.name})'}';
  final from = h.source.isEmpty ? '' : 'from ${tokenSource(h)}';
  final kind = tokenKind(h.kind);
  final budget = budgetLine(h, now);
  final token = [
    if (kind.isNotEmpty) kind[0].toUpperCase() + kind.substring(1),
    if (h.scopes.isNotEmpty) 'scopes ${h.scopes.join(', ')}',
  ].join(' with ');
  return AccountRow(
    icon: Icons.merge_type,
    title: h.host,
    lines: [
      if (h.needsOk)
        (needsOkStatus, t.needs)
      else if (h.problem.isNotEmpty)
        (h.problem, t.crashed)
      else
        (
          [who ?? 'Checking…', if (from.isNotEmpty) from].join(', '),
          t.textSecondary,
        ),
      if (budget.isNotEmpty) (budget, t.textMuted),
    ],
    state: switch (h) {
      _ when h.needsOk => null, // Allow… says it
      _ when h.problem.isNotEmpty => ('Not signed in', NoteTone.crashed),
      _ when who != null => ('Signed in', NoteTone.done),
      _ => null,
    },
    needsOk: h.needsOk,
    onAllow: onAllow,
    more: [
      if (token.isNotEmpty) MenuEntry.heading(token),
      if (h.pasted) MenuEntry('Remove token…', danger: true, onPick: onRemove),
    ],
  );
}
