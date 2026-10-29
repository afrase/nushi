import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/account_rows.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_findings_settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Where GitHub makes tokens.
final Uri githubTokensPage = Uri.parse('https://github.com/settings/tokens');

/// Where a token comes from, as Settings says it.
String tokenSource(GitHubHost h) => switch (h.source) {
  'gh' => "gh's login",
  'token' => 'a pasted token',
  final s => s, // GH_TOKEN and the like, from the environment
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
  return 'Left this hour: ${parts.join(' · ')}'
      '${mins != null && mins >= 0 ? ' (GraphQL resets in ${mins}m)' : ''}';
}

/// Settings › GitHub: each host gh is signed in to or given a token, who
/// its token is (gh's login, or a pasted one, in the keychain), and what's
/// left of its rate limits (shared with gh in a terminal and agents that
/// run gh); Add a token, for a host without gh, or instead of gh's.
class GitHubPage extends StatefulWidget {
  const new(this.client, {super.key, this.now});

  final NushiServiceClient client;

  /// The time resets are counted from (tests); now when null.
  final DateTime? now;

  @override
  State<GitHubPage> createState() => _GitHubPageState();
}

class _GitHubPageState extends State<GitHubPage> {
  List<GitHubHost>? _hosts;
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await widget.client.listGitHubHosts(ListGitHubHostsRequest());
      if (!mounted) return;
      setState(() {
        _hosts = r.hosts;
        _error = null;
        _adding = _adding || r.hosts.isEmpty;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _hosts = const [];
          _error = errorText(e);
        });
      }
    }
  }

  Future<void> _remove(GitHubHost h) async {
    if (!await confirm(
          context,
          'Remove the token for ${h.host}?',
          "Nushi deletes it from the keychain, and uses gh's login for "
              '${h.host} if gh has one.',
          'Remove',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    await tryOrShow(context, () async {
      await widget.client.removeGitHubToken(
        RemoveGitHubTokenRequest(host: h.host),
      );
      await _load();
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
          title: 'Hosts',
          footer: const Text(
            'Nushi asks GitHub only while its view, a pull request or a '
            "chat's status shows, and writes only what you send.",
          ),
          children: [
            for (final h in hosts)
              _hostRow(
                t,
                h,
                now: widget.now ?? clock(),
                onAllow: () => _allow(h),
                onRemove: () => _remove(h),
              ),
            if (hosts.isEmpty)
              const SettingsRow(
                'No GitHub host',
                description:
                    'Sign in with gh auth login in a terminal, or add a '
                    'token.',
              ),
          ],
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        if (_adding)
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
          )
        else
          Row(
            children: [
              Button(
                label: 'Add a token',
                icon: Icons.add,
                onPressed: () => setState(() => _adding = true),
              ),
            ],
          ),
        const SizedBox(height: 24),
        const FindingsGroup(),
      ],
    );
  }
}

/// A host's row: who its token is or what's wrong, where the token
/// comes from, and what's left of its rate limits.
AccountRow _hostRow(
  Tokens t,
  GitHubHost h, {
  required DateTime now,
  required VoidCallback onAllow,
  required VoidCallback onRemove,
}) {
  final who = h.login.isEmpty
      ? null
      : 'Signed in as ${h.login}${h.name.isEmpty ? '' : ' (${h.name})'}';
  final kind = tokenKind(h.kind);
  final budget = budgetLine(h, now);
  return AccountRow(
    title: h.host,
    lines: [
      if (h.needsOk)
        (needsOkStatus, t.needs)
      else if (h.problem.isNotEmpty)
        (h.problem, t.crashed)
      else
        (who ?? 'Checking…', t.textSecondary),
      if (h.source.isNotEmpty)
        (
          [
            'From ${tokenSource(h)}',
            if (kind.isNotEmpty) kind,
            if (h.scopes.isNotEmpty) 'scopes ${h.scopes.join(', ')}',
          ].join(' · '),
          t.textMuted,
        ),
      if (budget.isNotEmpty) (budget, t.textMuted),
    ],
    needsOk: h.needsOk,
    onAllow: onAllow,
    onRemove: h.pasted ? onRemove : null,
  );
}
